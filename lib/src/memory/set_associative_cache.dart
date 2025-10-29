// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// set_associative_cache.dart
// Set-associative cache implementation.
//
// 2025 September 10
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A set-associative cache supporting multiple read and fill ports.
class SetAssociativeCache extends Cache {
  /// Constructs a [Cache] supporting multiple read and fill ports.
  ///
  /// Defines a set-associativity of [ways] and a depth or number of [lines].
  /// The total capacity of the cache is [ways]*[lines]. The [replacement]
  /// policy is used to choose which way to evict on a fill miss.
  ///
  /// This cache is a read-cache. It does not track dirty data to implement
  /// write-back. The write policy it would support is a write-around policy.
  SetAssociativeCache(super.clk, super.reset, super.fills, super.reads,
      {super.evictions, super.ways, super.lines, super.replacement});

  @override
  void buildLogic() {
    final numReads = reads.length;
    final numFills = fills.length;
    final lineAddrWidth = log2Ceil(lines);
    final tagWidth = reads[0].addrWidth - lineAddrWidth;

    final validTagRFMatchFl = _genValidTagRFInterfaces(
        fills, tagWidth, lineAddrWidth,
        prefix: 'match_fl');
    final validTagRFMatchRd = _genValidTagRFInterfaces(
        reads, tagWidth, lineAddrWidth,
        prefix: 'match_rd');
    final validTagRFAlloc = _genValidTagRFInterfaces(
        fills, tagWidth, lineAddrWidth,
        prefix: 'alloc');

    // The Tag `RegisterFile`.
    for (var way = 0; way < ways; way++) {
      // Combine the read and fill match ports for this way.
      final validTagRFMatch = [
        ...validTagRFMatchFl[way],
        ...validTagRFMatchRd[way]
      ];
      RegisterFile(clk, reset, validTagRFAlloc[way], validTagRFMatch,
          numEntries: lines, name: 'valid_tag_rf_way$way');
    }

    // Setup the valid tag match fill interfaces.
    for (var flPortIdx = 0; flPortIdx < numFills; flPortIdx++) {
      final flPort = fills[flPortIdx];
      for (var way = 0; way < ways; way++) {
        validTagRFMatchFl[way][flPortIdx].addr <= getLine(flPort.addr);
        validTagRFMatchFl[way][flPortIdx].en <= flPort.en;
      }
    }
    final fillPortValidOneHot = [
      for (var flPortIdx = 0; flPortIdx < numFills; flPortIdx++)
        [
          for (var way = 0; way < ways; way++)
            (validTagRFMatchFl[way][flPortIdx].data[-1] &
                    validTagRFMatchFl[way][flPortIdx]
                        .data
                        .slice(tagWidth - 1, 0)
                        .eq(getTag(fills[flPortIdx].addr)))
                .named('match_fl${flPortIdx}_way$way')
        ]
    ];
    final fillPortValidWay = [
      for (var fillPortIdx = 0; fillPortIdx < numFills; fillPortIdx++)
        RecursivePriorityEncoder(fillPortValidOneHot[fillPortIdx].rswizzle())
            .out
            .slice(log2Ceil(ways) - 1, 0)
            .named('fill_port${fillPortIdx}_way')
    ];
    final fillValidPortMiss = [
      for (var fillPortIdx = 0; fillPortIdx < numFills; fillPortIdx++)
        (~[
          for (var way = 0; way < ways; way++)
            fillPortValidOneHot[fillPortIdx][way]
        ].swizzle().or())
            .named('fill_port${fillPortIdx}_miss')
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
      for (var rdPortIdx = 0; rdPortIdx < numFills; rdPortIdx++)
        (~[
          for (var way = 0; way < ways; way++)
            readPortValidOneHot[rdPortIdx][way]
        ].swizzle().or())
            .named('read_port${rdPortIdx}_miss')
    ];
    final readValidPortWay = [
      for (var rdPortIdx = 0; rdPortIdx < numFills; rdPortIdx++)
        RecursivePriorityEncoder(readPortValidOneHot[rdPortIdx].rswizzle())
            .out
            .slice(log2Ceil(ways) - 1, 0)
            .named('read_port${rdPortIdx}_way')
    ];

    // Generate the replacment policy logic. Fills and reads both create
    // hits. A fill miss causes an allocation followed by a hit.

    final policyFlHitPorts = _genReplacementAccesses(fills, prefix: 'rp_fl');
    final policyRdHitPorts = _genReplacementAccesses(reads, prefix: 'rp_rd');
    final policyAllocPorts = _genReplacementAccesses(fills, prefix: 'rp_alloc');
    final policyInvalPorts = _genReplacementAccesses(fills, prefix: 'rp_inval');

    for (var line = 0; line < lines; line++) {
      replacement(
          clk,
          reset,
          policyFlHitPorts[line]..addAll(policyRdHitPorts[line]),
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
    // Policy: Process fill hits or invalidates.
    for (var flPortIdx = 0; flPortIdx < numFills; flPortIdx++) {
      final flPort = fills[flPortIdx];
      Combinational([
        for (var line = 0; line < lines; line++)
          policyInvalPorts[line][flPortIdx].access < Const(0),
        for (var line = 0; line < lines; line++)
          policyFlHitPorts[line][flPortIdx].access < Const(0),
        If(flPort.en, then: [
          for (var line = 0; line < lines; line++)
            If(getLine(flPort.addr).eq(Const(line, width: lineAddrWidth)),
                then: [
                  If.block([
                    Iff(flPort.valid & ~fillValidPortMiss[flPortIdx], [
                      policyFlHitPorts[line][flPortIdx].access < flPort.en,
                      policyFlHitPorts[line][flPortIdx].way <
                          fillPortValidWay[flPortIdx],
                      // use dataRF eviction ports that parallel flPorts.
                      // Evict flPort.addr + dataRF[l][w][flPortIdx]
                      //    if tagRF[l][w][flPortIdx].valid
                    ]),
                    ElseIf(~flPort.valid, [
                      policyInvalPorts[line][flPortIdx].access < flPort.en,
                      policyInvalPorts[line][flPortIdx].way <
                          fillPortValidWay[flPortIdx],
                      // Evict flPort.addr + dataRF[l][w][flPortIdx]
                      //    if tagRF[l][w][flPortIdx].valid
                    ]),
                  ])
                ])
        ]),
      ]);

      // Policy: Process fill misses.
      for (var line = 0; line < lines; line++) {
        policyAllocPorts[line][flPortIdx].access <=
            flPort.en &
                flPort.valid &
                fillValidPortMiss[flPortIdx] &
                getLine(flPort.addr).eq(Const(line, width: lineAddrWidth));
      }

      // Process allocates (misses) and invalidates. TODO(desmonddak): transform
      // these to simple assignments and check for cleaner SV.
      Combinational([
        for (var way = 0; way < ways; way++)
          validTagRFAlloc[way][flPortIdx].en < Const(0),
        for (var way = 0; way < ways; way++)
          validTagRFAlloc[way][flPortIdx].addr < Const(0, width: lineAddrWidth),
        for (var way = 0; way < ways; way++)
          validTagRFAlloc[way][flPortIdx].data < Const(0, width: tagWidth + 1),
        If(flPort.en, then: [
          for (var line = 0; line < lines; line++)
            If(getLine(flPort.addr).eq(Const(line, width: lineAddrWidth)),
                then: [
                  for (var way = 0; way < ways; way++)
                    If.block([
                      Iff(
                          // Fill with allocate.
                          flPort.valid &
                              fillValidPortMiss[flPortIdx] &
                              Const(way, width: log2Ceil(ways))
                                  .eq(policyAllocPorts[line][flPortIdx].way),
                          [
                            validTagRFAlloc[way][flPortIdx].en < flPort.en,
                            validTagRFAlloc[way][flPortIdx].addr <
                                Const(line, width: lineAddrWidth),
                            validTagRFAlloc[way][flPortIdx].data <
                                [Const(1), getTag(flPort.addr)].swizzle(),
                          ]),
                      ElseIf(
                          // Fill with invalidate.
                          ~flPort.valid &
                              Const(way, width: log2Ceil(ways))
                                  .eq(policyInvalPorts[line][flPortIdx].way),
                          [
                            validTagRFAlloc[way][flPortIdx].en < flPort.en,
                            validTagRFAlloc[way][flPortIdx].addr <
                                Const(line, width: lineAddrWidth),
                            validTagRFAlloc[way][flPortIdx].data <
                                [Const(0), getTag(flPort.addr)].swizzle(),
                          ]),
                    ])
                ])
        ])
      ]);
    }
    // The Data `RegisterFile`.
    // Each way has its own RF, indexed by line address.

    final fillDataPorts =
        _genDataInterfaces(fills, dataWidth, lineAddrWidth, prefix: 'data_fl');
    final readDataPorts =
        _genDataInterfaces(reads, dataWidth, lineAddrWidth, prefix: 'data_rd');

    for (var way = 0; way < ways; way++) {
      RegisterFile(clk, reset, fillDataPorts[way], readDataPorts[way],
          numEntries: lines, name: 'data_rf_way$way');
    }

    for (var flPortIdx = 0; flPortIdx < numFills; flPortIdx++) {
      final flPort = fills[flPortIdx];
      for (var way = 0; way < ways; way++) {
        final matchWay = Const(way, width: log2Ceil(ways));
        final fillRFPort = fillDataPorts[way][flPortIdx];
        Combinational([
          fillRFPort.en < Const(0),
          fillRFPort.addr < Const(0, width: lineAddrWidth),
          fillRFPort.data < Const(0, width: dataWidth),
          If(flPort.en & flPort.valid, then: [
            for (var line = 0; line < lines; line++)
              If(
                  fillValidPortMiss[flPortIdx] &
                          policyAllocPorts[line][flPortIdx].access &
                          policyAllocPorts[line][flPortIdx].way.eq(matchWay) |
                      ~fillValidPortMiss[flPortIdx] &
                          policyFlHitPorts[line][flPortIdx].access &
                          fillPortValidWay[flPortIdx].eq(matchWay),
                  then: [
                    fillRFPort.addr < getLine(flPort.addr),
                    fillRFPort.data < flPort.data,
                    fillRFPort.en < flPort.en,
                  ])
          ])
        ]);
      }
    }

    // Write after read is:
    //   - We first clear RF enable.
    //   - RF.data is set by the storageBank in the RF on the clock edge.
    //   - We read the RF data below after it is written
    // Fix is to put the RF enable clear in the Else of the If below.

    for (var rdPortIdx = 0; rdPortIdx < numReads; rdPortIdx++) {
      final rdPort = reads[rdPortIdx];
      Combinational([
        rdPort.valid < Const(0),
        rdPort.data < Const(0, width: rdPort.dataWidth),
        // for (var way = 0; way < ways; way++)
        //   readDataPorts[way][rdPortIdx].en < Const(0),
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
                ],
                orElse: [
                  readDataPorts[way][rdPortIdx].en < Const(0)
                ])
        ])
      ]);
    }
  }

  /// Generates a 2D list of [DataPortInterface]s for the valid-tag RF.
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
        final fullPrefix = '${prefix}_way${way}_port${r}_way$way';
        dataPorts[way][r].en.named('${fullPrefix}_en');
        dataPorts[way][r].addr.named('${fullPrefix}_addr');
        dataPorts[way][r].data.named('${fullPrefix}_data');
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
