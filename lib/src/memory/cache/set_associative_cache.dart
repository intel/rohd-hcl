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
  late int _lineAddrWidth;
  late int _tagWidth;
  late int _dataWidth;

  /// Tag register files, one per way.
  late final List<RegisterFile> tagRFs;

  /// Valid bit register files, one per way.
  late final List<RegisterFile> validBitRFs;

  /// Data register files, one per way.l
  late final List<RegisterFile> dataRFs;

  /// Constructs a [Cache] supporting multiple read and fill ports.
  ///
  /// Defines a set-associativity of [ways] and a depth or number of [lines].
  /// The total capacity of the cache is [ways]*[lines]. The [replacement]
  /// policy is used to choose which way to evict on a fill miss.
  ///
  /// This cache is a read-cache. It does not track dirty data to implement
  /// write-back. The write policy it would support is a write-around policy.
  SetAssociativeCache(super.clk, super.reset, super.fills, super.reads,
      {super.ways, super.lines, super.replacement});

  @override
  void buildLogic() {
    _lineAddrWidth = log2Ceil(lines);
    _tagWidth = reads.isNotEmpty ? reads[0].addrWidth - _lineAddrWidth : 0;
    _dataWidth = dataWidth;

    final numFills = fills.length;
    final numReads = reads.length;
    final hasEvictions = fills.isNotEmpty && fills[0].eviction != null;

    // Construct tag RFs per-way; build the small per-way interface lists
    // at construction time instead of pre-building 2D arrays.
    tagRFs = List<RegisterFile>.generate(
        ways,
        (way) => RegisterFile(
            clk,
            reset,
            List.generate(numFills,
                (port) => DataPortInterface(_tagWidth, _lineAddrWidth)),
            [
              ...List.generate(numFills,
                  (port) => DataPortInterface(_tagWidth, _lineAddrWidth)),
              ...List.generate(numReads,
                  (port) => DataPortInterface(_tagWidth, _lineAddrWidth)),
              if (hasEvictions)
                ...List.generate(numFills,
                    (port) => DataPortInterface(_tagWidth, _lineAddrWidth))
            ],
            numEntries: lines,
            name: 'tag_rf_way$way'));

    // Construct valid-bit RFs per-way with write/read ports ordered as
    // (fills first, then reads).
    validBitRFs = List<RegisterFile>.generate(
        ways,
        (way) => RegisterFile(
            clk,
            reset,
            List.generate(numFills + numReads,
                (port) => DataPortInterface(1, _lineAddrWidth)),
            List.generate(numFills + numReads,
                (port) => DataPortInterface(1, _lineAddrWidth)),
            numEntries: lines,
            name: 'valid_bit_rf_way$way'));

    // Instantiate one replacement policy module per cache line using the
    // line-major arrays directly. Initialize replacement instance list.
    lineReplacementPolicy = List.generate(
        lines,
        (line) => replacement(
            clk,
            reset,
            [
              ...List.generate(numFills, (port) => AccessInterface(ways)),
              ...List.generate(numReads, (port) => AccessInterface(ways))
            ],
            [...List.generate(numFills, (port) => AccessInterface(ways))],
            [
              ...List.generate(numFills, (port) => AccessInterface(ways)),
              ...List.generate(numReads, (port) => AccessInterface(ways))
            ],
            name: 'rp_line$line',
            ways: ways));

    // Construct data RFs per-way with read ports (reads first, then evicts if
    // present) and fill write ports for fills.
    dataRFs = List<RegisterFile>.generate(
        ways,
        (way) => RegisterFile(
            clk,
            reset,
            List.generate(numFills,
                (port) => DataPortInterface(_dataWidth, _lineAddrWidth)),
            [
              ...List.generate(numReads,
                  (port) => DataPortInterface(_dataWidth, _lineAddrWidth)),
              if (hasEvictions)
                ...List.generate(numFills,
                    (port) => DataPortInterface(_dataWidth, _lineAddrWidth))
            ],
            numEntries: lines,
            name: 'data_rf_way$way'));

    for (var flPortIdx = 0; flPortIdx < numFills; flPortIdx++) {
      // Call helper which will index the class-level policyByLine arrays
      // for the current fill port.
      _fillPortHookup(
          flPortIdx,
          fills[flPortIdx].fill,
          hasEvictions ? fills[flPortIdx].eviction : null,
          hasEvictions ? flPortIdx.toString() : null);
    }

    for (var rdPortIdx = 0; rdPortIdx < numReads; rdPortIdx++) {
      _readPortHookup(rdPortIdx, reads[rdPortIdx]);
    }
  }

  /// Wire a read port.
  void _readPortHookup(int rdPortIdx, ValidDataPortInterface rdPort) {
    final numFills = fills.length;
    for (var way = 0; way < ways; way++) {
      validBitRFs[way].reads[numFills + rdPortIdx].en <= rdPort.en;
      validBitRFs[way].reads[numFills + rdPortIdx].addr <= getLine(rdPort.addr);
      tagRFs[way].reads[numFills + rdPortIdx].en <= rdPort.en;
      tagRFs[way].reads[numFills + rdPortIdx].addr <= getLine(rdPort.addr);
    }

    final readPortValidOneHot = [
      for (var way = 0; way < ways; way++)
        (validBitRFs[way].reads[numFills + rdPortIdx].data[0] &
                tagRFs[way]
                    .reads[numFills + rdPortIdx]
                    .data
                    .eq(getTag(rdPort.addr)))
            .named('match_rd_port${rdPort.name}_way$way')
    ];
    final readPortValidWay =
        RecursivePriorityEncoder(readPortValidOneHot.rswizzle())
            .out
            .slice(log2Ceil(ways) - 1, 0)
            .named('${rdPort.name}_valid_way');

    // Combine one-hot hit indicators into a single "any-hit" signal.
    final readPortValidAny = readPortValidOneHot.swizzle().or();

    final readMiss = (~readPortValidAny).named('read_port_${rdPort.name}_miss');
    final hasHit = ~readMiss;

    // Drive read outputs: defaults then per-way gated assignments.
    Combinational([
      rdPort.valid < Const(0),
      rdPort.data < Const(0, width: rdPort.dataWidth),
      for (var way = 0; way < ways; way++)
        If(
            readPortValidWay.eq(Const(way, width: log2Ceil(ways))) &
                rdPort.en &
                hasHit,
            then: [
              dataRFs[way].reads[rdPortIdx].en < rdPort.en,
              dataRFs[way].reads[rdPortIdx].addr < getLine(rdPort.addr),
              rdPort.data < dataRFs[way].reads[rdPortIdx].data,
              rdPort.valid < Const(1),
            ],
            orElse: [
              dataRFs[way].reads[rdPortIdx].en < Const(0)
            ])
    ]);

    for (var line = 0; line < lines; line++) {
      lineReplacementPolicy[line].hits[numFills + rdPortIdx].access <=
          rdPort.en &
              ~readMiss &
              getLine(rdPort.addr).eq(Const(line, width: _lineAddrWidth));
      lineReplacementPolicy[line].hits[numFills + rdPortIdx].way <=
          readPortValidWay;
    }

    if (rdPort.hasReadWithInvalidate) {
      for (var way = 0; way < ways; way++) {
        final matchWay = Const(way, width: log2Ceil(ways));
        final validBitWrPort = validBitRFs[way].writes[numFills + rdPortIdx];

        final shouldInvalidate = flop(
            clk,
            rdPort.readWithInvalidate &
                hasHit &
                rdPort.en &
                readPortValidWay.eq(matchWay),
            reset: reset);
        final invalidateAddr = flop(clk, getLine(rdPort.addr), reset: reset);

        Combinational([
          validBitWrPort.en < shouldInvalidate,
          validBitWrPort.addr < invalidateAddr,
          validBitWrPort.data < Const(0, width: 1),
        ]);
      }

      // Notify replacement policy about RWI invalidates (flopped, like valid
      // bit updates)
      final shouldInvalidateAny = flop(
          clk, rdPort.readWithInvalidate & hasHit & rdPort.en,
          reset: reset);
      final invalidateAddr = flop(clk, getLine(rdPort.addr), reset: reset);

      for (var line = 0; line < lines; line++) {
        lineReplacementPolicy[line].invalidates[numFills + rdPortIdx].access <=
            shouldInvalidateAny &
                invalidateAddr.eq(Const(line, width: _lineAddrWidth));
        lineReplacementPolicy[line].invalidates[numFills + rdPortIdx].way <=
            flop(clk, readPortValidWay, reset: reset);
      }
    } else {
      for (var way = 0; way < ways; way++) {
        final validBitWrPort = validBitRFs[way].writes[numFills + rdPortIdx];
        validBitWrPort.en <= Const(0);
        validBitWrPort.addr <= Const(0, width: _lineAddrWidth);
        validBitWrPort.data <= Const(0, width: 1);
      }

      // No RWI invalidates for this read port
      for (var line = 0; line < lines; line++) {
        lineReplacementPolicy[line].invalidates[numFills + rdPortIdx].access <=
            Const(0);
        lineReplacementPolicy[line].invalidates[numFills + rdPortIdx].way <=
            Const(0, width: log2Ceil(ways));
      }
    }
  }

  // Wire a fill port.
  void _fillPortHookup(int flPortIdx, ValidDataPortInterface flPort,
      ValidDataPortInterface? evictPort, String? nameSuffix) {
    final numFills = fills.length;
    final numReads = reads.length;
    final ways = this.ways;

    for (var way = 0; way < ways; way++) {
      validBitRFs[way].reads[flPortIdx].en <= flPort.en;
      validBitRFs[way].reads[flPortIdx].addr <= getLine(flPort.addr);
      tagRFs[way].reads[flPortIdx].en <= flPort.en;
      tagRFs[way].reads[flPortIdx].addr <= getLine(flPort.addr);
    }

    final fillPortValidOneHot = [
      for (var way = 0; way < ways; way++)
        (validBitRFs[way].reads[flPortIdx].data[0] &
                tagRFs[way].reads[flPortIdx].data.eq(getTag(flPort.addr)))
            .named('match_fl${nameSuffix ?? ''}_way$way')
    ];
    final fillPortValidWay =
        RecursivePriorityEncoder(fillPortValidOneHot.rswizzle())
            .out
            .slice(log2Ceil(ways) - 1, 0)
            .named('fill_port${nameSuffix ?? ''}_way');

    final fillPortValidAny = fillPortValidOneHot.swizzle().or();
    final fillMiss =
        (~fillPortValidAny).named('fill_port${nameSuffix ?? ''}_miss');

    if (evictPort != null) {
      for (var way = 0; way < ways; way++) {
        tagRFs[way].reads[numFills + numReads + flPortIdx].en <= flPort.en;
        tagRFs[way].reads[numFills + numReads + flPortIdx].addr <=
            getLine(flPort.addr);
        dataRFs[way].reads[numReads + flPortIdx].en <= flPort.en;
        dataRFs[way].reads[numReads + flPortIdx].addr <= getLine(flPort.addr);
      }

      final allocWay = Logic(
          name: 'evict${nameSuffix ?? ''}AllocWay', width: log2Ceil(ways));
      final hitWay =
          Logic(name: 'evict${nameSuffix ?? ''}HitWay', width: log2Ceil(ways));

      if (lines == 1) {
        allocWay <= lineReplacementPolicy[0].allocs[flPortIdx].way;
        hitWay <= fillPortValidWay;
      } else {
        Combinational([
          Case(getLine(flPort.addr), [
            for (var line = 0; line < lines; line++)
              CaseItem(Const(line, width: _lineAddrWidth), [
                allocWay < lineReplacementPolicy[line].allocs[flPortIdx].way
              ])
          ])
        ]);
        Combinational([hitWay < fillPortValidWay]);
      }

      // Compute whether the fill hit any way and select an eviction way.
      final fillHasHit = (~fillMiss).named('fill_has_hit${nameSuffix ?? ''}');
      final evictWay = mux(fillHasHit, hitWay, allocWay)
          .named('evict${nameSuffix ?? ''}Way');

      final evictTag =
          Logic(name: 'evict${nameSuffix ?? ''}Tag', width: _tagWidth);
      final evictData =
          Logic(name: 'evict${nameSuffix ?? ''}Data', width: _dataWidth);
      final allocWayValid = Logic(name: 'allocWayValid${nameSuffix ?? ''}');

      if (ways == 1) {
        evictTag <= tagRFs[0].reads[numFills + numReads + flPortIdx].data;
        evictData <= dataRFs[0].reads[numReads + flPortIdx].data;
        allocWayValid <= validBitRFs[0].reads[flPortIdx].data[0];
      } else {
        Combinational([
          evictTag < Const(0, width: _tagWidth),
          evictData < Const(0, width: _dataWidth),
          for (var way = 0; way < ways; way++)
            If(evictWay.eq(Const(way, width: log2Ceil(ways))), then: [
              evictTag <
                  tagRFs[way].reads[numFills + numReads + flPortIdx].data,
              evictData < dataRFs[way].reads[numReads + flPortIdx].data,
            ])
        ]);

        // Multi-way allocation valid reduction: any selected evict way that
        // has its valid bit set makes the allocation-way-valid true.
        final allocSel = [
          for (var way = 0; way < ways; way++)
            evictWay.eq(Const(way, width: log2Ceil(ways))) &
                validBitRFs[way].reads[flPortIdx].data[0]
        ];
        allocWayValid <=
            allocSel
                .swizzle()
                .or()
                .named('allocWayValidReduction${nameSuffix ?? ''}');
      }

      final allocEvictCond = (flPort.valid & ~fillHasHit & allocWayValid)
          .named('allocEvictCond${nameSuffix ?? ''}');
      final invalEvictCond = (~flPort.valid & fillHasHit)
          .named('invalEvictCond${nameSuffix ?? ''}');

      final evictAddrComb = Logic(
          name: 'evictAddrComb${nameSuffix ?? ''}', width: flPort.addrWidth);
      Combinational([
        evictAddrComb <
            mux(invalEvictCond, flPort.addr,
                [evictTag, getLine(flPort.addr)].swizzle())
      ]);

      Combinational([
        evictPort.en < (flPort.en & (invalEvictCond | allocEvictCond)),
        evictPort.valid < (flPort.en & (invalEvictCond | allocEvictCond)),
        evictPort.addr < evictAddrComb,
        evictPort.data < evictData,
      ]);
    }

    // Default combinational setup for policy hit/inval signals and per-line
    // selection.
    Combinational([
      for (var line = 0; line < lines; line++)
        lineReplacementPolicy[line].invalidates[flPortIdx].access < Const(0),
      for (var line = 0; line < lines; line++)
        lineReplacementPolicy[line].hits[flPortIdx].access < Const(0),
      If(flPort.en, then: [
        for (var line = 0; line < lines; line++)
          If(getLine(flPort.addr).eq(Const(line, width: _lineAddrWidth)),
              then: [
                If.block([
                  Iff(flPort.valid & ~fillMiss, [
                    lineReplacementPolicy[line].hits[flPortIdx].access <
                        flPort.en,
                    lineReplacementPolicy[line].hits[flPortIdx].way <
                        fillPortValidWay,
                  ]),
                  ElseIf(~flPort.valid, [
                    lineReplacementPolicy[line].invalidates[flPortIdx].access <
                        flPort.en,
                    lineReplacementPolicy[line].invalidates[flPortIdx].way <
                        fillPortValidWay,
                  ]),
                ])
              ])
      ])
    ]);

    // Alloc access signals per-line.
    for (var line = 0; line < lines; line++) {
      lineReplacementPolicy[line].allocs[flPortIdx].access <=
          flPort.en &
              flPort.valid &
              fillMiss &
              getLine(flPort.addr).eq(Const(
                line,
                width: _lineAddrWidth,
              ));
    }

    // Tag allocations.
    Combinational([
      for (var way = 0; way < ways; way++)
        tagRFs[way].writes[flPortIdx].en < Const(0),
      for (var way = 0; way < ways; way++)
        tagRFs[way].writes[flPortIdx].addr < Const(0, width: _lineAddrWidth),
      for (var way = 0; way < ways; way++)
        tagRFs[way].writes[flPortIdx].data < Const(0, width: _tagWidth),
      If(flPort.en, then: [
        for (var line = 0; line < lines; line++)
          If(getLine(flPort.addr).eq(Const(line, width: _lineAddrWidth)),
              then: [
                for (var way = 0; way < ways; way++)
                  If.block([
                    Iff(
                        flPort.valid &
                            fillMiss &
                            Const(way, width: log2Ceil(ways)).eq(
                                lineReplacementPolicy[line]
                                    .allocs[flPortIdx]
                                    .way),
                        [
                          tagRFs[way].writes[flPortIdx].en < flPort.en,
                          tagRFs[way].writes[flPortIdx].addr <
                              Const(line, width: _lineAddrWidth),
                          tagRFs[way].writes[flPortIdx].data <
                              getTag(flPort.addr),
                        ]),
                    ElseIf(
                        ~flPort.valid &
                            Const(way, width: log2Ceil(ways)).eq(
                                lineReplacementPolicy[line]
                                    .invalidates[flPortIdx]
                                    .way),
                        [
                          tagRFs[way].writes[flPortIdx].en < flPort.en,
                          tagRFs[way].writes[flPortIdx].addr <
                              Const(line, width: _lineAddrWidth),
                          tagRFs[way].writes[flPortIdx].data <
                              getTag(flPort.addr),
                        ]),
                  ])
              ])
      ])
    ]);

    // Valid-bit updates per-way.
    for (var way = 0; way < ways; way++) {
      final matchWay = Const(way, width: log2Ceil(ways));
      final validBitWrPort = validBitRFs[way].writes[flPortIdx];

      Logic allocMatch = Const(0);
      if (lines > 0) {
        Logic? accum;
        for (var line = 0; line < lines; line++) {
          final cond = getLine(flPort.addr)
                  .eq(Const(line, width: _lineAddrWidth)) &
              lineReplacementPolicy[line].allocs[flPortIdx].way.eq(matchWay);
          accum = (accum == null) ? cond : (accum | cond);
        }
        allocMatch = accum ?? Const(0);
      }

      Combinational([
        validBitWrPort.en < Const(0),
        validBitWrPort.addr < Const(0, width: _lineAddrWidth),
        validBitWrPort.data < Const(0, width: 1),
        If(flPort.en, then: [
          If.block([
            Iff(
                flPort.valid &
                    ((~fillMiss & fillPortValidWay.eq(matchWay)) |
                        (fillMiss & allocMatch)),
                [
                  validBitWrPort.en < Const(1),
                  validBitWrPort.addr < getLine(flPort.addr),
                  validBitWrPort.data < Const(1, width: 1),
                ]),
            ElseIf(~flPort.valid & ~fillMiss & fillPortValidWay.eq(matchWay), [
              validBitWrPort.en < Const(1),
              validBitWrPort.addr < getLine(flPort.addr),
              validBitWrPort.data < Const(0, width: 1),
            ]),
          ])
        ])
      ]);
    }

    // Data RF writes (per-way).
    for (var way = 0; way < ways; way++) {
      final matchWay = Const(way, width: log2Ceil(ways));
      final fillRFPort = dataRFs[way].writes[flPortIdx];
      Combinational([
        fillRFPort.en < Const(0),
        fillRFPort.addr < Const(0, width: _lineAddrWidth),
        fillRFPort.data < Const(0, width: _dataWidth),
        If(flPort.en & flPort.valid, then: [
          for (var line = 0; line < lines; line++)
            If(
                (fillMiss &
                        lineReplacementPolicy[line].allocs[flPortIdx].access &
                        lineReplacementPolicy[line]
                            .allocs[flPortIdx]
                            .way
                            .eq(matchWay)) |
                    (~fillMiss &
                        lineReplacementPolicy[line].hits[flPortIdx].access &
                        fillPortValidWay.eq(matchWay)),
                then: [
                  fillRFPort.addr < getLine(flPort.addr),
                  fillRFPort.data < flPort.data,
                  fillRFPort.en < flPort.en,
                ])
        ])
      ]);
    }
  }
}
