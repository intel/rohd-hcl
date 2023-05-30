// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fifo.dart
// Implementation of FIFOs.
//
// 2023 March 13
// Author: Max Korbel <max.korbel@intel.com>
//

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/utils.dart';

/// A simple FIFO (First In, First Out).
///
/// Supports a bypass if the FIFO is empty and written & read at the same time.
class Fifo extends Module {
  /// High if the entire FIFO is full and it cannot accept any more new items.
  Logic get full => output('full');

  /// High if there is nothing in the FIFO.
  Logic get empty => output('empty');

  /// Read data for the next item in the FIFO.
  ///
  /// This data is visible even when not actively removing from the FIFO.
  Logic get readData => output('readData');

  /// High if an error condition is reached.
  ///
  /// There is no guarantee that it will hold high once asserted.
  /// Behavior upon error is undefined.
  ///
  /// If [generateError] is `false`, this output will not exist.
  Logic? get error => generateError ? output('error') : null;

  /// The number of items in the FIFO.
  ///
  /// If [generateOccupancy] is `false`, this output will not exist.
  Logic? get occupancy => generateOccupancy ? output('occupancy') : null;

  /// The depth of this FIFO.
  final int depth;

  /// If `true`, then the [occupancy] output will be generated.
  final bool generateOccupancy;

  /// If `true`, then the [error] output will be generated.
  final bool generateError;

  /// If `true`, then it is possible to bypass through the FIFO by writing
  /// and reading at the same time while [empty].
  final bool generateBypass;

  /// Constructs a FIFO with RF-based storage.
  Fifo(Logic clk, Logic reset,
      {required Logic writeEnable,
      required Logic writeData,
      required Logic readEnable,
      required this.depth,
      this.generateError = false,
      this.generateOccupancy = false,
      this.generateBypass = false,
      super.name = 'fifo'})
      : assert(depth > 0, 'Depth must be at least 1.') {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    final dataWidth = writeData.width;
    final addrWidth = log2Ceil(depth);

    // set up read/write ports
    writeEnable = addInput('writeEnable', writeEnable);
    writeData = addInput('writeData', writeData, width: dataWidth);
    readEnable = addInput('readEnable', readEnable);
    addOutput('readData', width: dataWidth);

    // set up info ports
    addOutput('full');
    addOutput('empty');

    // set up the RF storage
    final wrPort = DataPortInterface(dataWidth, addrWidth);
    final rdPort = DataPortInterface(dataWidth, addrWidth);
    RegisterFile(clk, reset, [wrPort], [rdPort], numEntries: depth);

    final wrPointer = Logic(name: 'wrPointer', width: addrWidth);
    final rdPointer = Logic(name: 'rdPointer', width: addrWidth);

    // empty calculation
    final matchedPointers = Logic(name: 'matchedPointers');
    matchedPointers <= wrPointer.eq(rdPointer);
    empty <= matchedPointers & ~full;

    // error calculation
    if (generateError) {
      addOutput('error') <=
          ((full & writeEnable & ~readEnable) |
              (empty & readEnable & ~writeEnable));
    }

    // occupancy calculation
    if (generateOccupancy) {
      final occupancy = addOutput('occupancy', width: log2Ceil(depth));
      Sequential(clk, [
        If(reset, then: [
          occupancy < 0,
        ], orElse: [
          Case(
              conditionalType: ConditionalType.unique,
              [writeEnable, readEnable].swizzle(),
              [
                // write, no read
                CaseItem(Const(LogicValue.ofString('10')),
                    [occupancy < occupancy + 1]),

                // read, no write
                CaseItem(Const(LogicValue.ofString('01')),
                    [occupancy < occupancy - 1]),
              ],
              defaultItem: [
                occupancy < occupancy
              ])
        ])
      ]);
    }

    // bypass means don't write to the FIFO, feed straight through
    final bypass = Logic(name: 'bypass');
    if (generateBypass) {
      bypass <= empty & readEnable & writeEnable;
      wrPort.en <= writeEnable & ~bypass;
    } else {
      wrPort.en <= writeEnable;
    }

    wrPort.addr <= wrPointer;
    wrPort.data <= writeData;

    // we can read from the fifo at all times to allow peeking,
    // including a new write if it's empty
    final peekWriteData = Logic(name: 'peekWriteData')
      ..gets(empty & writeEnable);

    rdPort.en <= Const(1);
    rdPort.addr <= rdPointer;
    readData <=
        (generateBypass
            ? mux(peekWriteData, writeData, rdPort.data)
            : rdPort.data);

    final pointerIncrements = [
      wrPointer < _incrWithWrap(wrPointer, writeEnable),
      rdPointer < _incrWithWrap(rdPointer, readEnable),
    ];

    Sequential(clk, [
      If(reset, then: [
        wrPointer < 0,
        rdPointer < 0,
        full < 0,
      ], orElse: [
        if (generateBypass)
          If(~bypass, then: pointerIncrements)
        else
          ...pointerIncrements,

        // full condition is one of these options:
        //  - we were already full, and pointers are staying the same
        //  - wrptr is 1 behind read, and we're writing without reading
        // otherwise, rdEn has progressed or we're in undefined error territory
        full <
            (full & (writeEnable.eq(readEnable))) |
                (rdPointer.eq(_incrWithWrap(wrPointer)) &
                    writeEnable &
                    ~readEnable)
      ]),
    ]);
  }

  /// Increments [original] by 1, but wraps accounting for [depth].
  ///
  /// Optionally, the increment can be conditional on [condition].
  Logic _incrWithWrap(Logic original, [Logic? condition]) {
    final maxValue = depth - 1;
    final wrapped = mux(
        original.eq(maxValue), Const(0, width: original.width), original + 1);
    return condition != null ? mux(condition, wrapped, original) : wrapped;
  }
}
