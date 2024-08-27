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

/// State object for Divider processing
class DivState {
  /// width of state bits
  static int width = 3;

  /// ready for a new division
  static Const ready = Const(0, width: width);

  /// processing a current step in the algorithm
  static Const process = Const(1, width: width);

  /// accumulating the result of a current step in the algorithm
  static Const accumulate = Const(2, width: width);

  /// converting the final result of the algorithm
  static Const convert = Const(3, width: width);

  /// division complete
  static Const done = Const(4, width: width);
}

/// port group for divider's internal interface
enum DivInterfaceDirection {
  /// input ports
  ins,

  /// output ports
  outs
}

/// internal interface to the Divider
class DivInterface extends Interface<DivInterfaceDirection> {
  /// clock
  Logic get clk => port('clk');

  /// reset
  Logic get reset => port('reset');

  /// numerator
  Logic get a => port('a');

  /// denominator
  Logic get b => port('b');

  /// request for a new divison to be performed
  Logic get newInputs => port('newInputs');

  /// dividend
  Logic get c => port('c');

  /// division by zero occurred
  Logic get divZero => port('divZero');

  /// result of the division is ready
  Logic get isReady => port('isReady');

  /// busy working on a division
  Logic get isBusy => port('isBusy');

  /// width of the data operands and result
  final int dataWidth;

  /// constructor for interface
  DivInterface({this.dataWidth = 32}) {
    setPorts([
      Port('clk'),
      Port('reset'),
      Port('a', dataWidth),
      Port('b', dataWidth),
      Port('newInputs')
    ], [
      DivInterfaceDirection.ins
    ]);
    setPorts([
      Port('c', dataWidth),
      Port('divZero'),
      Port('isReady'),
      Port('isBusy')
    ], [
      DivInterfaceDirection.outs
    ]);
  }

  /// match constructor for interface
  DivInterface.match(DivInterface other) : this(dataWidth: other.dataWidth);
}

/// Divider module definition
class Divider extends Module {
  /// internal interface
  late final DivInterface intf;

  /// bit width of the data operands and result
  late final int dataWidth;

  /// helper to capture the log of the data width
  late final int logDataWidth;

  /// Divider constructor
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

  // convenience overload of Const w/ a fixed width
  Const dataConst(int v) => Const(v, width: dataWidth);

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
    final outBuffer = Logic(
        name: 'outBuffer',
        width: dataWidth); // accumulator that contains dividend
    final lastSuccess = Logic(
        name: 'lastSuccess',
        width: dataWidth); // capture last successful power of 2
    final tmpDifference = Logic(
        name: 'tmpDifference',
        width:
            dataWidth); // combinational logic signal to compute current (a-b*2^i)
    final lastDifference =
        Logic(name: 'lastDifference', width: dataWidth); // store last diff
    final tmpShift = Logic(
        name: 'tmpShift',
        width:
            dataWidth); // combinational logic signal to check for overflow when shifting

    // current value of i to try
    // need log(dataWidth) bits
    final currIndex = Logic(name: 'currIndex', width: logDataWidth);

    intf.c <= outBuffer; // result is ultimately stored in out_buffer
    intf.divZero <= ~intf.b.or(); // divide-by-0 if b==0 (NOR)

    // ready/busy signals are based on internal state
    intf.isReady <= currentState.eq(DivState.done);
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
      tmpShift < dataConst(0),
      tmpDifference < dataConst(0),
      nextState < DivState.ready,
      Case(currentState, [
        CaseItem(DivState.done, [nextState < DivState.ready]),
        CaseItem(DivState.convert, [nextState < DivState.done]),
        CaseItem(DivState.accumulate, [
          tmpDifference < lastDifference,
          If.block([
            Iff(~tmpDifference.or() | (bBuf > aBuf), [
              // we're done (ready to convert) as difference == 0 or we've exceeded the numerator
              nextState < DivState.convert
            ]),
            Else([nextState < DivState.process]) // more processing to do
          ])
        ]),
        CaseItem(DivState.process, [
          tmpShift < (bBuf << currIndex),
          If(
              bBuf[dataWidth - 1] &
                  ~bBuf
                      .getRange(0, dataWidth - 2)
                      .or(), // special case: b is most negative #
              then: [
                tmpDifference < // special logic for when a is also most negative #
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
          If(intf.newInputs, then: [
            nextState < mux(~intf.b.or(), DivState.done, DivState.process)
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
          aBuf < dataConst(0),
          bBuf < dataConst(0),
          signOut < Const(0),
        ]),
        ElseIf(currentState.eq(DivState.ready) & intf.newInputs, [
          // conditionally convert negative inputs to positive
          // and compute the output sign
          aBuf < mux(intf.a[dataWidth - 1], ~intf.a + dataConst(1), intf.a),
          bBuf < mux(intf.b[dataWidth - 1], ~intf.b + dataConst(1), intf.b),
          signOut < intf.a[dataWidth - 1] ^ intf.b[dataWidth - 1],
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
          lastSuccess < dataConst(0),
          lastDifference < dataConst(0),
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
            lastSuccess < dataConst(0),
            lastDifference < dataConst(0)
          ],
        )
      ])
    ]);

    // handle update of buffer
    Sequential(intf.clk, [
      If.block([
        Iff(intf.reset, [outBuffer < dataConst(0)]), // reset buffer
        ElseIf(currentState.eq(DivState.done),
            [outBuffer < dataConst(0)]), // reset buffer
        ElseIf(currentState.eq(DivState.convert), [
          outBuffer < mux(signOut, ~outBuffer + dataConst(1), outBuffer),
        ]), // conditionally convert the result to the correct sign
        ElseIf(currentState.eq(DivState.accumulate), [
          outBuffer < (outBuffer + lastSuccess)
        ]), // accumulate last_success into buffer
        Else([outBuffer < outBuffer]), // maintain buffer
      ])
    ]);
  }
}
