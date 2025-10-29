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
  DirectMappedCache(
    super.clk,
    super.reset,
    super.fills,
    super.reads, {
    super.lines = 16,
    super.name = 'direct_mapped_cache',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
            definitionName: definitionName ??
                'DirectMappedCache'
                    '_LINES$lines'
                    '_DATA${reads[0].dataWidth}'
                    '_ADDR${reads[0].addrWidth}',
            ways: 1);

  @override
  void buildLogic() {
    final numReads = reads.length;
    final numFills = fills.length;
    final lineAddrWidth = log2Ceil(lines);
    final tagWidth = reads[0].addrWidth - lineAddrWidth;

    // Create register files for tags (with valid bit) and data
    // Since we have 1 way, we only need single register files.
    final tagRfWritePorts = [
      for (var i = 0; i < numFills; i++)
        DataPortInterface(tagWidth + 1, lineAddrWidth)
    ];
    final tagRfReadPorts = [
      for (var i = 0; i < numReads + numFills; i++)
        DataPortInterface(tagWidth + 1, lineAddrWidth)
    ];

    RegisterFile(
      clk,
      reset,
      tagRfWritePorts,
      tagRfReadPorts,
      numEntries: lines,
      name: 'tag_rf',
    );

    // Data register file.
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
      dataRfReadPorts,
      numEntries: lines,
      name: 'data_rf',
    );

    // Handle fill operations.
    for (var fillIdx = 0; fillIdx < numFills; fillIdx++) {
      final fillPort = fills[fillIdx];
      final tagWrPort = tagRfWritePorts[fillIdx];
      final dataWrPort = dataRfWritePorts[fillIdx];

      // Write to tag RF: store valid bit + tag.
      tagWrPort.en <= fillPort.en & fillPort.valid;
      tagWrPort.addr <= getLine(fillPort.addr);
      tagWrPort.data <= [Const(1), getTag(fillPort.addr)].swizzle();

      // Write to data RF
      dataWrPort.en <= fillPort.en & fillPort.valid;
      dataWrPort.addr <= getLine(fillPort.addr);
      dataWrPort.data <= fillPort.data;

      // Read tag for fill port (to check if overwriting)..
      final tagRdPort = tagRfReadPorts[numReads + fillIdx];
      tagRdPort.en <= fillPort.en;
      tagRdPort.addr <= getLine(fillPort.addr);
    }

    // Handle read operations.
    for (var readIdx = 0; readIdx < numReads; readIdx++) {
      final readPort = reads[readIdx];
      final tagRdPort = tagRfReadPorts[readIdx];
      final dataRdPort = dataRfReadPorts[readIdx];

      // Read tag.
      tagRdPort.en <= readPort.en;
      tagRdPort.addr <= getLine(readPort.addr);

      // Read data.
      dataRdPort.en <= readPort.en;
      dataRdPort.addr <= getLine(readPort.addr);

      // Check for cache hit: valid bit is set AND tag matches.
      final validBit = tagRdPort.data[-1];
      final storedTag = tagRdPort.data.slice(tagWidth - 1, 0);
      final requestTag = getTag(readPort.addr);

      final hit = validBit & storedTag.eq(requestTag);

      // Output data and valid signal.
      readPort.data <= dataRdPort.data;
      readPort.valid <= hit;
    }
  }
}
