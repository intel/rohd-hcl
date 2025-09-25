// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cache.dart
// Set-associative cache.
//
// 2025 September 10
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An interface to a cache memory that supplies enable [en], address [addr],
/// [valid] for indicating a hit, and [data].
///
/// Can be used for either read or write direction by grouping signals using
/// [DataPortGroup].
class ValidDataPortInterface extends DataPortInterface {
  /// The "valid" bit for a response when the data is valid.
  Logic get valid => port('valid');

  /// Constructs a new interface of specified [dataWidth] and [addrWidth] for
  /// interacting with a memory in either the read or write direction.
  ValidDataPortInterface(super.dataWidth, super.addrWidth) : super() {
    setPorts([
      Logic.port('valid'),
    ], [
      DataPortGroup.data
    ]);
  }

  /// Makes a copy of this [ValidDataPortInterface] with matching configuration.
  @override
  ValidDataPortInterface clone() =>
      ValidDataPortInterface(dataWidth, addrWidth);
}

/// A module [Cache] implementing a configurable set-associative cache. Two
/// primary operations:
/// - Reading from a cache can result in a hit or miss. The only state change is
///   that on a hit, the ReplacementPolicy is updated.  This is similar to a
///   memory, except that a valid bit is returned with the read data.
/// - Writing to a cache always results in a write into the cache memory,
///   potentially allocating a line in a new way if the data was not present.
///   Externally, this just looks like a memory write.
abstract class Cache extends Module {
  /// Number of ways in the cache line, also know as associativity.
  late final int ways;

  /// Number of lines in the cache.
  late final int lines;

  /// Width of the data stored.
  late final int dataWidth;

  /// Write interfaces which supply address and data to be written.
  @protected
  final List<DataPortInterface> writes = [];

  /// Read interfaces which return data and valid on a read.
  @protected
  final List<ValidDataPortInterface> reads = [];

  /// The replacement policy to use for choosing which way to evict on a miss.
  @protected
  final ReplacementPolicy Function(Logic clk, Logic reset,
      List<AccessInterface> hits, List<AccessInterface> misses,
      {int ways, String name}) replacement;

  /// Clock.
  Logic get clk => input('clk');

  /// Reset.
  Logic get reset => input('reset');

  /// Constructs a [Cache] supporting multiple read and write ports.
  ///
  ///  Defines a set-associativity of [ways] and a depth or number of [lines].
  /// The total capacity of the cache is [ways]*[lines]. The [replacement]
  /// policy is used to choose which way to evict on a write miss.
  Cache(Logic clk, Logic reset, List<DataPortInterface> writes,
      List<ValidDataPortInterface> reads,
      {this.ways = 1,
      this.lines = 16,
      this.replacement = PseudoLRUReplacement.new,
      super.name = 'Cache',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : dataWidth = (writes.isNotEmpty)
            ? writes[0].dataWidth
            : (reads.isNotEmpty)
                ? reads[0].dataWidth
                : 0,
        super(
            definitionName: definitionName ??
                'Cache_WP${writes.length}'
                    '_RP${reads.length}_W${ways}_L$lines') {
    addInput('clk', clk);
    addInput('reset', reset);
    for (var i = 0; i < writes.length; i++) {
      this.writes.add(writes[i].clone()
        ..connectIO(this, writes[i],
            inputTags: {DataPortGroup.control, DataPortGroup.data},
            uniquify: (original) => 'write_${original}_$i'));
    }
    for (var i = 0; i < reads.length; i++) {
      this.reads.add(reads[i].clone()
        ..connectIO(this, reads[i],
            inputTags: {DataPortGroup.control},
            outputTags: {DataPortGroup.data},
            uniquify: (original) => 'read_${original}_$i'));
    }
    _buildLogic();
  }
  @mustBeOverridden
  void _buildLogic();

  /// Extract the tag from the address.
  Logic getTag(Logic addr) => addr.getRange(log2Ceil(lines));

  /// Extract the line index from the address.
  Logic getLine(Logic addr) => addr.slice(log2Ceil(lines) - 1, 0);
}

/// A multi-ported cache.
class MultiPortedCache extends Cache {
  /// Constructs a [Cache] supporting multiple read and write ports.
  ///
  /// Defines a set-associativity of [ways] and a depth or number of [lines].
  /// The total capacity of the cache is [ways]*[lines]. The [replacement]
  /// policy is used to choose which way to evict on a write miss.
  MultiPortedCache(super.clk, super.reset, super.writes, super.reads,
      {super.ways, super.lines, super.replacement});

  @override
  void _buildLogic() {
    final numReads = reads.length;
    final numWrites = writes.length;
    final lineAddrWidth = log2Ceil(lines);
    final tagWidth = reads[0].addrWidth - lineAddrWidth;

    final tagRFMatchWr = _genTagRFInterfaces(writes, tagWidth, lineAddrWidth);
    final tagRFMatchRd = _genTagRFInterfaces(reads, tagWidth, lineAddrWidth);
    final tagRFAlloc = _genTagRFInterfaces(writes, tagWidth, lineAddrWidth);

    // The Tag `RegisterFile`.
    // TODO(desmonddak): need to combine the valid bit of the interface
    // into the RF itself.
    for (var way = 0; way < ways; way++) {
      RegisterFile(clk, reset, tagRFAlloc[way],
          tagRFMatchWr[way]..addAll(tagRFMatchRd[way]),
          numEntries: lines, name: 'tag_rf_way$way');
    }

    // Setup the tag match write interfaces.
    for (var wrPortIdx = 0; wrPortIdx < numWrites; wrPortIdx++) {
      final wrPort = writes[wrPortIdx];
      for (var way = 0; way < ways; way++) {
        tagRFMatchWr[way][wrPortIdx].addr <= getLine(wrPort.addr);
        tagRFMatchWr[way][wrPortIdx].en <= wrPort.en;
      }
    }
    final writePortHitOneHot = [
      for (var wrPortIdx = 0; wrPortIdx < numWrites; wrPortIdx++)
        [
          for (var way = 0; way < ways; way++)
            tagRFMatchWr[way][wrPortIdx].data.eq(getTag(writes[wrPortIdx].addr))
        ]
    ];
    final writePortHitWay = [
      for (var wrPortIdx = 0; wrPortIdx < numWrites; wrPortIdx++)
        RecursivePriorityEncoder(writePortHitOneHot[wrPortIdx].rswizzle())
            .out
            .slice(log2Ceil(ways) - 1, 0)
    ];
    final writePortMiss = [
      for (var wrPortIdx = 0; wrPortIdx < numWrites; wrPortIdx++)
        ~[
          for (var way = 0; way < ways; way++)
            writePortHitOneHot[wrPortIdx][way]
        ].swizzle().or()
    ];

    // Setup the tag match read interfaces.
    for (var rdPortIdx = 0; rdPortIdx < numReads; rdPortIdx++) {
      final rdPort = reads[rdPortIdx];
      for (var way = 0; way < ways; way++) {
        tagRFMatchRd[way][rdPortIdx].addr <= getLine(rdPort.addr);
        tagRFMatchRd[way][rdPortIdx].en <= rdPort.en;
      }
    }

    final readPortHitOneHot = [
      for (var rdPortIdx = 0; rdPortIdx < numReads; rdPortIdx++)
        [
          for (var way = 0; way < ways; way++)
            tagRFMatchRd[way][rdPortIdx].data.eq(getTag(reads[rdPortIdx].addr))
        ]
    ];
    final readPortMiss = [
      for (var rdPortIdx = 0; rdPortIdx < numWrites; rdPortIdx++)
        ~[
          for (var way = 0; way < ways; way++) readPortHitOneHot[rdPortIdx][way]
        ].swizzle().or()
    ];
    final readPortHitWay = [
      for (var wrPortIdx = 0; wrPortIdx < numWrites; wrPortIdx++)
        RecursivePriorityEncoder(readPortHitOneHot[wrPortIdx].rswizzle())
            .out
            .slice(log2Ceil(ways) - 1, 0)
    ];

    // Next, generate the replacment policy logic. Writes and reads both create
    // hits. A write miss causes an allocation followed by a hit.

    final policyWrHitPorts = _genReplacementAccesses(writes);
    final policyRdHitPorts = _genReplacementAccesses(reads);
    final policyAllocPorts = _genReplacementAccesses(writes);

    for (var line = 0; line < lines; line++) {
      replacement(
          clk,
          reset,
          policyWrHitPorts[line]..addAll(policyRdHitPorts[line]),
          policyAllocPorts[line],
          name: 'replacement_line$line',
          ways: ways);
    }

    // Policy: Process write hits.
    for (var wrPortIdx = 0; wrPortIdx < numWrites; wrPortIdx++) {
      final wrPort = writes[wrPortIdx];
      Combinational([
        for (var line = 0; line < lines; line++)
          If(
              wrPort.en &
                  ~writePortMiss[wrPortIdx] &
                  getLine(wrPort.addr).eq(Const(line, width: lineAddrWidth)),
              then: [
                policyWrHitPorts[line][wrPortIdx].access < wrPort.en,
                policyWrHitPorts[line][wrPortIdx].way <
                    writePortHitWay[wrPortIdx],
              ],
              orElse: [
                policyWrHitPorts[line][wrPortIdx].access < Const(0),
                policyWrHitPorts[line][wrPortIdx].way <
                    Const(0, width: log2Ceil(ways))
              ])
      ]);
    }

    // Policy: Process read hits.
    for (var rdPortIdx = 0; rdPortIdx < numReads; rdPortIdx++) {
      final rdPort = reads[rdPortIdx];
      Combinational([
        for (var line = 0; line < lines; line++)
          If(
              rdPort.en &
                  ~readPortMiss[rdPortIdx] &
                  getLine(rdPort.addr).eq(Const(line, width: lineAddrWidth)),
              then: [
                policyRdHitPorts[line][rdPortIdx].access < rdPort.en,
                policyRdHitPorts[line][rdPortIdx].way <
                    readPortHitWay[rdPortIdx],
              ],
              orElse: [
                policyRdHitPorts[line][rdPortIdx].access < Const(0),
                policyRdHitPorts[line][rdPortIdx].way <
                    Const(0, width: log2Ceil(ways))
              ])
      ]);
    }

    // Policy: Process write misses.
    for (var wrPortIdx = 0; wrPortIdx < numWrites; wrPortIdx++) {
      final wrPort = writes[wrPortIdx];
      Combinational([
        for (var line = 0; line < lines; line++)
          If(
              wrPort.en &
                  writePortMiss[wrPortIdx] &
                  getLine(wrPort.addr).eq(Const(line, width: lineAddrWidth)),
              then: [
                policyAllocPorts[line][wrPortIdx].access < wrPort.en,
              ],
              orElse: [
                policyAllocPorts[line][wrPortIdx].access < Const(0),
              ])
      ]);
    }

    // On write miss, write the new tag into the evicted way.
    for (var wrPortIdx = 0; wrPortIdx < numWrites; wrPortIdx++) {
      final wrPort = writes[wrPortIdx];
      Combinational([
        for (var way = 0; way < ways; way++)
          tagRFAlloc[way][wrPortIdx].en < Const(0),
        for (var way = 0; way < ways; way++)
          tagRFAlloc[way][wrPortIdx].addr < Const(0, width: lineAddrWidth),
        for (var way = 0; way < ways; way++)
          tagRFAlloc[way][wrPortIdx].data < Const(0, width: tagWidth),
        for (var way = 0; way < ways; way++)
          tagRFAlloc[way][wrPortIdx].valid < Const(0),
        for (var line = 0; line < lines; line++)
          for (var way = 0; way < ways; way++)
            If(
                wrPort.en &
                    writePortMiss[wrPortIdx] &
                    getLine(wrPort.addr).eq(Const(line, width: lineAddrWidth)) &
                    Const(way, width: log2Ceil(ways))
                        .eq(policyAllocPorts[line][wrPortIdx].way),
                then: [
                  tagRFAlloc[way][wrPortIdx].en < wrPort.en,
                  tagRFAlloc[way][wrPortIdx].addr <
                      Const(line, width: lineAddrWidth),
                  tagRFAlloc[way][wrPortIdx].data < getTag(wrPort.addr),
                  tagRFAlloc[way][wrPortIdx].valid < Const(1),
                ])
      ]);
    }
    // The Data `RegisterFile`.
    // Each way has its own RF, indexed by line address.

    final writeDataPorts = _genDataInterfaces(writes, dataWidth, lineAddrWidth);
    final readDataPorts = _genDataInterfaces(reads, dataWidth, lineAddrWidth);

    for (var way = 0; way < ways; way++) {
      RegisterFile(clk, reset, writeDataPorts[way], readDataPorts[way],
          numEntries: lines, name: 'data_rf_way$way');
    }

    for (var wrPortIdx = 0; wrPortIdx < numWrites; wrPortIdx++) {
      final wrPort = writes[wrPortIdx];
      for (var way = 0; way < ways; way++) {
        final wrRFport = writeDataPorts[way][wrPortIdx];
        Combinational([
          wrRFport.en < Const(0),
          wrRFport.addr < Const(0, width: lineAddrWidth),
          wrRFport.data < Const(0, width: dataWidth),
          for (var line = 0; line < lines; line++)
            If(
                wrPort.en &
                    writePortMiss[wrPortIdx] &
                    policyAllocPorts[line][wrPortIdx].access &
                    policyAllocPorts[line][wrPortIdx]
                        .way
                        .eq(Const(way, width: log2Ceil(ways))),
                then: [
                  wrRFport.addr < getLine(wrPort.addr),
                  wrRFport.data < wrPort.data,
                  wrRFport.en < wrPort.en,
                ])
        ]);
      }
    }

    for (var rdPortIdx = 0; rdPortIdx < numReads; rdPortIdx++) {
      final rdPort = reads[rdPortIdx];
      Combinational([
        rdPort.valid < Const(0),
        rdPort.data < Const(0, width: rdPort.dataWidth),
        for (var way = 0; way < ways; way++)
          If(
              rdPort.en &
                  readPortHitWay[rdPortIdx]
                      .eq(Const(way, width: log2Ceil(ways))),
              then: [
                readDataPorts[way][rdPortIdx].en < rdPort.en,
                readDataPorts[way][rdPortIdx].addr < getLine(rdPort.addr),
                rdPort.data < readDataPorts[way][rdPortIdx].data,
                rdPort.valid < Const(1),
              ],
              orElse: [
                readDataPorts[way][rdPortIdx].en < Const(0),
                readDataPorts[way][rdPortIdx].addr <
                    Const(0, width: lineAddrWidth),
              ])
      ]);
    }
  }

  /// Generates a 2D list of [ValidDataPortInterface]s for the tag RF.
  /// The dimensions are [ways][ports].
  List<List<ValidDataPortInterface>> _genTagRFInterfaces(
          List<DataPortInterface> ports, int tagWidth, int addressWidth) =>
      [
        for (var way = 0; way < ways; way++)
          [
            for (var r = 0; r < ports.length; r++)
              ValidDataPortInterface(tagWidth, addressWidth)
          ]
      ];

  /// Generates a 2D list of [DataPortInterface]s for the data RF.
  /// The dimensions are [ways][ports].
  List<List<DataPortInterface>> _genDataInterfaces(
          List<DataPortInterface> ports, int dataWidth, int addressWidth) =>
      [
        for (var way = 0; way < ways; way++)
          [
            for (var r = 0; r < ports.length; r++)
              DataPortInterface(dataWidth, addressWidth)
          ]
      ];

  /// Generate a 2D list of [AccessInterface]s for the replacement policy.
  List<List<AccessInterface>> _genReplacementAccesses(
          List<DataPortInterface> ports) =>
      [
        for (var line = 0; line < lines; line++)
          [for (var i = 0; i < ports.length; i++) AccessInterface(ways)]
      ];
}
