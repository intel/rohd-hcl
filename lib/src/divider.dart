// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// divider.dart
// Implementation of Integer Divider Module.
//
// 2024 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// State object for Divider processing.
class DivState {
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

/// Port group for the divider's internal interface
enum DivInterfaceDirection {
  /// input ports
  ins,

  /// output ports
  outs
}

/// Internal interface to the Divider.
class DivInterface extends Interface<DivInterfaceDirection> {
  /// Clock for sequential logic.
  Logic get clk => port('clk');

  /// Reset for sequential logic (active high).
  Logic get reset => port('reset');

  /// Dividend (numerator) for the division operation.
  Logic get dividend => port('dividend');

  /// Divisor (denominator) for the division operation.
  Logic get divisor => port('divisor');

  /// Request for a new divison operation to be performed.
  Logic get validIn => port('validIn');

  /// Quotient (result) for the division operation.
  Logic get quotient => port('quotient');

  /// A Division by zero occurred.
  Logic get divZero => port('divZero');

  /// The result of the currnt division operation is ready.
  Logic get validOut => port('validOut');

  /// The module is busy working on a division operation.
  Logic get isBusy => port('isBusy');

  /// The width of the data operands and result.
  final int dataWidth;

  /// A constructor for the divider interface.
  DivInterface({this.dataWidth = 32}) {
    setPorts([
      Port('clk'),
      Port('reset'),
      Port('dividend', dataWidth),
      Port('divisor', dataWidth),
      Port('validIn')
    ], [
      DivInterfaceDirection.ins
    ]);
    setPorts([
      Port('quotient', dataWidth),
      Port('divZero'),
      Port('validOut'),
      Port('isBusy')
    ], [
      DivInterfaceDirection.outs
    ]);
  }

  /// A match constructor for the divider interface.
  DivInterface.match(DivInterface other) : this(dataWidth: other.dataWidth);
}

/// The Divider module definition
class Divider extends Module {
  /// The Divider's interface declaration.
  late final DivInterface intf;

  /// The width of the data operands and result.
  late final int dataWidth;

  /// The log of the data width representing
  /// the number of bits required to store that number.
  late final int logDataWidth;

  /// The Divider module's constructor
  Divider({required DivInterface interface})
      : dataWidth = interface.dataWidth,
        logDataWidth = log2Ceil(interface.dataWidth),
        super(name: 'divider') {
    intf = DivInterface.match(interface)
      ..connectIO(this, interface,
          inputTags: {DivInterfaceDirection.ins},
          outputTags: {DivInterfaceDirection.outs});

    _build();
  }

  void _build() {
    // to capture current inputs
    // as this operation takes multiple cycles
    final aBuf = Logic(name: 'aBuf', width: dataWidth);
    final bBuf = Logic(name: 'bBuf', width: dataWidth);
    final signOut = Logic(name: 'signOut');

    // to manage FSM
    // # of states is fixed
    final currentState = Logic(name: 'currentState', width: DivState.width);
    final nextState = Logic(name: 'nextState', width: DivState.width);

    // internal buffers for computation
    // accumulator that contains dividend
    final outBuffer = Logic(name: 'outBuffer', width: dataWidth);
    // capture last successful power of 2
    final lastSuccess = Logic(name: 'lastSuccess', width: dataWidth);
    // combinational logic signal to compute current (a-b*2^i)
    final tmpDifference = Logic(name: 'tmpDifference', width: dataWidth);
    // store last diff
    final lastDifference = Logic(name: 'lastDifference', width: dataWidth);
    // combinational logic signal to check for overflow when shifting
    final tmpShift = Logic(name: 'tmpShift', width: dataWidth);

    // current value of i to try
    // need log(dataWidth) bits
    final currIndex = Logic(name: 'currIndex', width: logDataWidth);

    intf.quotient <= outBuffer; // result is ultimately stored in out_buffer
    intf.divZero <= ~intf.divisor.or(); // divide-by-0 if b==0 (NOR)

    // ready/busy signals are based on internal state
    intf.validOut <= currentState.eq(DivState.done);
    intf.isBusy <= ~currentState.eq(DivState.ready);

    // update current_state with next_state once per cycle
    Sequential(intf.clk, [
      If(intf.reset,
          then: [currentState < DivState.ready],
          orElse: [currentState < nextState])
    ]);

    // combinational logic to compute next_state
    // and intermediate variables that are necessary
    Combinational([
      tmpShift < 0,
      tmpDifference < 0,
      nextState < DivState.ready,
      Case(currentState, [
        CaseItem(DivState.done, [nextState < DivState.ready]),
        CaseItem(DivState.convert, [nextState < DivState.done]),
        CaseItem(DivState.accumulate, [
          tmpDifference < lastDifference,
          If.block([
            Iff(~tmpDifference.or() | (bBuf > aBuf), [
              // we're done (ready to convert) as difference == 0
              // or we've exceeded the numerator
              nextState < DivState.convert
            ]),
            // more processing to do
            Else([nextState < DivState.process])
          ])
        ]),
        CaseItem(DivState.process, [
          tmpShift < (bBuf << currIndex),
          If(
              // special case: b is most negative #
              bBuf[dataWidth - 1] & ~bBuf.getRange(0, dataWidth - 2).or(),
              then: [
                // special logic for when a is also most negative #
                tmpDifference <
                    mux(
                        aBuf[dataWidth - 1] &
                            ~aBuf.getRange(0, dataWidth - 2).or(),
                        ~Const(0, width: dataWidth), // -1
                        Const(0, width: dataWidth)),
                nextState < DivState.accumulate
              ],
              orElse: [
                tmpDifference < (aBuf - tmpShift),
                // move to accumulate if tmpDifference <= 0
                If(
                    ~tmpShift.or() |
                        tmpDifference[dataWidth - 1] |
                        ~tmpDifference.or(),
                    then: [nextState < DivState.accumulate],
                    orElse: [nextState < DivState.process])
              ])
        ]),
        CaseItem(DivState.ready, [
          If(intf.validIn, then: [
            nextState < mux(~intf.divisor.or(), DivState.done, DivState.process)
            // move straight to DONE if divide-by-0
          ], orElse: [
            nextState < DivState.ready
          ])
        ])
      ])
    ]);

    // capture input arguments a, b into internal buffers
    // so the consumer doesn't have to continually assert them
    Sequential(intf.clk, [
      If.block([
        // only when READY and new inputs are available
        Iff(intf.reset, [
          aBuf < 0,
          bBuf < 0,
          signOut < 0,
        ]),
        ElseIf(currentState.eq(DivState.ready) & intf.validIn, [
          // conditionally convert negative inputs to positive
          // and compute the output sign
          aBuf <
              mux(intf.dividend[dataWidth - 1], ~intf.dividend + 1,
                  intf.dividend),
          bBuf <
              mux(intf.divisor[dataWidth - 1], ~intf.divisor + 1, intf.divisor),
          signOut < intf.dividend[dataWidth - 1] ^ intf.divisor[dataWidth - 1],
        ]),
        ElseIf(currentState.eq(DivState.accumulate), [
          // reduce a_buf by the portion we've covered, retain others
          aBuf < lastDifference,
          bBuf < bBuf,
          signOut < signOut,
        ]),
        Else([
          // retain all values
          aBuf < aBuf,
          bBuf < bBuf,
          signOut < signOut,
        ]),
      ])
    ]);

    // handle updates of curr_index
    Sequential(intf.clk, [
      If.block([
        Iff(intf.reset, [currIndex < Const(0, width: logDataWidth)]),
        ElseIf(
          currentState.eq(
              DivState.process), // increment current index each PROCESS cycle
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
        ElseIf(
            currentState.eq(
                DivState.process), // didn't exceed a_buf, so count as success
            [
              If(~tmpDifference[dataWidth - 1], then: [
                lastSuccess <
                    (Const(1, width: dataWidth) << currIndex), // capture 2^i
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
            lastDifference < 0
          ],
        )
      ])
    ]);

    // handle update of buffer
    Sequential(intf.clk, [
      If.block([
        Iff(intf.reset, [outBuffer < 0]), // reset buffer
        ElseIf(currentState.eq(DivState.done), [outBuffer < 0]), // reset buffer
        ElseIf(currentState.eq(DivState.convert), [
          outBuffer < mux(signOut, ~outBuffer + 1, outBuffer),
        ]), // conditionally convert the result to the correct sign
        ElseIf(currentState.eq(DivState.accumulate), [
          outBuffer < (outBuffer + lastSuccess)
        ]), // accumulate last_success into buffer
        Else([outBuffer < outBuffer]), // maintain buffer
      ])
    ]);
  }
}
