//
// fifo.dart
// Implementation of FIFOs.
//
// Author: Max Korbel
// 2023 March 13
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
  Logic get error => output('error');

  /// The depth of this FIFO.
  final int depth;

  /// Constructs a FIFO with RF-based storage.
  Fifo(Logic clk, Logic reset,
      {required Logic writeEnable,
      required Logic writeData,
      required Logic readEnable,
      required this.depth,
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
    addOutput('error');

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
    error <=
        ((full & writeEnable & ~readEnable) |
            (empty & readEnable & ~writeEnable));

    final bypass = Logic(name: 'bypass')
      ..gets(empty & readEnable & writeEnable);

    wrPort.en <= writeEnable & ~bypass;
    wrPort.addr <= wrPointer;
    wrPort.data <= writeData;

    rdPort.en <= readEnable & ~bypass;
    rdPort.addr <= rdPointer;
    readData <= mux(bypass, writeData, rdPort.data);

    Sequential(clk, [
      If(reset, then: [
        wrPointer < 0,
        rdPointer < 0,
        full < 0,
      ], orElse: [
        If(~bypass, then: [
          wrPointer < _incrWithWrap(wrPointer, writeEnable),
          rdPointer < _incrWithWrap(rdPointer, readEnable),
        ]),

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
