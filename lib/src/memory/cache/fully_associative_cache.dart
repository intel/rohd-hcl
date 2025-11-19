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
  /// If `true`, then the [occupancy], [full], and [empty] outputs will be
  /// generated.
  final bool generateOccupancy;

  /// Whether this cache supports simultaneous fill and read-with-invalidate
  /// when the cache is full (requires bypass network).
  /// Currently false - fills cannot complete when cache is full even if
  /// an RWI is freeing a slot in the same cycle (invalidate is delayed).
  final bool supportsFillReadWithInvalidateBypass = false;

  /// High if the entire cache is full and it cannot accept any more new
  /// entries. Only available if [generateOccupancy] is `true`.
  Logic? get full => tryOutput('full');

  /// High if there are no valid entries in the cache.
  /// Only available if [generateOccupancy] is `true`.
  Logic? get empty => tryOutput('empty');

  /// The number of valid entries in the cache.
  /// Only available if [generateOccupancy] is `true`.
  Logic? get occupancy => tryOutput('occupancy');

  /// Returns whether this cache supports simultaneous fill and
  /// read-with-invalidate bypass when the cache is full. When false, fills
  /// cannot complete when the cache is full even if an RWI in the same cycle is
  /// freeing up a slot.
  bool get canBypassFillWithRWI => supportsFillReadWithInvalidateBypass;

  /// The width of the tag. In a fully associative cache,
  /// this is the full address width since there's no line indexing.
  @protected
  final int tagWidth;

  /// The width needed to store the way.
  @protected
  final int wayAddrWidth;

  /// The tag RegisterFile.
  @protected
  late final RegisterFile tagRf;

  /// The data RegisterFile.
  @protected
  late final RegisterFile dataRf;

  /// The replacement policy instance.
  @protected
  late final ReplacementPolicy replacementPolicy;

  /// Constructs a [FullyAssociativeCache] with the specified configuration.
  ///
  /// The [reads] ports are used for looking up a tag and retrieving a hit with
  /// data or a miss. The [fills] ports are for writing data into the cache,
  /// either as a hit and overwriting existing data, or a miss in which case
  /// overwriting a new way in the cache.  This could result in an eviction of
  /// valid data. The [replacement] policy determines which way to evict on a
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
    super.ways = 4,
    super.replacement = PseudoLRUReplacement.new,
    this.generateOccupancy = false,
    super.name = 'FullyAssociativeCache',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  })  : tagWidth =
            reads.isNotEmpty ? reads[0].addrWidth : fills[0].fill.addrWidth,
        wayAddrWidth = log2Ceil(ways > 0 ? ways : 1),
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

    if (numReads == 0) {
      throw RohdHclException(
          'FullyAssociativeCache requires at least one read port');
    }
    if (numFills == 0) {
      throw RohdHclException(
          'FullyAssociativeCache requires at least one fill port');
    }

    // Create register file for tags (without valid bit).
    tagRf = RegisterFile(
        clk,
        reset,
        List.generate(
            numFills, (_) => DataPortInterface(tagWidth, wayAddrWidth)),
        [
          // read and fill tag read ports: (numReads + numFills) * ways
          ...List.generate((numReads + numFills) * ways,
              (_) => DataPortInterface(tagWidth, wayAddrWidth)),
          // evict tag read ports for each fill
          ...List.generate(
              numFills, (_) => DataPortInterface(tagWidth, wayAddrWidth)),
        ],
        numEntries: ways,
        name: 'tagRf');

    // Create separate valid bit storage using Logic arrays since we need
    // to update valid bits without using register file write ports.
    final validBits = List.generate(ways, (way) => Logic(name: 'validWay$way'));

    final readValidBitUpdates = List.generate(
        ways,
        (way) => List.generate(numReads,
            (readIdx) => Logic(name: 'read${readIdx}ValidUpdateWay$way')));

    final fillValidBitUpdates = List.generate(
        ways,
        (way) => List.generate(numFills,
            (fillIdx) => Logic(name: 'fill${fillIdx}ValidUpdateWay$way')));
    final fillValidBitNewValues = List.generate(
        ways,
        (way) => List.generate(numFills,
            (fillIdx) => Logic(name: 'fill${fillIdx}ValidNewValueWay$way')));

    // Combine all valid bit update sources.
    final validBitUpdates = List.generate(ways, (way) {
      final readUpdates = readValidBitUpdates[way];
      final anyReadUpdate = readUpdates.rswizzle().or();
      final anyFillUpdate = fillValidBitUpdates[way].rswizzle().or();
      return anyReadUpdate | anyFillUpdate;
    });

    final validBitNewValues = List.generate(ways, (way) {
      final readInvalidates = readValidBitUpdates[way];
      final anyReadInvalidate = readInvalidates.rswizzle().or();

      final anyFillUpdate = fillValidBitUpdates[way].rswizzle().or();

      var fillNewValue = validBits[way]; // Default to current value
      for (var fillIdx = 0; fillIdx < numFills; fillIdx++) {
        fillNewValue = mux(fillValidBitUpdates[way][fillIdx],
            fillValidBitNewValues[way][fillIdx], fillNewValue);
      }

      // Fills take precedence over read invalidates (prevents flopped RWI
      // invalidates from overriding fills that allocate to recently-invalidated
      // ways)
      return mux(anyFillUpdate, fillNewValue,
          mux(anyReadInvalidate, Const(0), validBits[way]));
    });

    // Register the valid bits with updates.
    for (var way = 0; way < ways; way++) {
      validBits[way] <=
          flop(clk,
              mux(validBitUpdates[way], validBitNewValues[way], validBits[way]),
              reset: reset);
    }

    dataRf = RegisterFile(
        clk,
        reset,
        List.generate(
            numFills, (_) => DataPortInterface(dataWidth, wayAddrWidth)),
        [
          ...List.generate(
              numReads, (_) => DataPortInterface(dataWidth, wayAddrWidth)),
          ...List.generate(
              numFills, (_) => DataPortInterface(dataWidth, wayAddrWidth)),
        ],
        numEntries: ways,
        name: 'dataRf');

    replacementPolicy = replacement(
        clk,
        reset,
        [
          ...List.generate(numReads, (_) => AccessInterface(ways)),
          ...List.generate(numFills, (_) => AccessInterface(ways)),
        ],
        List.generate(numFills, (_) => AccessInterface(ways)),
        [
          // Read-invalidate interfaces come first
          ...List.generate(numReads, (_) => AccessInterface(ways)),
          // Fill-invalidate interfaces come after
          ...List.generate(numFills, (_) => AccessInterface(ways)),
        ],
        ways: ways,
        name: 'fullyAssocReplacementPolicy');

    void handleReadPort(int readIdx, List<Logic> validBits,
        List<List<Logic>> readValidBitUpdates) {
      final readPort = reads[readIdx];
      final dataReadPort = dataRf.reads[readIdx];

      final readTagMatchesForPort = List.generate(
          ways, (way) => Logic(name: 'read${readIdx}Way${way}Match'));
      for (var way = 0; way < ways; way++) {
        final tagRdPort = tagRf.reads[readIdx * ways + way];
        tagRdPort.en <= reads[readIdx].en;
        tagRdPort.addr <= Const(way, width: wayAddrWidth);

        final storedTag = tagRdPort.data;
        final requestTag = reads[readIdx].addr;

        readTagMatchesForPort[way] <= validBits[way] & storedTag.eq(requestTag);
      }

      final hasHit =
          readTagMatchesForPort.rswizzle().or().named('read${readIdx}HasHit');

      final hitWay = Logic(name: 'read${readIdx}HitWay', width: wayAddrWidth);
      if (ways == 1) {
        hitWay <= Const(0, width: wayAddrWidth);
      } else {
        hitWay <=
            mux(
                hasHit,
                RecursivePriorityEncoder(readTagMatchesForPort.rswizzle())
                    .out
                    .slice(wayAddrWidth - 1, 0),
                Const(0, width: wayAddrWidth));
      }

      dataReadPort.en <= readPort.en & hasHit;
      dataReadPort.addr <= hitWay;

      readPort.data <= dataReadPort.data;
      readPort.valid <= hasHit;

      if (readPort.hasReadWithInvalidate) {
        final shouldInvalidate =
            readPort.readWithInvalidate & hasHit & readPort.en;

        for (var way = 0; way < ways; way++) {
          final isHitWay = (ways == 1)
              ? Const(1)
              : hitWay.eq(Const(way, width: wayAddrWidth));
          final invalidateThisWay = shouldInvalidate & isHitWay;

          // Flop the valid bit update signal
          readValidBitUpdates[way][readIdx] <=
              flop(clk, invalidateThisWay, reset: reset);
        }

        replacementPolicy.invalidates[readIdx].access <=
            flop(clk, shouldInvalidate, reset: reset);
        replacementPolicy.invalidates[readIdx].way <=
            flop(clk, hitWay, reset: reset);
      } else {
        for (var way = 0; way < ways; way++) {
          readValidBitUpdates[way][readIdx] <= Const(0);
        }

        // No invalidation for this read port
        replacementPolicy.invalidates[readIdx].access <= Const(0);
        replacementPolicy.invalidates[readIdx].way <=
            Const(0, width: wayAddrWidth);
      }

      replacementPolicy.hits[readIdx].access <= readPort.en & hasHit;
      replacementPolicy.hits[readIdx].way <= hitWay;
    }

    for (var readIdx = 0; readIdx < numReads; readIdx++) {
      handleReadPort(readIdx, validBits, readValidBitUpdates);
    }

    // single routine for handling fill ports (and contained eviction ports).
    void handleFillPort(int fillIdx) {
      final fillPort = fills[fillIdx].fill;
      final tagWritePort = tagRf.writes[fillIdx];
      final dataWritePort = dataRf.writes[fillIdx];
      final evictDataReadPort = dataRf.reads[numReads + fillIdx];
      final evictTagReadPort =
          tagRf.reads[(numReads + numFills) * ways + fillIdx];

      final fillTagMatchesForPort = List.generate(
          ways, (way) => Logic(name: 'fill${fillIdx}Way${way}Match'));
      for (var way = 0; way < ways; way++) {
        final tagRdPort = tagRf.reads[numReads * ways + fillIdx * ways + way];
        tagRdPort.en <= fills[fillIdx].fill.en;
        tagRdPort.addr <= Const(way, width: wayAddrWidth);

        final storedTag = tagRdPort.data;
        final requestTag = fills[fillIdx].fill.addr;

        fillTagMatchesForPort[way] <= validBits[way] & storedTag.eq(requestTag);
      }

      final hasHit =
          fillTagMatchesForPort.rswizzle().or().named('fill${fillIdx}HasHit');

      final hitWay = Logic(name: 'fill${fillIdx}HitWay', width: wayAddrWidth);
      if (ways == 1) {
        hitWay <= Const(0, width: wayAddrWidth);
      } else {
        hitWay <=
            mux(
                hasHit,
                RecursivePriorityEncoder(fillTagMatchesForPort.rswizzle())
                    .out
                    .slice(wayAddrWidth - 1, 0),
                Const(0, width: wayAddrWidth));
      }

      evictDataReadPort.en <= fillPort.en;
      evictTagReadPort.en <= fillPort.en;
      final evictDataAddr =
          mux(hasHit, hitWay, replacementPolicy.allocs[fillIdx].way)
              .named('evictDataAddr$fillIdx');
      evictDataReadPort.addr <= evictDataAddr;
      evictTagReadPort.addr <= evictDataAddr;
      final evictPort = fills[fillIdx].eviction;

      Combinational([
        tagWritePort.en < Const(0),
        tagWritePort.addr < Const(0, width: wayAddrWidth),
        tagWritePort.data < Const(0, width: tagWidth),
        dataWritePort.en < Const(0),
        dataWritePort.addr < Const(0, width: wayAddrWidth),
        dataWritePort.data < Const(0, width: dataWidth),
        replacementPolicy.hits[numReads + fillIdx].access < Const(0),
        replacementPolicy.hits[numReads + fillIdx].way <
            Const(0, width: wayAddrWidth),
        replacementPolicy.allocs[fillIdx].access < Const(0),
        replacementPolicy.invalidates[numReads + fillIdx].access < Const(0),
        replacementPolicy.invalidates[numReads + fillIdx].way <
            Const(0, width: wayAddrWidth),
        If(fillPort.en, then: [
          If.block([
            Iff(fillPort.valid & hasHit, [
              dataWritePort.en < Const(1),
              dataWritePort.addr < hitWay,
              dataWritePort.data < fillPort.data,
              replacementPolicy.hits[numReads + fillIdx].access < Const(1),
              replacementPolicy.hits[numReads + fillIdx].way < hitWay,
            ]),
            ElseIf(fillPort.valid & ~hasHit, [
              tagWritePort.en < Const(1),
              tagWritePort.addr < replacementPolicy.allocs[fillIdx].way,
              tagWritePort.data < fillPort.addr,
              dataWritePort.en < Const(1),
              dataWritePort.addr < replacementPolicy.allocs[fillIdx].way,
              dataWritePort.data < fillPort.data,
              replacementPolicy.allocs[fillIdx].access < Const(1),
            ]),
            ElseIf(~fillPort.valid & hasHit, [
              replacementPolicy.invalidates[numReads + fillIdx].access <
                  Const(1),
              replacementPolicy.invalidates[numReads + fillIdx].way < hitWay,
            ]),
          ])
        ])
      ]);

      // Handle valid bit updates and eviction outputs for this fill index
      for (var way = 0; way < ways; way++) {
        final isHitWay =
            (ways == 1) ? Const(1) : hitWay.eq(Const(way, width: wayAddrWidth));
        final isAllocWay = (ways == 1)
            ? Const(1)
            : replacementPolicy.allocs[fillIdx].way
                .eq(Const(way, width: wayAddrWidth));

        final validFillHit = (fillPort.en & fillPort.valid & hasHit & isHitWay)
            .named('validFillHit${fillIdx}Way$way');
        final validFillMiss =
            (fillPort.en & fillPort.valid & ~hasHit & isAllocWay)
                .named('validFillMiss${fillIdx}Way$way');
        final invalidFill = (fillPort.en & ~fillPort.valid & hasHit & isHitWay)
            .named('invalidFill${fillIdx}Way$way');

        fillValidBitUpdates[way][fillIdx] <=
            (validFillHit | validFillMiss | invalidFill)
                .named('fillValidUpdate${fillIdx}Way$way');
        fillValidBitNewValues[way][fillIdx] <=
            (validFillHit | validFillMiss)
                .named('fillValidNewValue${fillIdx}Way$way');
      }

      // Drive eviction port outputs (if present) 1:1 with this fill port.
      if (evictPort != null) {
        final fillHasHit = fillTagMatchesForPort
            .rswizzle()
            .or()
            .named('evict${fillIdx}FillHasHit');

        final allocWayIdx = replacementPolicy.allocs[fillIdx].way;
        final allocWayValid = (ways == 1)
            ? validBits[0]
            : (List.generate(
                    ways,
                    (way) =>
                        allocWayIdx.eq(Const(way, width: wayAddrWidth)) &
                        validBits[way])
                .rswizzle()
                .or()
                .named('allocWayValidReduction$fillIdx'));

        final allocEvictCond = (fillPort.valid & ~fillHasHit & allocWayValid)
            .named('allocEvictCond$fillIdx');
        final invalEvictCond =
            (~fillPort.valid & fillHasHit).named('invalEvictCond$fillIdx');

        final evictAddrComb =
            mux(invalEvictCond, fillPort.addr, evictTagReadPort.data)
                .named('evictAddrComb$fillIdx');

        evictPort.en <= (fillPort.en & (invalEvictCond | allocEvictCond));
        evictPort.valid <= (fillPort.en & (invalEvictCond | allocEvictCond));
        evictPort.addr <= evictAddrComb;
        evictPort.data <= evictDataReadPort.data;
      }
    }

    for (var fillIdx = 0; fillIdx < numFills; fillIdx++) {
      handleFillPort(fillIdx);
    }

    // Generate occupancy tracking if requested.
    if (generateOccupancy) {
      final occupancyWidth =
          log2Ceil(ways + 1); // +1 to represent full occupancy

      final validBitsBundle = validBits.rswizzle().named('validBitsBundle');
      final validCountModule = Count(validBitsBundle);
      final validCount = validCountModule.count;

      // Add outputs for occupancy tracking
      addOutput('occupancy', width: occupancyWidth);
      addOutput('full');
      addOutput('empty');

      // Connect outputs with proper width extension.
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
