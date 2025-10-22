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

    // Create register file for tags (with valid bit).
    final tagRfWritePorts = List.generate(
        numFills, (_) => DataPortInterface(tagWidth + 1, wayAddrWidth));
    final tagRfReadCount = (numReads + numFills) * ways + numFills;
    final tagRfReadPorts = List.generate(
        tagRfReadCount, (_) => DataPortInterface(tagWidth + 1, wayAddrWidth));

    RegisterFile(clk, reset, tagRfWritePorts, tagRfReadPorts,
        numEntries: ways, name: 'tag_rf');

    final dataRfWritePorts = List.generate(
        numFills, (_) => DataPortInterface(dataWidth, wayAddrWidth));
    final dataRfReadPorts = List.generate(
        numReads, (_) => DataPortInterface(dataWidth, wayAddrWidth));
    final evictDataRfReadPorts = List.generate(
        numFills, (_) => DataPortInterface(dataWidth, wayAddrWidth));

    RegisterFile(clk, reset, dataRfWritePorts,
        [...dataRfReadPorts, ...evictDataRfReadPorts],
        numEntries: ways, name: 'data_rf');

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
        ways: ways, name: 'fully_associative_replacement_policy');

    // Generate tag match logic for each way and each access port.
    final readTagMatches = [
      for (var readIdx = 0; readIdx < numReads; readIdx++)
        List.generate(
            ways, (way) => Logic(name: 'read_${readIdx}_way_${way}_match'))
    ];
    final fillTagMatches = [
      for (var fillIdx = 0; fillIdx < numFills; fillIdx++)
        List.generate(
            ways, (way) => Logic(name: 'fill_${fillIdx}_way_${way}_match'))
    ];

    // Read all tag entries to check for matches.
    for (var way = 0; way < ways; way++) {
      for (var readIdx = 0; readIdx < numReads; readIdx++) {
        final tagRdPort = tagRfReadPorts[readIdx * ways + way];
        tagRdPort.en <= reads[readIdx].en;
        tagRdPort.addr <= Const(way, width: wayAddrWidth);

        // Check if tag matches and entry is valid.
        final validBit = tagRdPort.data[-1]; // MSB is valid bit
        final storedTag = tagRdPort.data.slice(tagWidth - 1, 0);
        final requestTag = reads[readIdx].addr;

        readTagMatches[readIdx][way] <= validBit & storedTag.eq(requestTag);
      }

      // For fills (need to check for existing entries).
      for (var fillIdx = 0; fillIdx < numFills; fillIdx++) {
        final tagRdPort =
            tagRfReadPorts[numReads * ways + fillIdx * ways + way];
        tagRdPort.en <= fills[fillIdx].en;
        tagRdPort.addr <= Const(way, width: wayAddrWidth);

        // Check if tag matches and entry is valid.
        final validBit = tagRdPort.data[-1]; // MSB is valid bit
        final storedTag = tagRdPort.data.slice(tagWidth - 1, 0);
        final requestTag = fills[fillIdx].addr;

        fillTagMatches[fillIdx][way] <= validBit & storedTag.eq(requestTag);
      }
    }

    // Generate hit detection and way selection for reads.
    for (var readIdx = 0; readIdx < numReads; readIdx++) {
      final readPort = reads[readIdx];
      final dataReadPort = dataRfReadPorts[readIdx];

      // Determine if we have a hit and which way.
      final hasHit = readTagMatches[readIdx].reduce((a, b) => a | b);

      // Only compute way when we have a hit to avoid issues with all-zero
      // input.
      final hitWay =
          Logic(name: 'read_${readIdx}_hit_way', width: wayAddrWidth);
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

      // Determine if we have a hit and which way
      final hasHit = fillTagMatches[fillIdx].reduce((a, b) => a | b);

      // Only compute way when we have a hit
      final hitWay =
          Logic(name: 'fill_${fillIdx}_hit_way', width: wayAddrWidth);
      if (ways == 1) {
        // For single way, the way is always 0
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
          Logic(name: 'evict_data_addr_$fillIdx', width: wayAddrWidth);
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
        tagWritePort.data < Const(0, width: tagWidth + 1),
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
              tagWritePort.data <
                  [Const(1), fillPort.addr].swizzle(), // Valid + tag

              dataWritePort.en < Const(1),
              dataWritePort.addr < policyAllocs[fillIdx].way,
              dataWritePort.data < fillPort.data,

              policyAllocs[fillIdx].access < Const(1),
            ]),

            // Case 3: Invalid fill (invalidate existing entry if present).
            ElseIf(~fillPort.valid & hasHit, [
              // Clear valid bit in tag
              tagWritePort.en < Const(1),
              tagWritePort.addr < hitWay,
              tagWritePort.data <
                  [Const(0), fillPort.addr].swizzle(), // Invalid + tag

              // Update replacement policy
              policyInvalidates[fillIdx].access < Const(1),
              policyInvalidates[fillIdx].way < hitWay,
            ]),
          ])
        ])
      ]);
    }

    // Handle evictions if eviction ports are provided.
    if (evictions.isNotEmpty) {
      for (var evictIdx = 0; evictIdx < evictions.length; evictIdx++) {
        final evictPort = evictions[evictIdx];
        final fillPort = fills[evictIdx]; // Corresponding fill port.
        final evictDataReadPort = evictDataRfReadPorts[evictIdx];

        final evictTagReadBase = (numReads + numFills) * ways;
        final evictTagReadPort = tagRfReadPorts[evictTagReadBase + evictIdx];
        evictTagReadPort.en <= fillPort.en;
        evictTagReadPort.addr <= policyAllocs[evictIdx].way;

        final fillHasHit = fillTagMatches[evictIdx].reduce((a, b) => a | b);

        final allocEvictCond =
            fillPort.valid & ~fillHasHit & evictTagReadPort.data[-1];
        final invalEvictCond = ~fillPort.valid & fillHasHit;

        final evictAddrComb =
            Logic(name: 'evict_addr_comb_$evictIdx', width: fillPort.addrWidth);
        Combinational([
          If(invalEvictCond, then: [
            evictAddrComb < fillPort.addr
          ], orElse: [
            evictAddrComb < evictTagReadPort.data.slice(tagWidth - 1, 0)
          ])
        ]);

        Combinational([
          evictPort.en < (invalEvictCond | allocEvictCond),
          evictPort.valid < (invalEvictCond | allocEvictCond),
          evictPort.addr < evictAddrComb,
          evictPort.data < evictDataReadPort.data,
        ]);
      }
    }
  }

  @override
  // In a fully associative cache, the entire address is the tag
  Logic getTag(Logic addr) => addr;

  @override
  // No line indexing in a fully associative cache.
  Logic getLine(Logic addr) => Const(0, width: 1);
}
