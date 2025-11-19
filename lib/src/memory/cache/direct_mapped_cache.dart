// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// direct_mapped_cache.dart
// Direct-mapped cache implementation.
//
// 2025 October 15
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A direct-mapped cache (1-way set-associative cache).
///
/// This is a simplified cache where each memory address maps to exactly one
/// cache line (ways = 1). This eliminates the need for replacement policies
/// and way selection logic, making it more efficient but potentially having
/// more conflict misses.
class DirectMappedCache extends Cache {
  /// The tag register file.
  @protected
  late final RegisterFile tagRF;

  /// The data register file.
  @protected
  late final RegisterFile dataRF;

  /// The valid bit register file.
  @protected
  late final RegisterFile validBitRF;

  /// Constructs a [DirectMappedCache] with a single way.
  ///
  /// Defines a direct-mapped cache with [lines] entries. Each address maps
  /// to exactly one cache line based on the line index portion of the address.
  DirectMappedCache(
    super.clk,
    super.reset,
    super.fills,
    super.reads, {
    super.lines = 16,
  }) : super(ways: 1);

  @override
  void buildLogic() {
    final numReads = reads.length;
    final numFills = fills.length;
    final lineAddrWidth = log2Ceil(lines);
    final tagWidth = reads[0].addrWidth - lineAddrWidth;
    // Create per-way register files (direct-mapped is 1-way, but keep
    // consistent with other cache implementations).
    final hasEvictions = fills.isNotEmpty && fills[0].eviction != null;

    tagRF = RegisterFile(
        clk,
        reset,
        List.generate(
            numFills, (i) => DataPortInterface(tagWidth, lineAddrWidth)),
        [
          ...List.generate(
              numFills, (i) => DataPortInterface(tagWidth, lineAddrWidth)),
          ...List.generate(
              numReads, (i) => DataPortInterface(tagWidth, lineAddrWidth)),
          if (hasEvictions)
            ...List.generate(
                numFills, (i) => DataPortInterface(tagWidth, lineAddrWidth))
        ],
        numEntries: lines,
        name: 'tag_rf');

    validBitRF = RegisterFile(
        clk,
        reset,
        List.generate(
            numFills + numReads, (i) => DataPortInterface(1, lineAddrWidth)),
        List.generate(
            numFills + numReads, (i) => DataPortInterface(1, lineAddrWidth)),
        numEntries: lines,
        name: 'valid_bit_rf');

    dataRF = RegisterFile(
        clk,
        reset,
        List.generate(
            numFills, (i) => DataPortInterface(dataWidth, lineAddrWidth)),
        [
          ...List.generate(
              numReads, (i) => DataPortInterface(dataWidth, lineAddrWidth)),
          if (hasEvictions)
            ...List.generate(
                numFills, (i) => DataPortInterface(dataWidth, lineAddrWidth))
        ],
        numEntries: lines,
        name: 'data_rf');

    // Helper: handle a fill port at index `fillIdx`.
    void handleFillPort(int fillIdx) {
      final fillPort = fills[fillIdx].fill;
      final tagWrPort = tagRF.writes[fillIdx];
      final dataWrPort = dataRF.writes[fillIdx];

      tagWrPort.en <= fillPort.en & fillPort.valid;
      tagWrPort.addr <= getLine(fillPort.addr);
      tagWrPort.data <= getTag(fillPort.addr);

      dataWrPort.en <= fillPort.en & fillPort.valid;
      dataWrPort.addr <= getLine(fillPort.addr);
      dataWrPort.data <= fillPort.data;

      final tagRdPort = tagRF.reads[fillIdx];
      tagRdPort.en <= fillPort.en;
      tagRdPort.addr <= getLine(fillPort.addr);

      final validBitRdPort = validBitRF.reads[fillIdx];
      validBitRdPort.en <= fillPort.en;
      validBitRdPort.addr <= getLine(fillPort.addr);

      final storedTag = tagRdPort.data;
      final requestTag = getTag(fillPort.addr);
      final hasHit = validBitRdPort.data[0] & storedTag.eq(requestTag);

      final validBitWrPort = validBitRF.writes[fillIdx];

      Combinational([
        validBitWrPort.en < Const(0),
        validBitWrPort.addr < Const(0, width: lineAddrWidth),
        validBitWrPort.data < Const(0, width: 1),
        If(fillPort.en, then: [
          If.block([
            Iff(fillPort.valid, [
              validBitWrPort.en < Const(1),
              validBitWrPort.addr < getLine(fillPort.addr),
              validBitWrPort.data < Const(1, width: 1),
            ]),
            ElseIf(~fillPort.valid & hasHit, [
              validBitWrPort.en < Const(1),
              validBitWrPort.addr < getLine(fillPort.addr),
              validBitWrPort.data < Const(0, width: 1),
            ]),
          ])
        ])
      ]);

      // If eviction outputs are present, build eviction reads and outputs.
      if (hasEvictions) {
        final evictPort = fills[fillIdx].eviction!;

        final evictDataReadPort = dataRF.reads[numReads + fillIdx];
        final evictTagReadPort = tagRF.reads[numFills + numReads + fillIdx];

        // Read the tag and data at the line being filled.
        evictTagReadPort.en <= fillPort.en;
        evictTagReadPort.addr <= getLine(fillPort.addr);

        evictDataReadPort.en <= fillPort.en;
        evictDataReadPort.addr <= getLine(fillPort.addr);

        // Check if the line being filled has valid data (for eviction).
        final validBitRdPort = validBitRF.reads[fillIdx];
        final lineValid =
            validBitRdPort.data[0].named('evict${fillIdx}LineValid');

        // Check if this fill is a hit.
        final storedTag =
            evictTagReadPort.data.named('evict${fillIdx}StoredTag');
        final requestTag =
            getTag(fillPort.addr).named('evict${fillIdx}RequestTag');
        final fillHasHit = (lineValid & storedTag.eq(requestTag))
            .named('evict${fillIdx}FillHasHit');

        final allocEvictCond = (fillPort.valid & ~fillHasHit & lineValid)
            .named('allocEvictCond$fillIdx');
        final invalEvictCond =
            (~fillPort.valid & fillHasHit).named('invalEvictCond$fillIdx');

        final evictAddrComb =
            Logic(name: 'evictAddrComb$fillIdx', width: fillPort.addrWidth);
        Combinational([
          evictAddrComb <
              mux(invalEvictCond, fillPort.addr,
                  [evictTagReadPort.data, getLine(fillPort.addr)].swizzle())
        ]);

        Combinational([
          evictPort.en < (fillPort.en & (invalEvictCond | allocEvictCond)),
          evictPort.valid < (fillPort.en & (invalEvictCond | allocEvictCond)),
          evictPort.addr < evictAddrComb,
          evictPort.data < evictDataReadPort.data,
        ]);
      }
    }

    // Call helper for each fill port.
    for (var fillIdx = 0; fillIdx < numFills; fillIdx++) {
      handleFillPort(fillIdx);
    }

    // Handle read operations
    // Helper: handle a read port at index `readIdx`
    void handleReadPort(int readIdx) {
      final readPort = reads[readIdx];
      final tagRdPort = tagRF.reads[numFills + readIdx];
      final dataRdPort = dataRF.reads[readIdx];

      // Read tag.
      tagRdPort.en <= readPort.en;
      tagRdPort.addr <= getLine(readPort.addr);

      // Read data.
      dataRdPort.en <= readPort.en;
      dataRdPort.addr <= getLine(readPort.addr);

      // Read valid bit for read port check.
      final validBitRdPort = validBitRF.reads[numFills + readIdx];
      validBitRdPort.en <= readPort.en;
      validBitRdPort.addr <= getLine(readPort.addr);

      // Check for cache hit: valid bit is set AND tag matches.
      final storedTag = tagRdPort.data;
      final requestTag = getTag(readPort.addr);

      final hit = validBitRdPort.data[0] & storedTag.eq(requestTag);

      // Output data and valid signal.
      readPort.data <= dataRdPort.data;
      readPort.valid <= hit;

      // Handle readWithInvalidate functionality - write to valid bit RF
      // on next cycle.
      if (readPort.hasReadWithInvalidate) {
        final validBitWrPort = validBitRF.writes[numFills + readIdx];

        // Register the signals for next cycle write.
        final shouldInvalidate = flop(
            clk, readPort.readWithInvalidate & hit & readPort.en,
            reset: reset);
        final invalidateAddr = flop(clk, getLine(readPort.addr), reset: reset);

        Combinational([
          validBitWrPort.en < shouldInvalidate,
          validBitWrPort.addr < invalidateAddr,
          validBitWrPort.data < Const(0, width: 1), // Invalidate = set to 0.
        ]);
      } else {
        // No readWithInvalidate, so no valid bit writes from this read port.
        final validBitWrPort = validBitRF.writes[numFills + readIdx];
        validBitWrPort.en <= Const(0);
        validBitWrPort.addr <= Const(0, width: lineAddrWidth);
        validBitWrPort.data <= Const(0, width: 1);
      }
    }

    // Call helper for each read port.
    for (var readIdx = 0; readIdx < numReads; readIdx++) {
      handleReadPort(readIdx);
    }
  }
}
