// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fully_associative_cache.dart
// Fully associative cache implementation.
//
// 2025 October 15
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A fully associative cache implementation.
///
/// In a fully associative cache, any memory location can be stored in any cache
/// 'way'. This eliminates conflict misses at the cost of more complex tag
/// comparison logic and replacement policies. The entire address becomes the
/// tag, and all ways must be searched on each access.
///
class FullyAssociativeCache extends Cache {
  /// The width of the address tag. In a fully associative cache,
  /// this is the full address width since there's no line indexing.
  @protected
  final int tagWidth;

  /// If `true`, then the [occupancy], [full], and [empty] outputs will be
  /// generated.
  final bool generateOccupancy;

  /// High if the entire cache is full and it cannot accept any more new
  /// entries. Only available if [generateOccupancy] is `true`.
  Logic? get full => tryOutput('full');

  /// High if there are no valid entries in the cache.
  /// Only available if [generateOccupancy] is `true`.
  Logic? get empty => tryOutput('empty');

  /// The number of valid entries in the cache.
  /// Only available if [generateOccupancy] is `true`.
  Logic? get occupancy => tryOutput('occupancy');

  /// Constructs a [FullyAssociativeCache] with the specified configuration.
  ///
  /// The [reads] ports are used for looking up a tag and retrieving a hit with
  /// data or a miss. The [fills] ports are for writing data into the cache,
  /// either as a hit and overwriting existing data, or a miss in which case
  /// overwriting a new way in the cache.  This could result in an eviction of
  /// valid data, which would show up on a parallel [evictions] port (if
  /// provided). The [replacement] policy determines which way to evict on a
  /// miss and defaults to [PseudoLRUReplacement].
  ///
  /// Note: In a fully associative cache, [lines] is effectively 1 since there's
  /// no line indexing, but we use it to maintain consistency with the [Cache]
  /// base class.
  FullyAssociativeCache(
    super.clk,
    super.reset,
    super.fills,
    super.reads, {
    super.evictions,
    super.ways = 4,
    super.replacement = PseudoLRUReplacement.new,
    this.generateOccupancy = false,
    super.name = 'FullyAssociativeCache',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  })  : tagWidth = reads.isNotEmpty ? reads[0].addrWidth : fills[0].addrWidth,
        super(
          lines: 1, // Fully associative has no line indexing
          definitionName: definitionName ??
              'FullyAssociativeCache_WP${fills.length}_RP${reads.length}_'
                  'W$ways',
        ) {
    if (ways < 2) {
      throw RohdHclException('Must have more than 1 way for a '
          'FullyAssociativeCache');
    }
  }

  @override
  void buildLogic() {
    final numReads = reads.length;
    final numFills = fills.length;
    final wayAddrWidth = log2Ceil(ways > 0 ? ways : 1);

    // Create register file for tags (without valid bit).
    final tagRfWritePorts = List.generate(
        numFills, (_) => DataPortInterface(tagWidth, wayAddrWidth));
    final tagRfReadCount = (numReads + numFills) * ways + numFills;
    final tagRfReadPorts = List.generate(
        tagRfReadCount, (_) => DataPortInterface(tagWidth, wayAddrWidth));

    RegisterFile(clk, reset, tagRfWritePorts, tagRfReadPorts,
        numEntries: ways, name: 'tagRf');

    // Create separate valid bit storage using Logic arrays since we need
    // to update valid bits without using register file write ports.
    final validBits = List.generate(ways, (way) => Logic(name: 'validWay$way'));

    // Track which ways need valid bit updates from reads (readWithInvalidate).
    final readValidBitUpdates = List.generate(
        ways,
        (way) => List.generate(numReads,
            (readIdx) => Logic(name: 'read${readIdx}ValidUpdateWay$way')));

    // Track which ways need valid bit updates from fills.
    // Each fill port has its own set of update signals for each way.
    final fillValidBitUpdates = List.generate(
        numFills,
        (fillIdx) => List.generate(
            ways, (way) => Logic(name: 'fill${fillIdx}ValidUpdateWay$way')));
    final fillValidBitNewValues = List.generate(
        numFills,
        (fillIdx) => List.generate(
            ways, (way) => Logic(name: 'fill${fillIdx}ValidNewValueWay$way')));

    // Combine all valid bit update sources.
    final validBitUpdates = List.generate(ways, (way) {
      final readUpdates = readValidBitUpdates[way];
      final anyReadUpdate =
          readUpdates.isEmpty ? Const(0) : readUpdates.reduce((a, b) => a | b);
      // Combine all fill port updates for this way
      final fillUpdatesForWay =
          fillValidBitUpdates.map((fillUpdates) => fillUpdates[way]).toList();
      final anyFillUpdate = fillUpdatesForWay.isEmpty
          ? Const(0)
          : fillUpdatesForWay.reduce((a, b) => a | b);
      return anyReadUpdate | anyFillUpdate;
    });

    final validBitNewValues = List.generate(ways, (way) {
      // Priority: read invalidate > fill update > keep current value.
      final readInvalidates = readValidBitUpdates[way];
      final anyReadInvalidate = readInvalidates.isEmpty
          ? Const(0)
          : readInvalidates.reduce((a, b) => a | b);

      // Combine all fill port updates for this way
      final fillUpdatesForWay =
          fillValidBitUpdates.map((fillUpdates) => fillUpdates[way]).toList();
      final anyFillUpdate = fillUpdatesForWay.isEmpty
          ? Const(0)
          : fillUpdatesForWay.reduce((a, b) => a | b);

      // For new values, we need to pick the right one from the fill ports that
      // are updating For now, assume only one fill port updates a way at a time
      // (which should be the case)
      var fillNewValue = validBits[way]; // Default to current value
      for (var fillIdx = 0; fillIdx < numFills; fillIdx++) {
        fillNewValue = mux(fillValidBitUpdates[fillIdx][way],
            fillValidBitNewValues[fillIdx][way], fillNewValue);
      }

      // If read invalidates, set to 0. Else if fill updates, use fill value.
      // Else keep current (but this case shouldn't happen due to
      // validBitUpdates logic).
      return mux(anyReadInvalidate, Const(0),
          mux(anyFillUpdate, fillNewValue, validBits[way]));
    });

    // Register the valid bits with updates.
    for (var way = 0; way < ways; way++) {
      validBits[way] <=
          flop(clk,
              mux(validBitUpdates[way], validBitNewValues[way], validBits[way]),
              reset: reset);
    }

    final dataRfWritePorts = List.generate(
        numFills, (_) => DataPortInterface(dataWidth, wayAddrWidth));
    final dataRfReadPorts = List.generate(
        numReads, (_) => DataPortInterface(dataWidth, wayAddrWidth));
    final evictDataRfReadPorts = List.generate(
        numFills, (_) => DataPortInterface(dataWidth, wayAddrWidth));

    RegisterFile(clk, reset, dataRfWritePorts,
        [...dataRfReadPorts, ...evictDataRfReadPorts],
        numEntries: ways, name: 'dataRf');

    // Create replacement policy instance. We need a single policy for the
    // entire cache since there's only one 'line'.
    final policyReadHits =
        List.generate(numReads, (_) => AccessInterface(ways));
    final policyFillHits =
        List.generate(numFills, (_) => AccessInterface(ways));
    final policyAllocs = List.generate(numFills, (_) => AccessInterface(ways));
    final policyInvalidates =
        List.generate(numFills, (_) => AccessInterface(ways));

    replacement(clk, reset, [...policyReadHits, ...policyFillHits],
        policyAllocs, policyInvalidates,
        ways: ways, name: 'fullyAssocReplacementPolicy');

    // Generate tag match logic for each way and each access port.
    final readTagMatches = [
      for (var readIdx = 0; readIdx < numReads; readIdx++)
        List.generate(
            ways, (way) => Logic(name: 'read${readIdx}Way${way}Match'))
    ];
    final fillTagMatches = [
      for (var fillIdx = 0; fillIdx < numFills; fillIdx++)
        List.generate(
            ways, (way) => Logic(name: 'fill${fillIdx}Way${way}Match'))
    ];

    // Read all tag entries to check for matches.
    for (var way = 0; way < ways; way++) {
      for (var readIdx = 0; readIdx < numReads; readIdx++) {
        final tagRdPort = tagRfReadPorts[readIdx * ways + way];
        tagRdPort.en <= reads[readIdx].en;
        tagRdPort.addr <= Const(way, width: wayAddrWidth);

        // Check if tag matches and entry is valid using separate valid bit.
        final storedTag = tagRdPort.data;
        final requestTag = reads[readIdx].addr;

        readTagMatches[readIdx][way] <=
            validBits[way] & storedTag.eq(requestTag);
      }

      // For fills (need to check for existing entries).
      for (var fillIdx = 0; fillIdx < numFills; fillIdx++) {
        final tagRdPort =
            tagRfReadPorts[numReads * ways + fillIdx * ways + way];
        tagRdPort.en <= fills[fillIdx].en;
        tagRdPort.addr <= Const(way, width: wayAddrWidth);

        // Check if tag matches and entry is valid using separate valid bit.
        final storedTag = tagRdPort.data;
        final requestTag = fills[fillIdx].addr;

        fillTagMatches[fillIdx][way] <=
            validBits[way] & storedTag.eq(requestTag);
      }
    }

    // Generate hit detection and way selection for reads.
    for (var readIdx = 0; readIdx < numReads; readIdx++) {
      final readPort = reads[readIdx];
      final dataReadPort = dataRfReadPorts[readIdx];

      // Determine if we have a hit and which way.
      final hasHit = readTagMatches[readIdx]
          .reduce((a, b) => a | b)
          .named('read${readIdx}HasHit');

      // Only compute way when we have a hit to avoid issues with all-zero
      // input.
      final hitWay = Logic(name: 'read${readIdx}HitWay', width: wayAddrWidth);
      if (ways == 1) {
        // For single way, the way is always 0.
        hitWay <= Const(0, width: wayAddrWidth);
      } else {
        Combinational([
          If(hasHit, then: [
            hitWay <
                RecursivePriorityEncoder(readTagMatches[readIdx].rswizzle())
                    .out
                    .slice(wayAddrWidth - 1, 0),
          ], orElse: [
            hitWay < Const(0, width: wayAddrWidth),
          ])
        ]);
      }

      // Read data from the hit way.
      dataReadPort.en <= readPort.en & hasHit;
      dataReadPort.addr <= hitWay;

      // Output data and valid signal.
      readPort.data <= dataReadPort.data;
      readPort.valid <= hasHit;

      // Handle readWithInvalidate functionality - register the invalidation for
      // next cycle.
      if (readPort.hasReadWithInvalidate) {
        final shouldInvalidate =
            readPort.readWithInvalidate & hasHit & readPort.en;

        // Register the invalidation to happen on the next cycle after hit
        // detection.
        for (var way = 0; way < ways; way++) {
          final isHitWay = (ways == 1)
              ? Const(1)
              : hitWay.eq(Const(way, width: wayAddrWidth));
          final invalidateThisWay = shouldInvalidate & isHitWay;

          // Register the invalidation for next clock cycle.
          readValidBitUpdates[way][readIdx] <=
              flop(clk, invalidateThisWay, reset: reset);
        }
      } else {
        // No readWithInvalidate, so no valid bit updates from this read port.
        for (var way = 0; way < ways; way++) {
          readValidBitUpdates[way][readIdx] <= Const(0);
        }
      }

      // Update replacement policy on hit.
      policyReadHits[readIdx].access <= readPort.en & hasHit;
      policyReadHits[readIdx].way <= hitWay;
    }

    // Generate hit detection and way selection for fills
    for (var fillIdx = 0; fillIdx < numFills; fillIdx++) {
      final fillPort = fills[fillIdx];
      final tagWritePort = tagRfWritePorts[fillIdx];
      final dataWritePort = dataRfWritePorts[fillIdx];
      final evictDataReadPort = evictDataRfReadPorts[fillIdx];

      // Determine if we have a hit and which way.
      final hasHit = fillTagMatches[fillIdx]
          .reduce((a, b) => a | b)
          .named('fill${fillIdx}HasHit');

      // Only compute way when we have a hit.
      final hitWay = Logic(name: 'fill${fillIdx}HitWay', width: wayAddrWidth);
      if (ways == 1) {
        // For single way, the way is always 0.
        hitWay <= Const(0, width: wayAddrWidth);
      } else {
        Combinational([
          If(hasHit, then: [
            hitWay <
                RecursivePriorityEncoder(fillTagMatches[fillIdx].rswizzle())
                    .out
                    .slice(wayAddrWidth - 1, 0),
          ], orElse: [
            hitWay < Const(0, width: wayAddrWidth),
          ])
        ]);
      }

      evictDataReadPort.en <= fillPort.en;
      final evictDataAddr =
          Logic(name: 'evictDataAddr$fillIdx', width: wayAddrWidth);
      Combinational([
        If(hasHit,
            then: [evictDataAddr < hitWay],
            orElse: [evictDataAddr < policyAllocs[fillIdx].way])
      ]);
      evictDataReadPort.addr <= evictDataAddr;

      // Handle fill operations.
      Combinational([
        tagWritePort.en < Const(0),
        tagWritePort.addr < Const(0, width: wayAddrWidth),
        tagWritePort.data < Const(0, width: tagWidth),
        dataWritePort.en < Const(0),
        dataWritePort.addr < Const(0, width: wayAddrWidth),
        dataWritePort.data < Const(0, width: dataWidth),
        policyFillHits[fillIdx].access < Const(0),
        policyFillHits[fillIdx].way < Const(0, width: wayAddrWidth),
        policyAllocs[fillIdx].access < Const(0),
        policyInvalidates[fillIdx].access < Const(0),
        policyInvalidates[fillIdx].way < Const(0, width: wayAddrWidth),
        If(fillPort.en, then: [
          If.block([
            // Case 1: Valid fill with hit (update existing entry).
            Iff(fillPort.valid & hasHit, [
              dataWritePort.en < Const(1),
              dataWritePort.addr < hitWay,
              dataWritePort.data < fillPort.data,

              // Update replacement policy.
              policyFillHits[fillIdx].access < Const(1),
              policyFillHits[fillIdx].way < hitWay,
            ]),

            // Case 2: Valid fill with miss (allocate new entry).
            ElseIf(fillPort.valid & ~hasHit, [
              tagWritePort.en < Const(1),
              tagWritePort.addr < policyAllocs[fillIdx].way,
              tagWritePort.data < fillPort.addr, // Just the tag, no valid bit

              dataWritePort.en < Const(1),
              dataWritePort.addr < policyAllocs[fillIdx].way,
              dataWritePort.data < fillPort.data,

              policyAllocs[fillIdx].access < Const(1),
            ]),

            // Case 3: Invalid fill (invalidate existing entry if present).
            ElseIf(~fillPort.valid & hasHit, [
              // Update replacement policy for invalidation
              policyInvalidates[fillIdx].access < Const(1),
              policyInvalidates[fillIdx].way < hitWay,
            ]),
          ])
        ])
      ]);

      // Handle valid bit updates from fills
      for (var way = 0; way < ways; way++) {
        final isHitWay =
            (ways == 1) ? Const(1) : hitWay.eq(Const(way, width: wayAddrWidth));
        final isAllocWay = (ways == 1)
            ? Const(1)
            : policyAllocs[fillIdx].way.eq(Const(way, width: wayAddrWidth));

        final validFillHit = (fillPort.en & fillPort.valid & hasHit & isHitWay)
            .named('validFillHit${fillIdx}Way$way');
        final validFillMiss =
            (fillPort.en & fillPort.valid & ~hasHit & isAllocWay)
                .named('validFillMiss${fillIdx}Way$way');
        final invalidFill = (fillPort.en & ~fillPort.valid & hasHit & isHitWay)
            .named('invalidFill${fillIdx}Way$way');

        Combinational([
          fillValidBitUpdates[fillIdx][way] <
              (validFillHit | validFillMiss | invalidFill)
                  .named('fillValidUpdate${fillIdx}Way$way'),
          // Set to 1 for valid fills, 0 for invalid.
          fillValidBitNewValues[fillIdx][way] <
              (validFillHit | validFillMiss)
                  .named('fillValidNewValue${fillIdx}Way$way'),
        ]);
      }
    }

    // Handle evictions if eviction ports are provided.
    if (evictions.isNotEmpty) {
      for (var evictIdx = 0; evictIdx < evictions.length; evictIdx++) {
        final evictPort = evictions[evictIdx];
        final fillPort = fills[evictIdx]; // Corresponding fill port.
        final evictDataReadPort = evictDataRfReadPorts[evictIdx];

        final evictTagReadBase = numReads * ways + numFills * ways;
        final evictTagReadPort = tagRfReadPorts[evictTagReadBase + evictIdx];
        evictTagReadPort.en <= fillPort.en;
        evictTagReadPort.addr <= policyAllocs[evictIdx].way;

        final fillHasHit = fillTagMatches[evictIdx]
            .reduce((a, b) => a | b)
            .named('evict${evictIdx}FillHasHit');

        // Check if the way being allocated has a valid entry (for eviction).
        final allocWayIdx = policyAllocs[evictIdx].way;
        final allocWayValid = Logic(name: 'allocWayValid$evictIdx');

        // Generate multiplexer to select valid bit based on way index
        if (ways == 1) {
          allocWayValid <= validBits[0];
        } else {
          final validSelections = <Logic>[];
          for (var way = 0; way < ways; way++) {
            validSelections.add(
                allocWayIdx.eq(Const(way, width: wayAddrWidth)) &
                    validBits[way]);
          }
          allocWayValid <=
              validSelections
                  .reduce((a, b) => a | b)
                  .named('allocWayValidReduction$evictIdx');
        }

        final allocEvictCond = (fillPort.valid & ~fillHasHit & allocWayValid)
            .named('allocEvictCond$evictIdx');
        final invalEvictCond =
            (~fillPort.valid & fillHasHit).named('invalEvictCond$evictIdx');

        final evictAddrComb =
            Logic(name: 'evictAddrComb$evictIdx', width: fillPort.addrWidth);
        Combinational([
          If(invalEvictCond, then: [
            evictAddrComb < fillPort.addr
          ], orElse: [
            evictAddrComb <
                evictTagReadPort
                    .data // No need to slice since valid bit is separate
          ])
        ]);

        Combinational([
          evictPort.en < (fillPort.en & (invalEvictCond | allocEvictCond)),
          evictPort.valid < (fillPort.en & (invalEvictCond | allocEvictCond)),
          evictPort.addr < evictAddrComb,
          evictPort.data < evictDataReadPort.data,
        ]);
      }
    }

    // Generate occupancy tracking if requested
    if (generateOccupancy) {
      final occupancyWidth =
          log2Ceil(ways + 1); // +1 to represent full occupancy

      // Use Count component to count the number of valid bits directly.
      // This provides immediate combinational response without delays.
      final validBitsBundle = validBits.rswizzle().named('validBitsBundle');

      final validCountModule = Count(validBitsBundle);
      final validCount = validCountModule.count;

      // Add outputs for occupancy tracking
      addOutput('occupancy', width: occupancyWidth);
      addOutput('full');
      addOutput('empty');

      // Connect outputs with proper width extension
      occupancy! <= validCount.zeroExtend(occupancyWidth);
      full! <= validCount.eq(Const(ways, width: validCount.width));
      empty! <= validCount.eq(Const(0, width: validCount.width));
    }
  }

  @override
  // In a fully associative cache, the entire address is the tag
  Logic getTag(Logic addr) => addr;

  @override
  // No line indexing in a fully associative cache.
  Logic getLine(Logic addr) => Const(0, width: 1);
}
