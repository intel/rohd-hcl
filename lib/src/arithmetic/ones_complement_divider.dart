// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ones_complement_divider.dart
// Integer Divider using one's complement signed arithmetic.
//
// 2025 April
// Author: Jose Rojas Chaves <jose.rojas.chaves@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A multi-cycle integer divider that uses **one's complement** signed
/// arithmetic.
///
/// This is an independent sibling of [MultiCycleDivider] intended for
/// performance and area comparison.  Both classes share the same
/// [MultiCycleDividerInterface] and [MultiCycleDividerStates] FSM states,
/// but differ in their sign-arithmetic primitives and sign-correction
/// circuit:
///
/// | Primitive | 2's complement ([MultiCycleDivider]) | 1's complement |
/// |-----------|--------------------------------------|----------------|
/// | Negate    | `~x + 1` (carry chain)  | `~x` (bitwise only)        |
/// | Zero test | all-zeros               | all-zeros OR all-ones      |
/// | Overflow  | MIN_INT ÷ −1 overflows  | symmetric range, never     |
///
/// The critical-path benefit is in the **convert** FSM state: sign-correcting
/// the quotient/remainder requires only a bitwise invert (`~x`) rather than a
/// full carry-propagate add (`~x + 1`), removing an adder from the cycle.
///
/// ### One's complement conventions
///
/// * Positive zero: `000…0`.  Negative zero: `111…1`.
/// * The range is symmetric: `[-(2^(n-1)-1), +(2^(n-1)-1)]`; there is no
///   MIN_INT overflow case.
/// * A divisor of `111…1` (negative zero) triggers [divZero] when
///   `isSigned` is asserted.
class OnesComplementDivider extends Module {
  /// The divider interface (shared with [MultiCycleDivider]).
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

  /// The log of the data width (bits needed to represent [dataWidth]).
  late final int logDataWidth;

  /// When `true` (default), the [remainder] output is computed using the full
  /// O(n²) greedy algorithm. When `false`, [remainder] is always 0 and the
  /// divider uses an O(n) binary long-division algorithm instead.
  final bool computeRemainder;

  /// Creates a one's complement multi-cycle divider.
  OnesComplementDivider(MultiCycleDividerInterface interface,
      {this.computeRemainder = true,
      super.name = 'ones_complement_divider',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : dataWidth = interface.dataWidth,
        logDataWidth = log2Ceil(interface.dataWidth),
        super(
            definitionName: definitionName ??
                'OnesComplementDivider_W${interface.dataWidth}') {
    intf = interface.clone()
      ..pairConnectIO(
        this,
        interface,
        PairRole.consumer,
        uniquify: (original) => '${super.name}_$original',
      );
    _build();
  }

  /// Factory constructor matching [MultiCycleDivider.ofLogics].
  factory OnesComplementDivider.ofLogics({
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
    return OnesComplementDivider(intf,
        computeRemainder: computeRemainder,
        reserveName: reserveName,
        reserveDefinitionName: reserveDefinitionName,
        definitionName:
            definitionName ?? 'OnesComplementDivider_W${intf.dataWidth}');
  }

  void _build() {
    if (computeRemainder) {
      _buildWithRemainder();
    } else {
      _buildQuotientOnly();
    }
  }

  // ---------------------------------------------------------------------------
  // Signed-arithmetic helpers (1's complement)
  //
  //   negate(x)       = ~x
  //   isZero(divisor) = ~d.or() | (d.and() & isSigned)
  // ---------------------------------------------------------------------------

  /// Detects a zero divisor: positive zero (all-zeros) OR negative zero
  /// (all-ones, only when [MultiCycleDividerInterface.isSigned] is asserted).
  Logic _isZero(Logic rawDivisor) =>
      ~rawDivisor.or() | (rawDivisor.and() & intf.isSigned);

  // ---------------------------------------------------------------------------
  // O(n²) greedy algorithm — computes quotient AND remainder
  // ---------------------------------------------------------------------------

  void _buildWithRemainder() {
    final aBuf = Logic(name: 'aBuf', width: dataWidth + 1);
    final rBuf = Logic(name: 'rBuf', width: dataWidth + 1);
    final bBuf = Logic(name: 'bBuf', width: dataWidth + 1);
    final signOut = Logic(name: 'signOut');
    final signNum = Logic(name: 'signNum');

    final outBuffer = Logic(name: 'outBuffer', width: dataWidth + 1);
    final lastSuccess = Logic(name: 'lastSuccess', width: dataWidth + 1);
    final tmpDifference = Logic(name: 'tmpDifference', width: dataWidth + 1);
    final lastDifference = Logic(name: 'lastDifference', width: dataWidth + 1);
    final tmpShift = Logic(name: 'tmpShift', width: dataWidth + 1);
    // logDataWidth+1 bits so currIndex can reach dataWidth, allowing
    // bBuf<<currIndex to overflow to zero (loop-exit condition).
    final currIndex = Logic(name: 'currIndex', width: logDataWidth + 1);

    intf.quotient <= outBuffer.getRange(0, dataWidth);
    // After negating −0 (0xFF) via ~: ~0xFF = 0x00, so all-zeros check holds.
    intf.divZero <= ~bBuf.or();
    intf.remainder <= rBuf.getRange(0, dataWidth);

    // One's complement has a symmetric range — MIN_INT ÷ −1 never overflows,
    // so the process state needs no special-case overflow guard.
    final fsm = FiniteStateMachine<MultiCycleDividerStates>(
      intf.clk,
      intf.reset,
      MultiCycleDividerStates.ready,
      [
        State<MultiCycleDividerStates>(
          MultiCycleDividerStates.ready,
          events: {
            intf.validIn & _isZero(intf.divisor): MultiCycleDividerStates.done,
            intf.validIn: MultiCycleDividerStates.process,
          },
          actions: [],
        ),
        State<MultiCycleDividerStates>(
          MultiCycleDividerStates.process,
          events: {
            ~tmpShift.or() | tmpDifference[-1] | ~tmpDifference.or():
                MultiCycleDividerStates.accumulate,
          },
          actions: [
            tmpShift < (bBuf << currIndex),
            tmpDifference < (aBuf - tmpShift),
          ],
        ),
        State<MultiCycleDividerStates>(
          MultiCycleDividerStates.accumulate,
          events: {
            ~lastDifference.or() | (bBuf > aBuf):
                MultiCycleDividerStates.convert,
            Const(1): MultiCycleDividerStates.process,
          },
          actions: [
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
          events: {intf.readyOut: MultiCycleDividerStates.ready},
          actions: [],
        ),
      ],
      setupActions: [tmpShift < 0, tmpDifference < 0],
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
          signNum < 0,
        ]),
        ElseIf(inState(MultiCycleDividerStates.ready) & intf.validIn, [
          // Negate by ~x only (no carry chain).
          aBuf <
              mux(extDividendIn[dataWidth - 1] & intf.isSigned, ~extDividendIn,
                  extDividendIn),
          bBuf <
              mux(extDivisorIn[dataWidth - 1] & intf.isSigned, ~extDivisorIn,
                  extDivisorIn),
          signOut <
              (intf.dividend[dataWidth - 1] ^ intf.divisor[dataWidth - 1]) &
                  intf.isSigned,
          signNum < intf.dividend[dataWidth - 1] & intf.isSigned,
        ]),
        ElseIf(inState(MultiCycleDividerStates.accumulate), [
          aBuf < lastDifference,
          bBuf < bBuf,
          signOut < signOut,
          signNum < signNum,
        ]),
        Else([
          aBuf < aBuf,
          bBuf < bBuf,
          signOut < signOut,
          signNum < signNum,
        ]),
      ])
    ]);

    // Remainder sign correction: ~aBuf (no carry).
    final aBufConv = mux(signNum, ~aBuf, aBuf);
    Sequential(intf.clk, [
      If.block([
        Iff(intf.reset, [rBuf < Const(0, width: dataWidth + 1)]),
        ElseIf(inState(MultiCycleDividerStates.convert), [rBuf < aBufConv]),
        Else([rBuf < rBuf]),
      ])
    ]);

    Sequential(intf.clk, [
      If.block([
        Iff(intf.reset, [currIndex < Const(0, width: logDataWidth + 1)]),
        ElseIf(inState(MultiCycleDividerStates.process),
            [currIndex < (currIndex + Const(1, width: logDataWidth + 1))]),
        Else([currIndex < Const(0, width: logDataWidth + 1)]),
      ])
    ]);

    Sequential(intf.clk, [
      If.block([
        Iff(intf.reset, [lastSuccess < 0, lastDifference < 0]),
        ElseIf(inState(MultiCycleDividerStates.ready) & intf.validIn, [
          lastSuccess < 0,
          lastDifference <
              mux(extDividendIn[dataWidth - 1] & intf.isSigned, ~extDividendIn,
                  extDividendIn),
        ]),
        ElseIf(inState(MultiCycleDividerStates.process), [
          If(~tmpDifference[-1], then: [
            lastSuccess < (Const(1, width: dataWidth + 1) << currIndex),
            lastDifference < tmpDifference,
          ], orElse: [
            lastSuccess < lastSuccess,
            lastDifference < lastDifference,
          ]),
        ]),
        Else([lastSuccess < 0, lastDifference < lastDifference]),
      ])
    ]);

    Sequential(intf.clk, [
      If.block([
        Iff(intf.reset, [outBuffer < 0]),
        ElseIf(inState(MultiCycleDividerStates.done), [
          outBuffer <
              mux(intf.readyOut, Const(0, width: dataWidth + 1), outBuffer),
        ]),
        ElseIf(inState(MultiCycleDividerStates.convert), [
          // Sign correction: ~outBuffer (no carry chain).
          outBuffer < mux(signOut, ~outBuffer, outBuffer),
        ]),
        ElseIf(inState(MultiCycleDividerStates.accumulate),
            [outBuffer < (outBuffer + lastSuccess)]),
        Else([outBuffer < outBuffer]),
      ])
    ]);
  }

  // ---------------------------------------------------------------------------
  // O(n) binary long-division — quotient only, remainder always 0
  // ---------------------------------------------------------------------------

  void _buildQuotientOnly() {
    final aBuf = Logic(name: 'aBuf', width: dataWidth + 1);
    final bBuf = Logic(name: 'bBuf', width: dataWidth + 1);
    final signOut = Logic(name: 'signOut');
    final outBuffer = Logic(name: 'outBuffer', width: dataWidth + 1);
    final partialRem = Logic(name: 'partialRem', width: dataWidth + 1);
    final bitIdx = Logic(name: 'bitIdx', width: widthFor(dataWidth));

    final shiftedRem = Logic(name: 'shiftedRem', width: dataWidth + 1);
    final trialDiff = Logic(name: 'trialDiff', width: dataWidth + 1);
    final quotBit = Logic(name: 'quotBit');

    intf.quotient <= outBuffer.getRange(0, dataWidth);
    intf.divZero <= ~bBuf.or();
    intf.remainder <= Const(0, width: dataWidth);

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
            intf.validIn & _isZero(intf.divisor): MultiCycleDividerStates.done,
            intf.validIn: MultiCycleDividerStates.process,
          },
          actions: [],
        ),
        State<MultiCycleDividerStates>(
          MultiCycleDividerStates.process,
          events: {
            bitIdx.eq(Const(0, width: widthFor(dataWidth))):
                MultiCycleDividerStates.convert,
          },
          actions: [
            shiftedRem <
                ((partialRem << 1) |
                    currentDividendBit.zeroExtend(dataWidth + 1)),
            trialDiff < (shiftedRem - bBuf),
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
          events: {intf.readyOut: MultiCycleDividerStates.ready},
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
          // Negate by ~x only (no carry chain).
          aBuf <
              mux(extDividendIn[dataWidth - 1] & intf.isSigned, ~extDividendIn,
                  extDividendIn),
          bBuf <
              mux(extDivisorIn[dataWidth - 1] & intf.isSigned, ~extDivisorIn,
                  extDivisorIn),
          signOut <
              (intf.dividend[dataWidth - 1] ^ intf.divisor[dataWidth - 1]) &
                  intf.isSigned,
          outBuffer < 0,
          partialRem < 0,
          bitIdx < bitIdxInit,
        ]),
        ElseIf(inState(MultiCycleDividerStates.process), [
          partialRem < mux(quotBit, trialDiff, shiftedRem),
          outBuffer < ((outBuffer << 1) | quotBit.zeroExtend(dataWidth + 1)),
          bitIdx < (bitIdx - Const(1, width: widthFor(dataWidth))),
        ]),
        ElseIf(inState(MultiCycleDividerStates.convert), [
          // Sign correction: ~outBuffer (no carry chain).
          outBuffer < mux(signOut, ~outBuffer, outBuffer),
          bitIdx < bitIdx,
        ]),
        ElseIf(inState(MultiCycleDividerStates.done), [
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

// =============================================================================
