// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// divider.dart
// Implementation of Integer Divider Module.
//
// 2024 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// State object for Divider processing.
class _MultiCycleDividerState {
  /// Width of state in bits.
  static int width = 3;

  /// Ready for a new division.
  static Const ready = Const(0, width: width);

  /// Processing a current step in the algorithm.
  static Const process = Const(1, width: width);

  /// Accumulating the result of a current step in the algorithm.
  static Const accumulate = Const(2, width: width);

  /// Converting the final result of the algorithm.
  static Const convert = Const(3, width: width);

  /// Division complete.
  static Const done = Const(4, width: width);
}

/// Internal interface to the Divider.
class MultiCycleDividerInterface extends PairInterface {
  /// Clock for sequential logic.
  Logic get clk => port('clk');

  /// Reset for sequential logic (active high).
  Logic get reset => port('reset');

  /// Dividend (numerator) for the division operation.
  Logic get dividend => port('dividend');

  /// Divisor (denominator) for the division operation.
  Logic get divisor => port('divisor');

  /// Are the division operands signed.
  Logic get isSigned => port('isSigned');

  /// The integrating environment is ready to accept the output of the module.
  Logic get readyOut => port('readyOut');

  /// Request for a new division operation to be performed.
  Logic get validIn => port('validIn');

  /// Quotient (result) for the division operation.
  Logic get quotient => port('quotient');

  /// Remainder (modulus) for the division operation.
  Logic get remainder => port('remainder');

  /// A Division by zero occurred.
  Logic get divZero => port('divZero');

  /// The result of the current division operation is ready.
  Logic get validOut => port('validOut');

  /// The module is ready to accept new inputs.
  Logic get readyIn => port('readyIn');

  /// The width of the data operands and result.
  final int dataWidth;

  /// A constructor for the divider interface.
  MultiCycleDividerInterface({this.dataWidth = 32})
      : super(portsFromProvider: [
          Port('clk'),
          Port('reset'),
          Port('dividend', dataWidth),
          Port('divisor', dataWidth),
          Port('isSigned'),
          Port('validIn'),
          Port('readyOut'),
        ], portsFromConsumer: [
          Port('quotient', dataWidth),
          Port('remainder', dataWidth),
          Port('divZero'),
          Port('validOut'),
          Port('readyIn'),
        ]);

  /// A match constructor for the divider interface.
  MultiCycleDividerInterface.match(MultiCycleDividerInterface other)
      : this(dataWidth: other.dataWidth);
}

/// The Divider module definition.
class MultiCycleDivider extends Module {
  /// The Divider's interface declaration.
  @protected
  late final MultiCycleDividerInterface intf;

  /// Get interface's validOut signal value.
  Logic get validOut => output('${name}_validOut');

  /// Get interface's quotient signal value.
  Logic get quotient => output('${name}_quotient');

  /// Get interface's remainder signal value.
  Logic get remainder => output('${name}_remainder');

  /// Get interface's divZero signal value.
  Logic get divZero => output('${name}_divZero');

  /// Get interface's readyIn signal value.
  Logic get readyIn => output('${name}_readyIn');

  /// The width of the data operands and result.
  late final int dataWidth;

  /// The log of the data width representing
  /// the number of bits required to store that number.
  late final int logDataWidth;

  /// The Divider module's constructor.
  MultiCycleDivider(MultiCycleDividerInterface interface)
      : dataWidth = interface.dataWidth,
        logDataWidth = log2Ceil(interface.dataWidth),
        super(
            name: 'divider',
            definitionName: 'MultiCycleDivider_W${interface.dataWidth}') {
    intf = MultiCycleDividerInterface.match(interface)
      ..pairConnectIO(
        this,
        interface,
        PairRole.consumer,
        uniquify: (original) => '${super.name}_$original',
      );

    _build();
  }

  /// Factory method to create a [MultiCycleDivider]
  /// from explicit [Logic] signals instead of an interface.
  factory MultiCycleDivider.ofLogics({
    required Logic clk,
    required Logic reset,
    required Logic validIn,
    required Logic dividend,
    required Logic divisor,
    required Logic isSigned,
    required Logic readyOut,
  }) {
    assert(dividend.width == divisor.width,
        'Widths of all data signals do not match!');
    final dataWidth = dividend.width;
    final intf = MultiCycleDividerInterface(dataWidth: dataWidth);
    intf.clk <= clk;
    intf.reset <= reset;
    intf.validIn <= validIn;
    intf.dividend <= dividend;
    intf.divisor <= divisor;
    intf.isSigned <= isSigned;
    intf.readyOut <= readyOut;
    return MultiCycleDivider(intf);
  }

  void _build() {
    // To capture current inputs
    // as this operation takes multiple cycles.
    final aBuf = Logic(name: 'aBuf', width: dataWidth + 1);
    final rBuf = Logic(name: 'rBuf', width: dataWidth + 1);
    final bBuf = Logic(name: 'bBuf', width: dataWidth + 1);
    final signOut = Logic(name: 'signOut');
    final signNum = Logic(name: 'signNum');

    // to manage FSM
    // # of states is fixed
    final currentState =
        Logic(name: 'currentState', width: _MultiCycleDividerState.width);
    final nextState =
        Logic(name: 'nextState', width: _MultiCycleDividerState.width);

    // internal buffers for computation
    // accumulator that contains dividend
    final outBuffer = Logic(name: 'outBuffer', width: dataWidth + 1);
    // capture last successful power of 2
    final lastSuccess = Logic(name: 'lastSuccess', width: dataWidth + 1);
    // combinational logic signal to compute current (a-b*2^i)
    final tmpDifference = Logic(name: 'tmpDifference', width: dataWidth + 1);
    // store last diff
    final lastDifference = Logic(name: 'lastDifference', width: dataWidth + 1);
    // combinational logic signal to check for overflow when shifting
    final tmpShift = Logic(name: 'tmpShift', width: dataWidth + 1);

    // current value of i to try
    // need log(dataWidth) bits
    final currIndex = Logic(name: 'currIndex', width: logDataWidth);

    intf.quotient <=
        outBuffer.getRange(
            0, dataWidth); // result is ultimately stored in out_buffer
    intf.divZero <= ~bBuf.or(); // divide-by-0 if b==0 (NOR)
    intf.remainder <=
        rBuf.getRange(0, dataWidth); // synonymous with the remainder

    // ready/busy signals are based on internal state
    intf.validOut <= currentState.eq(_MultiCycleDividerState.done);
    intf.readyIn <= currentState.eq(_MultiCycleDividerState.ready);

    // update current_state with next_state once per cycle
    Sequential(intf.clk, [
      If(intf.reset,
          then: [currentState < _MultiCycleDividerState.ready],
          orElse: [currentState < nextState])
    ]);

    // combinational logic to compute next_state
    // and intermediate variables that are necessary
    Combinational([
      tmpShift < 0,
      tmpDifference < 0,
      nextState < _MultiCycleDividerState.ready,
      Case(currentState, [
        CaseItem(_MultiCycleDividerState.done, [
          // can move to ready as long as outside indicates consumption
          nextState <
              mux(intf.readyOut, _MultiCycleDividerState.ready,
                  _MultiCycleDividerState.done)
        ]),
        CaseItem(_MultiCycleDividerState.convert,
            [nextState < _MultiCycleDividerState.done]),
        CaseItem(_MultiCycleDividerState.accumulate, [
          tmpDifference < lastDifference,
          If.block([
            Iff(~tmpDifference.or() | (bBuf > aBuf), [
              // we're done (ready to convert) as difference == 0
              // or we've exceeded the numerator
              nextState < _MultiCycleDividerState.convert
            ]),
            // more processing to do
            Else([nextState < _MultiCycleDividerState.process])
          ])
        ]),
        CaseItem(_MultiCycleDividerState.process, [
          tmpShift < (bBuf << currIndex),
          If(
              // special case: b is most negative #
              // XOR of signOut and signNum is high iff
              // signed AND denominator is negative
              bBuf[dataWidth - 1] &
                  ~bBuf.getRange(0, dataWidth - 2).or() &
                  (signOut ^ signNum),
              then: [
                tmpDifference < ~Const(0, width: dataWidth + 1), // -1
                nextState < _MultiCycleDividerState.accumulate
              ],
              orElse: [
                tmpDifference < (aBuf - tmpShift),
                // move to accumulate if tmpDifference <= 0
                If(~tmpShift.or() | tmpDifference[-1] | ~tmpDifference.or(),
                    then: [nextState < _MultiCycleDividerState.accumulate],
                    orElse: [nextState < _MultiCycleDividerState.process])
              ])
        ]),
        CaseItem(_MultiCycleDividerState.ready, [
          If(intf.validIn, then: [
            nextState <
                mux(~intf.divisor.or(), _MultiCycleDividerState.done,
                    _MultiCycleDividerState.process)
            // move straight to DONE if divide-by-0
          ], orElse: [
            nextState < _MultiCycleDividerState.ready
          ])
        ])
      ])
    ]);

    // capture input arguments a, b into internal buffers
    // so the consumer doesn't have to continually assert them
    final extDividendIn = Logic(name: 'extDividendIn', width: dataWidth + 1)
      ..gets(mux(intf.isSigned, intf.dividend.signExtend(dataWidth + 1),
          intf.dividend.zeroExtend(dataWidth + 1)));
    final extDivisorIn = Logic(name: 'extDivisorIn', width: dataWidth + 1)
      ..gets(mux(intf.isSigned, intf.divisor.signExtend(dataWidth + 1),
          intf.divisor.zeroExtend(dataWidth + 1)));
    Sequential(intf.clk, [
      If.block([
        // only when READY and new inputs are available
        Iff(intf.reset, [
          aBuf < 0,
          bBuf < 0,
          signOut < 0,
          signNum < 0,
        ]),
        ElseIf(currentState.eq(_MultiCycleDividerState.ready) & intf.validIn, [
          // conditionally convert negative inputs to positive
          // and compute the output sign
          aBuf <
              mux(extDividendIn[dataWidth - 1] & intf.isSigned,
                  ~extDividendIn + 1, extDividendIn),
          bBuf <
              mux(extDivisorIn[dataWidth - 1] & intf.isSigned,
                  ~extDivisorIn + 1, extDivisorIn),
          signOut <
              (intf.dividend[dataWidth - 1] ^ intf.divisor[dataWidth - 1]) &
                  intf.isSigned,
          signNum < intf.dividend[dataWidth - 1] & intf.isSigned,
        ]),
        ElseIf(currentState.eq(_MultiCycleDividerState.accumulate), [
          // reduce a_buf by the portion we've covered, retain others
          aBuf < lastDifference,
          bBuf < bBuf,
          signOut < signOut,
          signNum < signNum,
        ]),
        Else([
          // retain all values
          aBuf < aBuf,
          bBuf < bBuf,
          signOut < signOut,
          signNum < signNum,
        ]),
      ])
    ]);

    // handle updates of remainder buffer
    final aBufConv = mux(signNum, ~aBuf + 1, aBuf);
    Sequential(intf.clk, [
      If.block([
        Iff(intf.reset, [rBuf < Const(0, width: dataWidth + 1)]),
        ElseIf(
          currentState.eq(_MultiCycleDividerState
              .convert), // adjust positive remainder for signs
          [rBuf < aBufConv],
        ),
        Else(
          [rBuf < rBuf], // retain
        )
      ])
    ]);

    // handle updates of curr_index
    Sequential(intf.clk, [
      If.block([
        Iff(intf.reset, [currIndex < Const(0, width: logDataWidth)]),
        ElseIf(
          currentState.eq(_MultiCycleDividerState
              .process), // increment current index each PROCESS cycle
          [currIndex < (currIndex + Const(1, width: logDataWidth))],
        ),
        Else(
          [currIndex < Const(0, width: logDataWidth)], // reset curr_index
        )
      ])
    ]);

    // handle update of lastSuccess and lastDifference
    Sequential(intf.clk, [
      If.block([
        Iff(intf.reset, [
          lastSuccess < 0,
          lastDifference < 0,
        ]),
        ElseIf(currentState.eq(_MultiCycleDividerState.ready) & intf.validIn, [
          lastSuccess < 0,
          lastDifference <
              mux(extDividendIn[dataWidth - 1] & intf.isSigned,
                  ~extDividendIn + 1, extDividendIn), // start by matching aBuf
        ]),
        ElseIf(
            currentState.eq(_MultiCycleDividerState
                .process), // didn't exceed a_buf, so count as success
            [
              If(~tmpDifference[-1], then: [
                lastSuccess <
                    (Const(1, width: dataWidth + 1) <<
                        currIndex), // capture 2^i
                lastDifference < tmpDifference
              ], orElse: [
                // failure so maintain
                lastSuccess < lastSuccess,
                lastDifference < lastDifference
              ]),
            ]),
        Else(
          [
            // not needed so reset
            lastSuccess < 0,
            lastDifference < lastDifference,
          ],
        )
      ])
    ]);

    // handle update of buffer
    Sequential(intf.clk, [
      If.block([
        Iff(intf.reset, [outBuffer < 0]), // reset buffer
        ElseIf(currentState.eq(_MultiCycleDividerState.done), [
          outBuffer <
              mux(intf.readyOut, Const(0, width: dataWidth + 1), outBuffer),
        ]), // reset buffer if consumed result
        ElseIf(currentState.eq(_MultiCycleDividerState.convert), [
          outBuffer < mux(signOut, ~outBuffer + 1, outBuffer),
        ]), // conditionally convert the result to the correct sign
        ElseIf(currentState.eq(_MultiCycleDividerState.accumulate), [
          outBuffer < (outBuffer + lastSuccess)
        ]), // accumulate last_success into buffer
        Else([outBuffer < outBuffer]), // maintain buffer
      ])
    ]);
  }
}
