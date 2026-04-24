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

/// States for the [MultiCycleDivider] FSM.
enum MultiCycleDividerStates {
  /// Ready for a new division.
  ready,

  /// Processing a current step in the algorithm.
  process,

  /// Accumulating the result of a current step in the algorithm.
  accumulate,

  /// Converting the final result of the algorithm.
  convert,

  /// Division complete.
  done,
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
          Logic.port('clk'),
          Logic.port('reset'),
          Logic.port('dividend', dataWidth),
          Logic.port('divisor', dataWidth),
          Logic.port('isSigned'),
          Logic.port('validIn'),
          Logic.port('readyOut'),
        ], portsFromConsumer: [
          Logic.port('quotient', dataWidth),
          Logic.port('remainder', dataWidth),
          Logic.port('divZero'),
          Logic.port('validOut'),
          Logic.port('readyIn'),
        ]);

  /// A match constructor for the divider interface.
  @Deprecated('Use clone() instead.')
  MultiCycleDividerInterface.match(MultiCycleDividerInterface other)
      : this(dataWidth: other.dataWidth);

  /// Clones this [MultiCycleDividerInterface].
  @override
  MultiCycleDividerInterface clone() =>
      MultiCycleDividerInterface(dataWidth: dataWidth);
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

  /// When `true` (default), the [remainder] output is computed using the full
  /// O(n²) greedy algorithm. When `false`, [remainder] is always 0 and the
  /// divider uses an O(n) binary long-division algorithm instead.
  final bool computeRemainder;

  /// The Divider module's constructor
  MultiCycleDivider(MultiCycleDividerInterface interface,
      {this.computeRemainder = true,
      super.name = 'multi_cycle_divider',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : dataWidth = interface.dataWidth,
        logDataWidth = log2Ceil(interface.dataWidth),
        super(
            definitionName:
                definitionName ?? 'MultiCycleDivider_W${interface.dataWidth}') {
    intf = interface.clone()
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
    bool computeRemainder = true,
    bool reserveName = false,
    bool reserveDefinitionName = false,
    String? definitionName,
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
    return MultiCycleDivider(intf,
        computeRemainder: computeRemainder,
        reserveName: reserveName,
        reserveDefinitionName: reserveDefinitionName,
        definitionName:
            definitionName ?? 'MultiCycleDivider_W${intf.dataWidth}');
  }

  /// Routes to the appropriate build method based on [computeRemainder].
  void _build() {
    if (computeRemainder) {
      _buildWithRemainder();
    } else {
      _buildQuotientOnly();
    }
  }

  /// Full O(n²) greedy algorithm that computes both quotient and remainder.
  void _buildWithRemainder() {
    // To capture current inputs
    // as this operation takes multiple cycles.
    final aBuf = Logic(name: 'aBuf', width: dataWidth + 1);
    final rBuf = Logic(name: 'rBuf', width: dataWidth + 1);
    final bBuf = Logic(name: 'bBuf', width: dataWidth + 1);
    final signOut = Logic(name: 'signOut');
    final signNum = Logic(name: 'signNum');

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

    // special case: b is the most negative number;
    // XOR of signOut and signNum is high iff signed AND denominator is negative
    final specialCase = bBuf[dataWidth - 1] &
        ~bBuf.getRange(0, dataWidth - 2).or() &
        (signOut ^ signNum);

    // Build the FSM using ROHD's FiniteStateMachine.
    // setupActions provide combinational defaults before state-specific logic.
    // Each state's actions run before its events are evaluated, so tmpShift
    // and tmpDifference computed in process actions are visible to its events.
    final fsm = FiniteStateMachine<MultiCycleDividerStates>(
      intf.clk,
      intf.reset,
      MultiCycleDividerStates.ready,
      [
        State<MultiCycleDividerStates>(
          MultiCycleDividerStates.ready,
          events: {
            // divide-by-zero: jump straight to done
            intf.validIn & ~intf.divisor.or(): MultiCycleDividerStates.done,
            // normal: start processing
            intf.validIn: MultiCycleDividerStates.process,
          },
          actions: [],
        ),
        State<MultiCycleDividerStates>(
          MultiCycleDividerStates.process,
          events: {
            // go to accumulate when:
            //   - special case (b is most-negative), or
            //   - shift would be zero, or
            //   - difference went negative or exactly zero
            specialCase |
                ~tmpShift.or() |
                tmpDifference[-1] |
                ~tmpDifference.or(): MultiCycleDividerStates.accumulate,
          },
          actions: [
            // compute shift; for special case set difference to -1,
            // otherwise compute (a - b*2^i)
            tmpShift < (bBuf << currIndex),
            If(
              specialCase,
              then: [tmpDifference < ~Const(0, width: dataWidth + 1)],
              orElse: [tmpDifference < (aBuf - tmpShift)],
            ),
          ],
        ),
        State<MultiCycleDividerStates>(
          MultiCycleDividerStates.accumulate,
          events: {
            // done when remainder is zero or divisor exceeds what's left
            ~lastDifference.or() | (bBuf > aBuf):
                MultiCycleDividerStates.convert,
            // otherwise keep processing more bits
            Const(1): MultiCycleDividerStates.process,
          },
          actions: [
            // expose lastDifference through tmpDifference for consistency
            tmpDifference < lastDifference,
          ],
        ),
        State<MultiCycleDividerStates>(
          MultiCycleDividerStates.convert,
          events: {Const(1): MultiCycleDividerStates.done},
          actions: [],
        ),
        State<MultiCycleDividerStates>(
          MultiCycleDividerStates.done,
          events: {
            // return to ready once the consumer has accepted the result
            intf.readyOut: MultiCycleDividerStates.ready,
          },
          actions: [],
        ),
      ],
      setupActions: [
        tmpShift < 0,
        tmpDifference < 0,
      ],
    );

    // Helper to build a state-equality Logic for use in Sequential blocks.
    Logic inState(MultiCycleDividerStates s) => fsm.currentState
        .eq(Const(fsm.getStateIndex(s), width: fsm.currentState.width));

    // ready/busy signals are based on internal state
    intf.validOut <= inState(MultiCycleDividerStates.done);
    intf.readyIn <= inState(MultiCycleDividerStates.ready);

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
        ElseIf(inState(MultiCycleDividerStates.ready) & intf.validIn, [
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
        ElseIf(inState(MultiCycleDividerStates.accumulate), [
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
          inState(MultiCycleDividerStates.convert),
          [rBuf < aBufConv], // adjust positive remainder for signs
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
          inState(MultiCycleDividerStates.process),
          [currIndex < (currIndex + Const(1, width: logDataWidth))],
          // increment current index each PROCESS cycle
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
        ElseIf(inState(MultiCycleDividerStates.ready) & intf.validIn, [
          lastSuccess < 0,
          lastDifference <
              mux(extDividendIn[dataWidth - 1] & intf.isSigned,
                  ~extDividendIn + 1, extDividendIn), // start by matching aBuf
        ]),
        ElseIf(
          inState(MultiCycleDividerStates.process),
          // didn't exceed a_buf, so count as success
          [
            If(~tmpDifference[-1], then: [
              lastSuccess <
                  (Const(1, width: dataWidth + 1) << currIndex), // capture 2^i
              lastDifference < tmpDifference
            ], orElse: [
              // failure so maintain
              lastSuccess < lastSuccess,
              lastDifference < lastDifference
            ]),
          ],
        ),
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
        ElseIf(inState(MultiCycleDividerStates.done), [
          outBuffer <
              mux(intf.readyOut, Const(0, width: dataWidth + 1), outBuffer),
        ]), // reset buffer if consumed result
        ElseIf(inState(MultiCycleDividerStates.convert), [
          outBuffer < mux(signOut, ~outBuffer + 1, outBuffer),
        ]), // conditionally convert the result to the correct sign
        ElseIf(inState(MultiCycleDividerStates.accumulate), [
          outBuffer < (outBuffer + lastSuccess)
        ]), // accumulate last_success into buffer
        Else([outBuffer < outBuffer]), // maintain buffer
      ])
    ]);
  }

  /// O(n) binary long division — one quotient bit per clock cycle.
  ///
  /// Processes the dividend MSB-first, shifting a partial remainder left and
  /// trial-subtracting the divisor each cycle. The [remainder] output is
  /// always 0 in this mode.
  void _buildQuotientOnly() {
    // Registers.
    final aBuf = Logic(name: 'aBuf', width: dataWidth + 1); // |dividend|
    final bBuf = Logic(name: 'bBuf', width: dataWidth + 1); // |divisor|
    final signOut = Logic(name: 'signOut'); // output sign
    final outBuffer =
        Logic(name: 'outBuffer', width: dataWidth + 1); // quotient
    final partialRem = Logic(name: 'partialRem', width: dataWidth + 1);

    // bitIdx counts DOWN from dataWidth-1 to 0; one bit of dividend per cycle.
    final bitIdx = Logic(name: 'bitIdx', width: widthFor(dataWidth));

    // Combinational intermediates (reset to 0 by setupActions).
    final shiftedRem = Logic(name: 'shiftedRem', width: dataWidth + 1);
    final trialDiff = Logic(name: 'trialDiff', width: dataWidth + 1);
    final quotBit = Logic(name: 'quotBit');

    // Outputs.
    intf.quotient <= outBuffer.getRange(0, dataWidth);
    intf.divZero <= ~bBuf.or();
    intf.remainder <= Const(0, width: dataWidth); // not computed in this mode

    // Select aBuf[bitIdx]: the dividend bit for this cycle (MSB-first).
    final dividendBitList = List<Logic>.generate(dataWidth, (i) => aBuf[i]);
    final currentDividendBit =
        bitIdx.selectFrom(dividendBitList).named('currentDividendBit');

    final bitIdxInit =
        Const(dataWidth - 1, width: widthFor(dataWidth)).named('bitIdxInit');

    final fsm = FiniteStateMachine<MultiCycleDividerStates>(
      intf.clk,
      intf.reset,
      MultiCycleDividerStates.ready,
      [
        State<MultiCycleDividerStates>(
          MultiCycleDividerStates.ready,
          events: {
            intf.validIn & ~intf.divisor.or(): MultiCycleDividerStates.done,
            intf.validIn: MultiCycleDividerStates.process,
          },
          actions: [],
        ),
        State<MultiCycleDividerStates>(
          MultiCycleDividerStates.process,
          events: {
            // Last bit: bitIdx is at 0 this cycle → go to sign-convert.
            bitIdx.eq(Const(0, width: widthFor(dataWidth))):
                MultiCycleDividerStates.convert,
          },
          actions: [
            // Shift partial remainder left and bring in the next dividend bit.
            shiftedRem <
                ((partialRem << 1) |
                    currentDividendBit.zeroExtend(dataWidth + 1)),
            // Trial subtraction: shiftedRem - bBuf.
            trialDiff < (shiftedRem - bBuf),
            // Quotient bit = 1 when shiftedRem >= bBuf (MSB of diff = 0).
            quotBit < ~trialDiff[-1],
          ],
        ),
        State<MultiCycleDividerStates>(
          MultiCycleDividerStates.convert,
          events: {Const(1): MultiCycleDividerStates.done},
          actions: [],
        ),
        State<MultiCycleDividerStates>(
          MultiCycleDividerStates.done,
          events: {
            intf.readyOut: MultiCycleDividerStates.ready,
          },
          actions: [],
        ),
      ],
      setupActions: [shiftedRem < 0, trialDiff < 0, quotBit < 0],
    );

    Logic inState(MultiCycleDividerStates s) => fsm.currentState
        .eq(Const(fsm.getStateIndex(s), width: fsm.currentState.width));

    intf.validOut <= inState(MultiCycleDividerStates.done);
    intf.readyIn <= inState(MultiCycleDividerStates.ready);

    final extDividendIn = Logic(name: 'extDividendIn', width: dataWidth + 1)
      ..gets(mux(intf.isSigned, intf.dividend.signExtend(dataWidth + 1),
          intf.dividend.zeroExtend(dataWidth + 1)));
    final extDivisorIn = Logic(name: 'extDivisorIn', width: dataWidth + 1)
      ..gets(mux(intf.isSigned, intf.divisor.signExtend(dataWidth + 1),
          intf.divisor.zeroExtend(dataWidth + 1)));

    Sequential(intf.clk, [
      If.block([
        Iff(intf.reset, [
          aBuf < 0,
          bBuf < 0,
          signOut < 0,
          outBuffer < 0,
          partialRem < 0,
          bitIdx < bitIdxInit,
        ]),
        ElseIf(inState(MultiCycleDividerStates.ready) & intf.validIn, [
          // Convert negative inputs to positive and compute the output sign.
          aBuf <
              mux(extDividendIn[dataWidth - 1] & intf.isSigned,
                  ~extDividendIn + 1, extDividendIn),
          bBuf <
              mux(extDivisorIn[dataWidth - 1] & intf.isSigned,
                  ~extDivisorIn + 1, extDivisorIn),
          signOut <
              (intf.dividend[dataWidth - 1] ^ intf.divisor[dataWidth - 1]) &
                  intf.isSigned,
          outBuffer < 0,
          partialRem < 0,
          bitIdx < bitIdxInit,
        ]),
        ElseIf(inState(MultiCycleDividerStates.process), [
          // Accept quotient bit; update partial remainder.
          partialRem < mux(quotBit, trialDiff, shiftedRem),
          // Shift quotient accumulator left and insert new bit at LSB.
          outBuffer < ((outBuffer << 1) | quotBit.zeroExtend(dataWidth + 1)),
          // Count down toward 0.
          bitIdx < (bitIdx - Const(1, width: widthFor(dataWidth))),
        ]),
        ElseIf(inState(MultiCycleDividerStates.convert), [
          // Apply sign correction to quotient.
          outBuffer < mux(signOut, ~outBuffer + 1, outBuffer),
          bitIdx < bitIdx,
        ]),
        ElseIf(inState(MultiCycleDividerStates.done), [
          // Clear quotient once the consumer accepts the result.
          outBuffer <
              mux(intf.readyOut, Const(0, width: dataWidth + 1), outBuffer),
        ]),
        Else([
          aBuf < aBuf,
          bBuf < bBuf,
          signOut < signOut,
          outBuffer < outBuffer,
          partialRem < partialRem,
          bitIdx < bitIdx,
        ]),
      ])
    ]);
  }
}
