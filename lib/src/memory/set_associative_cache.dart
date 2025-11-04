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

    // Create tag RF interfaces (without valid bit)
    final tagRFMatchFl =
        _genTagRFInterfaces(fills, tagWidth, lineAddrWidth, prefix: 'match_fl');
    final tagRFMatchRd =
        _genTagRFInterfaces(reads, tagWidth, lineAddrWidth, prefix: 'match_rd');
    final tagRFAlloc =
        _genTagRFInterfaces(fills, tagWidth, lineAddrWidth, prefix: 'alloc');

    // Create eviction tag read ports if needed (one per fill port per way)
    final evictTagRfReadPorts = evictions.isNotEmpty
        ? List.generate(
            ways,
            (way) => List.generate(
                numFills,
                (i) => DataPortInterface(tagWidth, lineAddrWidth)
                  ..en.named('evictTagRd_way${way}_port${i}_en')
                  ..addr.named('evictTagRd_way${way}_port${i}_addr')
                  ..data.named('evictTagRd_way${way}_port${i}_data')))
        : <List<DataPortInterface>>[];

    // The Tag `RegisterFile` (without valid bit).
    for (var way = 0; way < ways; way++) {
      // Combine the read and fill match ports for this way.
      final tagRFMatch = [...tagRFMatchFl[way], ...tagRFMatchRd[way]];
      final allTagReadPorts = evictions.isNotEmpty
          ? [...tagRFMatch, ...evictTagRfReadPorts[way]]
          : tagRFMatch;
      RegisterFile(clk, reset, tagRFAlloc[way], allTagReadPorts,
          numEntries: lines, name: 'tag_rf_way$way');
    }

    // Create valid bit register files (one bit wide, indexed by line address).
    // Each way has its own valid bit RF.
    // validBitRF[way][port] where port includes both reads and fills.
    final validBitRFWritePorts = List.generate(
        ways,
        (way) => List.generate(
            numFills + numReads, // Fills + potential read invalidates
            (i) => DataPortInterface(1, lineAddrWidth)
              ..en.named('validBitWr_way${way}_port${i}_en')
              ..addr.named('validBitWr_way${way}_port${i}_addr')
              ..data.named('validBitWr_way${way}_port${i}_data')));

    final validBitRFReadPorts = List.generate(
        ways,
        (way) => List.generate(
            numFills + numReads, // For fill and read checks
            (i) => DataPortInterface(1, lineAddrWidth)
              ..en.named('validBitRd_way${way}_port${i}_en')
              ..addr.named('validBitRd_way${way}_port${i}_addr')
              ..data.named('validBitRd_way${way}_port${i}_data')));

    // Create valid bit register files
    for (var way = 0; way < ways; way++) {
      RegisterFile(
          clk, reset, validBitRFWritePorts[way], validBitRFReadPorts[way],
          numEntries: lines, name: 'valid_bit_rf_way$way');
    }

    // Setup the tag match fill interfaces and valid bit reads for fills.
    for (var flPortIdx = 0; flPortIdx < numFills; flPortIdx++) {
      final flPort = fills[flPortIdx];
      for (var way = 0; way < ways; way++) {
        tagRFMatchFl[way][flPortIdx].addr <= getLine(flPort.addr);
        tagRFMatchFl[way][flPortIdx].en <= flPort.en;

        // Read valid bit for this fill port check
        validBitRFReadPorts[way][flPortIdx].addr <= getLine(flPort.addr);
        validBitRFReadPorts[way][flPortIdx].en <= flPort.en;
      }
    }

    final fillPortValidOneHot = [
      for (var flPortIdx = 0; flPortIdx < numFills; flPortIdx++)
        [
          for (var way = 0; way < ways; way++)
            (validBitRFReadPorts[way][flPortIdx].data[0] &
                    tagRFMatchFl[way][flPortIdx]
                        .data
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

    // Setup the tag match read interfaces and valid bit reads for reads.
    for (var rdPortIdx = 0; rdPortIdx < numReads; rdPortIdx++) {
      final rdPort = reads[rdPortIdx];
      for (var way = 0; way < ways; way++) {
        tagRFMatchRd[way][rdPortIdx].addr <= getLine(rdPort.addr);
        tagRFMatchRd[way][rdPortIdx].en <= rdPort.en;

        // Read valid bit for this read port check
        validBitRFReadPorts[way][numFills + rdPortIdx].addr <=
            getLine(rdPort.addr);
        validBitRFReadPorts[way][numFills + rdPortIdx].en <= rdPort.en;
      }
    }

    final readPortValidOneHot = [
      for (var rdPortIdx = 0; rdPortIdx < numReads; rdPortIdx++)
        [
          for (var way = 0; way < ways; way++)
            (validBitRFReadPorts[way][numFills + rdPortIdx].data[0] &
                    tagRFMatchRd[way][rdPortIdx]
                        .data
                        .eq(getTag(reads[rdPortIdx].addr)))
                .named('match_rd${rdPortIdx}_way$way')
        ]
    ];
    final readValidPortMiss = [
      for (var rdPortIdx = 0; rdPortIdx < numReads; rdPortIdx++)
        (~[
          for (var way = 0; way < ways; way++)
            readPortValidOneHot[rdPortIdx][way]
        ].swizzle().or())
            .named('read_port${rdPortIdx}_miss')
    ];
    final readValidPortWay = [
      for (var rdPortIdx = 0; rdPortIdx < numReads; rdPortIdx++)
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

      // Process allocates (misses) and invalidates with separate tag RF
      // (without valid bit).
      Combinational([
        for (var way = 0; way < ways; way++)
          tagRFAlloc[way][flPortIdx].en < Const(0),
        for (var way = 0; way < ways; way++)
          tagRFAlloc[way][flPortIdx].addr < Const(0, width: lineAddrWidth),
        for (var way = 0; way < ways; way++)
          tagRFAlloc[way][flPortIdx].data < Const(0, width: tagWidth),
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
                            tagRFAlloc[way][flPortIdx].en < flPort.en,
                            tagRFAlloc[way][flPortIdx].addr <
                                Const(line, width: lineAddrWidth),
                            tagRFAlloc[way][flPortIdx].data <
                                getTag(flPort.addr),
                          ]),
                      ElseIf(
                          // Fill with invalidate.
                          ~flPort.valid &
                              Const(way, width: log2Ceil(ways))
                                  .eq(policyInvalPorts[line][flPortIdx].way),
                          [
                            tagRFAlloc[way][flPortIdx].en < flPort.en,
                            tagRFAlloc[way][flPortIdx].addr <
                                Const(line, width: lineAddrWidth),
                            tagRFAlloc[way][flPortIdx].data <
                                getTag(flPort.addr),
                          ]),
                    ])
                ])
        ])
      ]);

      // Handle valid bit updates from fills - write to valid bit RF
      for (var way = 0; way < ways; way++) {
        final matchWay = Const(way, width: log2Ceil(ways));
        final validBitWrPort = validBitRFWritePorts[way][flPortIdx];

        // Need to check which line's policy allocator provides the way
        final allocWayMatches = [
          for (var line = 0; line < lines; line++)
            getLine(flPort.addr).eq(Const(line, width: lineAddrWidth)) &
                policyAllocPorts[line][flPortIdx].way.eq(matchWay)
        ];
        final allocWayMatch = allocWayMatches.isEmpty
            ? Const(0)
            : allocWayMatches.reduce((a, b) => a | b);

        Combinational([
          validBitWrPort.en < Const(0),
          validBitWrPort.addr < Const(0, width: lineAddrWidth),
          validBitWrPort.data < Const(0, width: 1),
          If(flPort.en, then: [
            If.block([
              // Valid fill with hit or miss - set valid bit to 1
              Iff(
                  flPort.valid &
                      (~fillValidPortMiss[flPortIdx] &
                              fillPortValidWay[flPortIdx].eq(matchWay) |
                          fillValidPortMiss[flPortIdx] & allocWayMatch),
                  [
                    validBitWrPort.en < Const(1),
                    validBitWrPort.addr < getLine(flPort.addr),
                    validBitWrPort.data < Const(1, width: 1),
                  ]),
              // Invalid fill (invalidation) - set valid bit to 0
              ElseIf(
                  ~flPort.valid &
                      ~fillValidPortMiss[flPortIdx] &
                      fillPortValidWay[flPortIdx].eq(matchWay),
                  [
                    validBitWrPort.en < Const(1),
                    validBitWrPort.addr < getLine(flPort.addr),
                    validBitWrPort.data < Const(0, width: 1),
                  ]),
            ])
          ])
        ]);
      }
    }
    // The Data `RegisterFile`.
    // Each way has its own RF, indexed by line address.

    // Create eviction data read ports if needed (one per fill port per way)
    final evictDataRfReadPorts = evictions.isNotEmpty
        ? List.generate(
            ways,
            (way) => List.generate(
                numFills,
                (i) => DataPortInterface(dataWidth, lineAddrWidth)
                  ..en.named('evictDataRd_way${way}_port${i}_en')
                  ..addr.named('evictDataRd_way${way}_port${i}_addr')
                  ..data.named('evictDataRd_way${way}_port${i}_data')))
        : <List<DataPortInterface>>[];

    final fillDataPorts =
        _genDataInterfaces(fills, dataWidth, lineAddrWidth, prefix: 'data_fl');
    final readDataPorts =
        _genDataInterfaces(reads, dataWidth, lineAddrWidth, prefix: 'data_rd');

    for (var way = 0; way < ways; way++) {
      final allDataReadPorts = evictions.isNotEmpty
          ? [...readDataPorts[way], ...evictDataRfReadPorts[way]]
          : readDataPorts[way];
      RegisterFile(clk, reset, fillDataPorts[way], allDataReadPorts,
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
      final hasHit = ~readValidPortMiss[rdPortIdx];
      Combinational([
        rdPort.valid < Const(0),
        rdPort.data < Const(0, width: rdPort.dataWidth),
        // for (var way = 0; way < ways; way++)
        //   readDataPorts[way][rdPortIdx].en < Const(0),
        If(rdPort.en & hasHit, then: [
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

      // Handle readWithInvalidate functionality - write to valid bit RF
      // on next cycle.
      if (rdPort.hasReadWithInvalidate) {
        for (var way = 0; way < ways; way++) {
          final matchWay = Const(way, width: log2Ceil(ways));
          final validBitWrPort =
              validBitRFWritePorts[way][numFills + rdPortIdx];

          // Register the signals for next cycle write
          final shouldInvalidate = flop(
              clk,
              rdPort.readWithInvalidate &
                  hasHit &
                  rdPort.en &
                  readValidPortWay[rdPortIdx].eq(matchWay),
              reset: reset);
          final invalidateAddr = flop(clk, getLine(rdPort.addr), reset: reset);

          Combinational([
            validBitWrPort.en < shouldInvalidate,
            validBitWrPort.addr < invalidateAddr,
            validBitWrPort.data < Const(0, width: 1), // Invalidate = set to 0
          ]);
        }
      } else {
        // No readWithInvalidate, so no valid bit writes from this read port.
        for (var way = 0; way < ways; way++) {
          final validBitWrPort =
              validBitRFWritePorts[way][numFills + rdPortIdx];
          validBitWrPort.en <= Const(0);
          validBitWrPort.addr <= Const(0, width: lineAddrWidth);
          validBitWrPort.data <= Const(0, width: 1);
        }
      }
    }

    // Handle evictions if eviction ports are provided.
    if (evictions.isNotEmpty) {
      for (var evictIdx = 0; evictIdx < evictions.length; evictIdx++) {
        final evictPort = evictions[evictIdx];
        final fillPort = fills[evictIdx]; // Corresponding fill port.

        // For each way, read the tag and data at the line being filled
        for (var way = 0; way < ways; way++) {
          final evictTagReadPort = evictTagRfReadPorts[way][evictIdx];
          final evictDataReadPort = evictDataRfReadPorts[way][evictIdx];

          evictTagReadPort.en <= fillPort.en;
          evictTagReadPort.addr <= getLine(fillPort.addr);

          evictDataReadPort.en <= fillPort.en;
          evictDataReadPort.addr <= getLine(fillPort.addr);
        }

        // Determine which way to evict from (use the policy allocator for the
        // line).
        final evictWay =
            Logic(name: 'evict${evictIdx}Way', width: log2Ceil(ways));
        final fillHasHit = ~fillValidPortMiss[evictIdx];

        // Build a multiplexer to select the way based on line
        // Multiplex way selection based on which line is being accessed
        final allocWay =
            Logic(name: 'evict${evictIdx}AllocWay', width: log2Ceil(ways));
        final hitWay =
            Logic(name: 'evict${evictIdx}HitWay', width: log2Ceil(ways));

        if (lines == 1) {
          allocWay <= policyAllocPorts[0][evictIdx].way;
          hitWay <= fillPortValidWay[evictIdx];
        } else {
          final allocCases = <CaseItem>[];
          final hitCases = <CaseItem>[];
          for (var line = 0; line < lines; line++) {
            allocCases.add(CaseItem(Const(line, width: lineAddrWidth),
                [allocWay < policyAllocPorts[line][evictIdx].way]));
            hitCases.add(CaseItem(Const(line, width: lineAddrWidth),
                [hitWay < fillPortValidWay[evictIdx]]));
          }
          Combinational([Case(getLine(fillPort.addr), allocCases)]);
          Combinational([Case(getLine(fillPort.addr), hitCases)]);
        }

        Combinational([
          If(fillHasHit,
              then: [evictWay < hitWay], orElse: [evictWay < allocWay])
        ]);

        // Select tag and data from the evict way
        final evictTag = Logic(name: 'evict${evictIdx}Tag', width: tagWidth);
        final evictData = Logic(name: 'evict${evictIdx}Data', width: dataWidth);

        // Multiplex tag and data based on way
        if (ways == 1) {
          evictTag <= evictTagRfReadPorts[0][evictIdx].data;
          evictData <= evictDataRfReadPorts[0][evictIdx].data;
        } else {
          final tagSelections = <Conditional>[];
          final dataSelections = <Conditional>[];
          for (var way = 0; way < ways; way++) {
            final isThisWay = evictWay.eq(Const(way, width: log2Ceil(ways)));
            tagSelections.add(If(isThisWay,
                then: [evictTag < evictTagRfReadPorts[way][evictIdx].data]));
            dataSelections.add(If(isThisWay,
                then: [evictData < evictDataRfReadPorts[way][evictIdx].data]));
          }
          Combinational([
            evictTag < Const(0, width: tagWidth),
            ...tagSelections,
          ]);
          Combinational([
            evictData < Const(0, width: dataWidth),
            ...dataSelections,
          ]);
        }

        // Check if the way being allocated/hit has a valid entry
        final allocWayValid = Logic(name: 'allocWayValid$evictIdx');
        if (ways == 1) {
          // For single way, read valid bit from way 0
          allocWayValid <= validBitRFReadPorts[0][evictIdx].data[0];
        } else {
          final validSelections = <Logic>[];
          for (var way = 0; way < ways; way++) {
            validSelections.add(evictWay.eq(Const(way, width: log2Ceil(ways))) &
                validBitRFReadPorts[way][evictIdx].data[0]);
          }
          allocWayValid <=
              validSelections
                  .reduce((a, b) => a | b)
                  .named('allocWayValidReduction$evictIdx');
        }

        // Two eviction conditions:
        // 1. Allocation eviction: valid fill to a way with valid data (miss)
        // 2. Invalidation eviction: invalid fill that hits
        final allocEvictCond = (fillPort.valid & ~fillHasHit & allocWayValid)
            .named('allocEvictCond$evictIdx');
        final invalEvictCond =
            (~fillPort.valid & fillHasHit).named('invalEvictCond$evictIdx');

        // Construct the eviction address
        final evictAddrComb =
            Logic(name: 'evictAddrComb$evictIdx', width: fillPort.addrWidth);
        Combinational([
          If(invalEvictCond, then: [
            // For invalidation, use the fill address (which matched)
            evictAddrComb < fillPort.addr
          ], orElse: [
            // For allocation, reconstruct from stored tag and line address
            evictAddrComb < [evictTag, getLine(fillPort.addr)].swizzle()
          ])
        ]);

        // Drive eviction outputs
        Combinational([
          evictPort.en < (fillPort.en & (invalEvictCond | allocEvictCond)),
          evictPort.valid < (fillPort.en & (invalEvictCond | allocEvictCond)),
          evictPort.addr < evictAddrComb,
          evictPort.data < evictData,
        ]);
      }
    }
  }

  /// Generates a 2D list of [DataPortInterface]s for the tag RF (without valid
  /// bit). The dimensions are [ways][ports].
  List<List<DataPortInterface>> _genTagRFInterfaces(
      List<ValidDataPortInterface> ports, int tagWidth, int addressWidth,
      {String prefix = 'tag'}) {
    final dataPorts = [
      for (var way = 0; way < ways; way++)
        [
          for (var r = 0; r < ports.length; r++)
            DataPortInterface(tagWidth, addressWidth)
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
