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
import 'package:rohd_vf/rohd_vf.dart';

//TODO: an auto-attach verification component, check empty at end of test, error situation, etc.

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

  //TODO: doc comment these
  Logic get _writeEnable => input('writeEnable');
  Logic get _readEnable => input('readEnable');
  Logic get _clk => input('clk');
  Logic get _reset => input('reset');
  Logic get _writeData => input('writeData');

  final int dataWidth;
  final int _addrWidth;

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
      : dataWidth = writeData.width,
        _addrWidth = log2Ceil(depth),
        assert(depth > 0, 'Depth must be at least 1.') {
    addInput('clk', clk);
    addInput('reset', reset);

    // set up read/write ports
    addInput('writeEnable', writeEnable);
    addInput('writeData', writeData, width: dataWidth);
    addInput('readEnable', readEnable);
    addOutput('readData', width: dataWidth);

    // set up info ports
    addOutput('full');
    addOutput('empty');

    if (generateError) {
      addOutput('error');
    }

    if (generateOccupancy) {
      addOutput('occupancy', width: log2Ceil(depth));
    }

    _buildLogic();
  }

  /// Builds all the logic for the FIFO.
  void _buildLogic() {
    // set up the RF storage
    final wrPort = DataPortInterface(dataWidth, _addrWidth);
    final rdPort = DataPortInterface(dataWidth, _addrWidth);
    RegisterFile(_clk, _reset, [wrPort], [rdPort], numEntries: depth);

    final wrPointer = Logic(name: 'wrPointer', width: _addrWidth);
    final rdPointer = Logic(name: 'rdPointer', width: _addrWidth);

    // empty calculation
    final matchedPointers = Logic(name: 'matchedPointers');
    matchedPointers <= wrPointer.eq(rdPointer);
    empty <= matchedPointers & ~full;

    // error calculation
    if (generateError) {
      final overflow = full & _writeEnable & ~_readEnable;

      var underflow = empty & _readEnable;
      if (generateBypass) {
        underflow &= ~_writeEnable;
      }

      error! <= underflow | overflow;
    }

    // occupancy calculation
    if (generateOccupancy) {
      Sequential(_clk, [
        If(_reset, then: [
          occupancy! < 0,
        ], orElse: [
          Case(
              conditionalType: ConditionalType.unique,
              [_writeEnable, _readEnable].swizzle(),
              [
                // write, no read
                CaseItem(Const(LogicValue.ofString('10')),
                    [occupancy! < occupancy! + 1]),

                // read, no write
                CaseItem(Const(LogicValue.ofString('01')),
                    [occupancy! < occupancy! - 1]),
              ],
              defaultItem: [
                occupancy! < occupancy
              ])
        ])
      ]);
    }

    // bypass means don't write to the FIFO, feed straight through
    Logic? bypass;
    if (generateBypass) {
      bypass = Logic(name: 'bypass');
      bypass <= empty & _readEnable & _writeEnable;
      wrPort.en <= _writeEnable & ~bypass;
    } else {
      wrPort.en <= _writeEnable;
    }

    wrPort.addr <= wrPointer;
    wrPort.data <= _writeData;

    // we can read from the fifo at all times to allow peeking,
    // including a new write if it's empty
    final peekWriteData = Logic(name: 'peekWriteData')
      ..gets(empty & _writeEnable);

    rdPort.en <= Const(1);
    rdPort.addr <= rdPointer;
    readData <=
        (generateBypass
            ? mux(peekWriteData, _writeData, rdPort.data)
            : rdPort.data);

    final pointerIncrements = [
      wrPointer < _incrWithWrap(wrPointer, _writeEnable),
      rdPointer < _incrWithWrap(rdPointer, _readEnable),
    ];

    Sequential(_clk, [
      If(_reset, then: [
        wrPointer < 0,
        rdPointer < 0,
        full < 0,
      ], orElse: [
        if (generateBypass)
          If(~bypass!, then: pointerIncrements)
        else
          ...pointerIncrements,

        // full condition is one of these options:
        //  - we were already full, and pointers are staying the same
        //  - wrptr is 1 behind read, and we're writing without reading
        // otherwise, rdEn has progressed or we're in undefined error territory
        full <
            (full & (_writeEnable.eq(_readEnable))) |
                (rdPointer.eq(_incrWithWrap(wrPointer)) &
                    _writeEnable &
                    ~_readEnable)
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

/// A checker for [Fifo]s that they are being used properly and not reaching any
/// dangerous conditions.
///
/// This is not intended to check that the [Fifo] is *functioning* properly, but
/// rather that it hasn't been used in an innpropriate way.  For example:
/// - No error condition hit (underflow/overflow)
/// - Empty at the end of the test
class FifoChecker extends Component {
  /// The [Fifo] being checked.
  final Fifo fifo;

  /// Builds a checker for a [fifo].
  ///
  /// Attaches to the top level [Test.instance] if no parent is provided.
  FifoChecker(this.fifo, {String name = '', Component? parent})
      : super(name, parent ?? Test.instance) {
    var hasReset = false;

    fifo._clk.posedge.listen((event) {
      if (!fifo._reset.value.isValid) {
        // reset is invalid, bad state
        hasReset = false;
        return;
      } else if (fifo._reset.value.toBool()) {
        // reset is high, track that and move on
        hasReset = true;
        return;
      } else if (hasReset) {
        // reset is low, and we've previously reset, should be good to check

        if (fifo.full.value.toBool() &&
            fifo._writeEnable.value.toBool() &&
            !fifo._readEnable.value.toBool()) {
          logger.severe('Fifo $fifo received a write that caused an overflow.');
        } else if (fifo.empty.value.toBool() &&
            fifo._readEnable.value.toBool()) {
          if (!(fifo.generateBypass && fifo._writeEnable.value.toBool())) {
            logger
                .severe('Fifo $fifo received a read that caused an underflow.');
          }
        }
      }
    });
  }

  @override
  void check() {
    if (!fifo.empty.value.toBool()) {
      logger.severe('Fifo $fifo is not empty at the end of the test.');
    }
  }
}

//TODO: logger also?