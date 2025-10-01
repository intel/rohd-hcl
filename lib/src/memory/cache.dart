// Copyright (C) 2025 Intel Corporation
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
  /// interacting with a `Cache` in either the read or write direction.
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

/// A module [Cache] implementing a configurable set-associative cache. Three
/// primary operations:
/// - Reading from a cache can result in a hit or miss. The only state change is
///   that on a hit, the [replacement] policy is updated.  This is similar to a
///   memory, except that a valid bit is returned with the read data.
/// - Writing to a cache with a valid bit set results in a write into the cache
///   memory, potentially allocating a line in a new way if the data was not
///   present. Externally, this just looks like a memory write.
/// - Writing to a cache without the valid bit set results in an invalidate of
///   the matching line if present.
abstract class Cache extends Module {
  /// Number of ways in the cache line, also know as associativity.
  late final int ways;

  /// Number of lines in the cache.
  late final int lines;

  /// Width of the data stored.
  late final int dataWidth;

  /// Write interfaces which supply address and data to be written.
  @protected
  final List<ValidDataPortInterface> writes = [];

  /// Read interfaces which return data and valid on a read.
  @protected
  final List<ValidDataPortInterface> reads = [];

  /// The replacement policy to use for choosing which way to evict on a miss.
  @protected
  final ReplacementPolicy Function(
      Logic clk,
      Logic reset,
      List<AccessInterface> hits,
      List<AccessInterface> misses,
      List<AccessInterface> invalidates,
      {int ways,
      String name}) replacement;

  /// Clock.
  Logic get clk => input('clk');

  /// Reset.
  Logic get reset => input('reset');

  /// Constructs a [Cache] supporting multiple read and write ports.
  ///
  /// Defines a set-associativity of [ways] and a depth or number of [lines].
  /// The total capacity of the cache is [ways]*[lines]. The [replacement]
  /// policy is used to choose which way to evict on a write miss.
  Cache(Logic clk, Logic reset, List<ValidDataPortInterface> writes,
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
            uniquify: (original) => 'cwr_${original}_$i'));
    }
    for (var i = 0; i < reads.length; i++) {
      this.reads.add(reads[i].clone()
        ..connectIO(this, reads[i],
            inputTags: {DataPortGroup.control},
            outputTags: {DataPortGroup.data},
            uniquify: (original) => 'crd_${original}_$i'));
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

    final validTagRFMatchWr = _genValidTagRFInterfaces(
        writes, tagWidth, lineAddrWidth,
        prefix: 'match_wr');
    final validTagRFMatchRd = _genValidTagRFInterfaces(
        reads, tagWidth, lineAddrWidth,
        prefix: 'match_rd');
    final validTagRFAlloc = _genValidTagRFInterfaces(
        writes, tagWidth, lineAddrWidth,
        prefix: 'alloc');

    // The Tag `RegisterFile`.
    for (var way = 0; way < ways; way++) {
      // Combine the read and write match ports for this way.
      final validTagRFMatch = validTagRFMatchWr[way]
        ..addAll(validTagRFMatchRd[way]);
      RegisterFile(clk, reset, validTagRFAlloc[way], validTagRFMatch,
          numEntries: lines, name: 'valid_tag_rf_way$way');
    }

    // Setup the valid tag match write interfaces.
    for (var wrPortIdx = 0; wrPortIdx < numWrites; wrPortIdx++) {
      final wrPort = writes[wrPortIdx];
      for (var way = 0; way < ways; way++) {
        validTagRFMatchWr[way][wrPortIdx].addr <= getLine(wrPort.addr);
        validTagRFMatchWr[way][wrPortIdx].en <= wrPort.en;
      }
    }
    final writePortValidOneHot = [
      for (var wrPortIdx = 0; wrPortIdx < numWrites; wrPortIdx++)
        [
          for (var way = 0; way < ways; way++)
            (validTagRFMatchWr[way][wrPortIdx].data[-1] &
                    validTagRFMatchWr[way][wrPortIdx]
                        .data
                        .slice(tagWidth - 1, 0)
                        .eq(getTag(writes[wrPortIdx].addr)))
                .named('match_wr${wrPortIdx}_way$way')
        ]
    ];
    final writePortValidWay = [
      for (var wrPortIdx = 0; wrPortIdx < numWrites; wrPortIdx++)
        RecursivePriorityEncoder(writePortValidOneHot[wrPortIdx].rswizzle())
            .out
            .slice(log2Ceil(ways) - 1, 0)
            .named('write_port${wrPortIdx}_way')
    ];
    final writeValidPortMiss = [
      for (var wrPortIdx = 0; wrPortIdx < numWrites; wrPortIdx++)
        (~[
          for (var way = 0; way < ways; way++)
            writePortValidOneHot[wrPortIdx][way]
        ].swizzle().or())
            .named('write_port${wrPortIdx}_miss')
    ];

    // Setup the tag match read interfaces.
    for (var rdPortIdx = 0; rdPortIdx < numReads; rdPortIdx++) {
      final rdPort = reads[rdPortIdx];
      for (var way = 0; way < ways; way++) {
        validTagRFMatchRd[way][rdPortIdx].addr <= getLine(rdPort.addr);
        validTagRFMatchRd[way][rdPortIdx].en <= rdPort.en;
      }
    }
    final readPortValidOneHot = [
      for (var rdPortIdx = 0; rdPortIdx < numReads; rdPortIdx++)
        [
          for (var way = 0; way < ways; way++)
            (validTagRFMatchRd[way][rdPortIdx].data[-1] &
                    validTagRFMatchRd[way][rdPortIdx]
                        .data
                        .slice(tagWidth - 1, 0)
                        .eq(getTag(reads[rdPortIdx].addr)))
                .named('match_rd${rdPortIdx}_way$way')
        ]
    ];
    final readValidPortMiss = [
      for (var rdPortIdx = 0; rdPortIdx < numWrites; rdPortIdx++)
        (~[
          for (var way = 0; way < ways; way++)
            readPortValidOneHot[rdPortIdx][way]
        ].swizzle().or())
            .named('read_port${rdPortIdx}_miss')
    ];
    final readValidPortWay = [
      for (var rdPortIdx = 0; rdPortIdx < numWrites; rdPortIdx++)
        RecursivePriorityEncoder(readPortValidOneHot[rdPortIdx].rswizzle())
            .out
            .slice(log2Ceil(ways) - 1, 0)
            .named('read_port${rdPortIdx}_way')
    ];

    // Generate the replacment policy logic. Writes and reads both create
    // hits. A write miss causes an allocation followed by a hit.

    final policyWrHitPorts = _genReplacementAccesses(writes, prefix: 'rp_wr');
    final policyRdHitPorts = _genReplacementAccesses(reads, prefix: 'rp_rd');
    final policyAllocPorts =
        _genReplacementAccesses(writes, prefix: 'rp_alloc');
    final policyInvalPorts =
        _genReplacementAccesses(writes, prefix: 'rp_inval');

    for (var line = 0; line < lines; line++) {
      replacement(
          clk,
          reset,
          policyWrHitPorts[line]..addAll(policyRdHitPorts[line]),
          policyAllocPorts[line],
          policyInvalPorts[line],
          name: 'rp_line$line',
          ways: ways);
    }

    // Policy: Process read hits.
    for (var rdPortIdx = 0; rdPortIdx < numReads; rdPortIdx++) {
      final rdPort = reads[rdPortIdx];
      for (var line = 0; line < lines; line++) {
        policyRdHitPorts[line][rdPortIdx].access <=
            rdPort.en &
                ~readValidPortMiss[rdPortIdx] &
                getLine(rdPort.addr).eq(Const(line, width: lineAddrWidth));
        policyRdHitPorts[line][rdPortIdx].way <= readValidPortWay[rdPortIdx];
      }
    }
    // Policy: Process write hits or invalidates.
    for (var wrPortIdx = 0; wrPortIdx < numWrites; wrPortIdx++) {
      final wrPort = writes[wrPortIdx];
      Combinational([
        for (var line = 0; line < lines; line++)
          policyInvalPorts[line][wrPortIdx].access < Const(0),
        for (var line = 0; line < lines; line++)
          policyWrHitPorts[line][wrPortIdx].access < Const(0),
        If(wrPort.en, then: [
          for (var line = 0; line < lines; line++)
            If(getLine(wrPort.addr).eq(Const(line, width: lineAddrWidth)),
                then: [
                  If.block([
                    Iff(wrPort.valid & ~writeValidPortMiss[wrPortIdx], [
                      policyWrHitPorts[line][wrPortIdx].access < wrPort.en,
                      policyWrHitPorts[line][wrPortIdx].way <
                          writePortValidWay[wrPortIdx],
                    ]),
                    ElseIf(~wrPort.valid, [
                      policyInvalPorts[line][wrPortIdx].access < wrPort.en,
                      policyInvalPorts[line][wrPortIdx].way <
                          writePortValidWay[wrPortIdx],
                    ]),
                  ])
                ])
        ]),
      ]);

      // Policy: Process write misses.
      for (var line = 0; line < lines; line++) {
        policyAllocPorts[line][wrPortIdx].access <=
            wrPort.en &
                wrPort.valid &
                writeValidPortMiss[wrPortIdx] &
                getLine(wrPort.addr).eq(Const(line, width: lineAddrWidth));
      }

      // Process allocates (misses) and invalidates. TODO(desmonddak): transform
      // these to simple assignments and check for cleaner SV.
      Combinational([
        for (var way = 0; way < ways; way++)
          validTagRFAlloc[way][wrPortIdx].en < Const(0),
        for (var way = 0; way < ways; way++)
          validTagRFAlloc[way][wrPortIdx].addr < Const(0, width: lineAddrWidth),
        for (var way = 0; way < ways; way++)
          validTagRFAlloc[way][wrPortIdx].data < Const(0, width: tagWidth + 1),
        If(wrPort.en, then: [
          for (var line = 0; line < lines; line++)
            If(getLine(wrPort.addr).eq(Const(line, width: lineAddrWidth)),
                then: [
                  for (var way = 0; way < ways; way++)
                    If.block([
                      Iff(
                          // Write with allocate.
                          wrPort.valid &
                              writeValidPortMiss[wrPortIdx] &
                              Const(way, width: log2Ceil(ways))
                                  .eq(policyAllocPorts[line][wrPortIdx].way),
                          [
                            validTagRFAlloc[way][wrPortIdx].en < wrPort.en,
                            validTagRFAlloc[way][wrPortIdx].addr <
                                Const(line, width: lineAddrWidth),
                            validTagRFAlloc[way][wrPortIdx].data <
                                [Const(1), getTag(wrPort.addr)].swizzle(),
                          ]),
                      ElseIf(
                          // Write with invalidate.
                          ~wrPort.valid &
                              Const(way, width: log2Ceil(ways))
                                  .eq(policyInvalPorts[line][wrPortIdx].way),
                          [
                            validTagRFAlloc[way][wrPortIdx].en < wrPort.en,
                            validTagRFAlloc[way][wrPortIdx].addr <
                                Const(line, width: lineAddrWidth),
                            validTagRFAlloc[way][wrPortIdx].data <
                                [Const(0), getTag(wrPort.addr)].swizzle(),
                          ]),
                    ])
                ])
        ])
      ]);
    }
    // The Data `RegisterFile`.
    // Each way has its own RF, indexed by line address.

    final writeDataPorts =
        _genDataInterfaces(writes, dataWidth, lineAddrWidth, prefix: 'data_wr');
    final readDataPorts =
        _genDataInterfaces(reads, dataWidth, lineAddrWidth, prefix: 'data_rd');

    for (var way = 0; way < ways; way++) {
      RegisterFile(clk, reset, writeDataPorts[way], readDataPorts[way],
          numEntries: lines, name: 'data_rf_way$way');
    }

    for (var wrPortIdx = 0; wrPortIdx < numWrites; wrPortIdx++) {
      final wrPort = writes[wrPortIdx];
      for (var way = 0; way < ways; way++) {
        final matchWay = Const(way, width: log2Ceil(ways));
        final wrRFport = writeDataPorts[way][wrPortIdx];
        Combinational([
          wrRFport.en < Const(0),
          wrRFport.addr < Const(0, width: lineAddrWidth),
          wrRFport.data < Const(0, width: dataWidth),
          If(wrPort.en & wrPort.valid, then: [
            for (var line = 0; line < lines; line++)
              If(
                  writeValidPortMiss[wrPortIdx] &
                          policyAllocPorts[line][wrPortIdx].access &
                          policyAllocPorts[line][wrPortIdx].way.eq(matchWay) |
                      ~writeValidPortMiss[wrPortIdx] &
                          policyWrHitPorts[line][wrPortIdx].access &
                          writePortValidWay[wrPortIdx].eq(matchWay),
                  then: [
                    wrRFport.addr < getLine(wrPort.addr),
                    wrRFport.data < wrPort.data,
                    wrRFport.en < wrPort.en,
                  ])
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
          readDataPorts[way][rdPortIdx].en < Const(0),
        If(rdPort.en & ~readValidPortMiss[rdPortIdx], then: [
          for (var way = 0; way < ways; way++)
            If(
                readValidPortWay[rdPortIdx]
                    .eq(Const(way, width: log2Ceil(ways))),
                then: [
                  readDataPorts[way][rdPortIdx].en < rdPort.en,
                  readDataPorts[way][rdPortIdx].addr < getLine(rdPort.addr),
                  rdPort.data < readDataPorts[way][rdPortIdx].data,
                  rdPort.valid < Const(1),
                ])
        ])
      ]);
    }
  }

  /// Generates a 2D list of [DataPortInterface]s for the vakud-tag RF.
  /// The dimensions are [ways][ports].
  List<List<DataPortInterface>> _genValidTagRFInterfaces(
      List<ValidDataPortInterface> ports, int tagWidth, int addressWidth,
      {String prefix = 'tag'}) {
    final dataPorts = [
      for (var way = 0; way < ways; way++)
        [
          for (var r = 0; r < ports.length; r++)
            DataPortInterface(tagWidth + 1, addressWidth)
        ]
    ];
    for (var way = 0; way < ways; way++) {
      for (var r = 0; r < ports.length; r++) {
        dataPorts[way][r].en.named('${prefix}_port${r}_way${way}_en');
        dataPorts[way][r].addr.named('${prefix}_port${r}_way${way}_addr');
        dataPorts[way][r].data.named('${prefix}_port${r}_way${way}_data');
      }
    }
    return dataPorts;
  }

  /// Generates a 2D list of [DataPortInterface]s for the data RF.
  /// The dimensions are [ways][ports].
  List<List<DataPortInterface>> _genDataInterfaces(
      List<DataPortInterface> ports, int dataWidth, int addressWidth,
      {String prefix = 'data'}) {
    final dataPorts = [
      for (var way = 0; way < ways; way++)
        [
          for (var r = 0; r < ports.length; r++)
            DataPortInterface(dataWidth, addressWidth)
        ]
    ];
    for (var way = 0; way < ways; way++) {
      for (var r = 0; r < ports.length; r++) {
        dataPorts[way][r].en.named('${prefix}_port${r}_way${way}_en');
        dataPorts[way][r].addr.named('${prefix}_port${r}_way${way}_addr');
        dataPorts[way][r].data.named('${prefix}_port${r}_way${way}_data');
      }
    }
    return dataPorts;
  }

  /// Generate a 2D list of [AccessInterface]s for the replacement policy.
  List<List<AccessInterface>> _genReplacementAccesses(
      List<DataPortInterface> ports,
      {String prefix = 'replace'}) {
    final dataPorts = [
      for (var line = 0; line < lines; line++)
        [for (var i = 0; i < ports.length; i++) AccessInterface(ways)]
    ];

    for (var line = 0; line < lines; line++) {
      for (var r = 0; r < ports.length; r++) {
        dataPorts[line][r]
            .access
            .named('${prefix}_line${line}_port${r}_access');
        dataPorts[line][r].way.named('${prefix}_line${line}_port${r}_way');
      }
    }
    return dataPorts;
  }
}
