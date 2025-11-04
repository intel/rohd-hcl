// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// direct_mapped_cache.dart
// Direct-mapped cache implementation.
//
// 2025 October 15
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A direct-mapped cache (1-way set-associative cache).
///
/// This is a simplified cache where each memory address maps to exactly one
/// cache line (ways = 1). This eliminates the need for replacement policies
/// and way selection logic, making it more efficient but potentially having
/// more conflict misses.
class DirectMappedCache extends Cache {
  /// Constructs a [DirectMappedCache] with a single way.
  ///
  /// Defines a direct-mapped cache with [lines] entries. Each address maps
  /// to exactly one cache line based on the line index portion of the address.
  ///
  /// The [evictions] ports return the address and data being evicted when
  /// a fill overwrites valid data or when an entry is invalidated.
  DirectMappedCache(
    super.clk,
    super.reset,
    super.fills,
    super.reads, {
    super.evictions,
    super.lines = 16,
  }) : super(ways: 1);

  @override
  void buildLogic() {
    final numReads = reads.length;
    final numFills = fills.length;
    final lineAddrWidth = log2Ceil(lines);
    final tagWidth = reads[0].addrWidth - lineAddrWidth;

    // Create eviction tag read ports if needed (one per fill port)
    final evictTagRfReadPorts = evictions.isNotEmpty
        ? List.generate(
            numFills,
            (i) => DataPortInterface(tagWidth, lineAddrWidth)
              ..en.named('evictTagRd_port${i}_en')
              ..addr.named('evictTagRd_port${i}_addr')
              ..data.named('evictTagRd_port${i}_data'))
        : <DataPortInterface>[];

    // Create register files for tags (without valid bit) and data
    // Since we have 1 way, we only need single register files
    final tagRfWritePorts = [
      for (var i = 0; i < numFills; i++)
        DataPortInterface(tagWidth, lineAddrWidth)
    ];
    final tagRfReadPorts = [
      for (var i = 0; i < numReads + numFills; i++)
        DataPortInterface(tagWidth, lineAddrWidth)
    ];

    RegisterFile(
      clk,
      reset,
      tagRfWritePorts,
      [...tagRfReadPorts, ...evictTagRfReadPorts],
      numEntries: lines,
      name: 'tag_rf',
    );

    // Create valid bit register file (one bit wide, indexed by line address).
    final validBitRfWritePorts = List.generate(
        numFills + numReads, // Fills + potential read invalidates
        (i) => DataPortInterface(1, lineAddrWidth)
          ..en.named('validBitWr_port${i}_en')
          ..addr.named('validBitWr_port${i}_addr')
          ..data.named('validBitWr_port${i}_data'));

    final validBitRfReadPorts = List.generate(
        numFills + numReads, // For fill and read checks
        (i) => DataPortInterface(1, lineAddrWidth)
          ..en.named('validBitRd_port${i}_en')
          ..addr.named('validBitRd_port${i}_addr')
          ..data.named('validBitRd_port${i}_data'));

    RegisterFile(clk, reset, validBitRfWritePorts, validBitRfReadPorts,
        numEntries: lines, name: 'valid_bit_rf');

    // Data register file (including eviction read ports if needed)
    final evictDataRfReadPorts = evictions.isNotEmpty
        ? List.generate(
            numFills,
            (i) => DataPortInterface(dataWidth, lineAddrWidth)
              ..en.named('evictDataRd_port${i}_en')
              ..addr.named('evictDataRd_port${i}_addr')
              ..data.named('evictDataRd_port${i}_data'))
        : <DataPortInterface>[];

    final dataRfWritePorts = [
      for (var i = 0; i < numFills; i++)
        DataPortInterface(dataWidth, lineAddrWidth)
    ];
    final dataRfReadPorts = [
      for (var i = 0; i < numReads; i++)
        DataPortInterface(dataWidth, lineAddrWidth)
    ];

    RegisterFile(
      clk,
      reset,
      dataRfWritePorts,
      [...dataRfReadPorts, ...evictDataRfReadPorts],
      numEntries: lines,
      name: 'data_rf',
    );

    // Handle fill operations
    for (var fillIdx = 0; fillIdx < numFills; fillIdx++) {
      final fillPort = fills[fillIdx];
      final tagWrPort = tagRfWritePorts[fillIdx];
      final dataWrPort = dataRfWritePorts[fillIdx];

      // Write to tag RF: store tag only (valid bit is separate)
      tagWrPort.en <= fillPort.en & fillPort.valid;
      tagWrPort.addr <= getLine(fillPort.addr);
      tagWrPort.data <= getTag(fillPort.addr);

      // Write to data RF
      dataWrPort.en <= fillPort.en & fillPort.valid;
      dataWrPort.addr <= getLine(fillPort.addr);
      dataWrPort.data <= fillPort.data;

      // Read tag for fill port (to check if overwriting)
      final tagRdPort = tagRfReadPorts[numReads + fillIdx];
      tagRdPort.en <= fillPort.en;
      tagRdPort.addr <= getLine(fillPort.addr);

      // Read valid bit for fill port check
      final validBitRdPort = validBitRfReadPorts[fillIdx];
      validBitRdPort.en <= fillPort.en;
      validBitRdPort.addr <= getLine(fillPort.addr);

      // Check if this is a hit or miss
      final storedTag = tagRdPort.data;
      final requestTag = getTag(fillPort.addr);
      final hasHit = validBitRdPort.data[0] & storedTag.eq(requestTag);

      // Handle valid bit updates from fills - write to valid bit RF
      final validBitWrPort = validBitRfWritePorts[fillIdx];

      Combinational([
        validBitWrPort.en < Const(0),
        validBitWrPort.addr < Const(0, width: lineAddrWidth),
        validBitWrPort.data < Const(0, width: 1),
        If(fillPort.en, then: [
          If.block([
            // Valid fill (hit or miss) - set valid bit to 1
            Iff(fillPort.valid, [
              validBitWrPort.en < Const(1),
              validBitWrPort.addr < getLine(fillPort.addr),
              validBitWrPort.data < Const(1, width: 1),
            ]),
            // Invalid fill (invalidation) - set valid bit to 0
            ElseIf(~fillPort.valid & hasHit, [
              validBitWrPort.en < Const(1),
              validBitWrPort.addr < getLine(fillPort.addr),
              validBitWrPort.data < Const(0, width: 1),
            ]),
          ])
        ])
      ]);
    }

    // Handle read operations
    for (var readIdx = 0; readIdx < numReads; readIdx++) {
      final readPort = reads[readIdx];
      final tagRdPort = tagRfReadPorts[readIdx];
      final dataRdPort = dataRfReadPorts[readIdx];

      // Read tag
      tagRdPort.en <= readPort.en;
      tagRdPort.addr <= getLine(readPort.addr);

      // Read data
      dataRdPort.en <= readPort.en;
      dataRdPort.addr <= getLine(readPort.addr);

      // Read valid bit for read port check
      final validBitRdPort = validBitRfReadPorts[numFills + readIdx];
      validBitRdPort.en <= readPort.en;
      validBitRdPort.addr <= getLine(readPort.addr);

      // Check for cache hit: valid bit is set AND tag matches
      final storedTag = tagRdPort.data;
      final requestTag = getTag(readPort.addr);

      final hit = validBitRdPort.data[0] & storedTag.eq(requestTag);

      // Output data and valid signal
      readPort.data <= dataRdPort.data;
      readPort.valid <= hit;

      // Handle readWithInvalidate functionality - write to valid bit RF
      // on next cycle.
      if (readPort.hasReadWithInvalidate) {
        final validBitWrPort = validBitRfWritePorts[numFills + readIdx];

        // Register the signals for next cycle write
        final shouldInvalidate = flop(
            clk, readPort.readWithInvalidate & hit & readPort.en,
            reset: reset);
        final invalidateAddr = flop(clk, getLine(readPort.addr), reset: reset);

        Combinational([
          validBitWrPort.en < shouldInvalidate,
          validBitWrPort.addr < invalidateAddr,
          validBitWrPort.data < Const(0, width: 1), // Invalidate = set to 0
        ]);
      } else {
        // No readWithInvalidate, so no valid bit writes from this read port.
        final validBitWrPort = validBitRfWritePorts[numFills + readIdx];
        validBitWrPort.en <= Const(0);
        validBitWrPort.addr <= Const(0, width: lineAddrWidth);
        validBitWrPort.data <= Const(0, width: 1);
      }
    }

    // Handle evictions if eviction ports are provided.
    if (evictions.isNotEmpty) {
      for (var evictIdx = 0; evictIdx < evictions.length; evictIdx++) {
        final evictPort = evictions[evictIdx];
        final fillPort = fills[evictIdx]; // Corresponding fill port.
        final evictDataReadPort = evictDataRfReadPorts[evictIdx];
        final evictTagReadPort = evictTagRfReadPorts[evictIdx];

        // Read the tag and data at the line being filled
        evictTagReadPort.en <= fillPort.en;
        evictTagReadPort.addr <= getLine(fillPort.addr);

        evictDataReadPort.en <= fillPort.en;
        evictDataReadPort.addr <= getLine(fillPort.addr);

        // Check if the line being filled has valid data (for eviction)
        final validBitRdPort = validBitRfReadPorts[evictIdx];
        final lineValid =
            validBitRdPort.data[0].named('evict${evictIdx}LineValid');

        // Check if this fill is a hit
        final storedTag =
            evictTagReadPort.data.named('evict${evictIdx}StoredTag');
        final requestTag =
            getTag(fillPort.addr).named('evict${evictIdx}RequestTag');
        final fillHasHit = (lineValid & storedTag.eq(requestTag))
            .named('evict${evictIdx}FillHasHit');

        // Two eviction conditions:
        // 1. Allocation eviction: valid fill to a line with valid data (miss)
        //    - overwrites existing valid entry with new data
        // 2. Invalidation eviction: invalid fill that hits
        //    - invalidates an existing entry
        final allocEvictCond = (fillPort.valid & ~fillHasHit & lineValid)
            .named('allocEvictCond$evictIdx');
        final invalEvictCond =
            (~fillPort.valid & fillHasHit).named('invalEvictCond$evictIdx');

        // Construct the eviction address:
        // - For invalidation: use the fill address (which matched)
        // - For allocation: reconstruct from stored tag + line address
        final evictAddrComb =
            Logic(name: 'evictAddrComb$evictIdx', width: fillPort.addrWidth);
        Combinational([
          If(invalEvictCond, then: [
            evictAddrComb < fillPort.addr
          ], orElse: [
            // Reconstruct address from stored tag and line address
            evictAddrComb <
                [evictTagReadPort.data, getLine(fillPort.addr)].swizzle()
          ])
        ]);

        // Drive eviction outputs
        Combinational([
          evictPort.en < (fillPort.en & (invalEvictCond | allocEvictCond)),
          evictPort.valid < (fillPort.en & (invalEvictCond | allocEvictCond)),
          evictPort.addr < evictAddrComb,
          evictPort.data < evictDataReadPort.data,
        ]);
      }
    }
  }
}
