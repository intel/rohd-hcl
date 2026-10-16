// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Shared FSM and datapath logic for multi-cycle divisors with different
/// signed-number conventions.
abstract class MultiCycleDividerBase extends Module {
  /// The Divider's interface declaration.
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

  /// The log of the data width representing the number of bits required to
  /// store that number.
  late final int logDataWidth;

  /// When `true`, the [remainder] output is computed using the full O(n²)
  /// greedy algorithm. When `false`, [remainder] is always 0 and the divider
  /// uses an O(n) binary long-division algorithm instead.
  final bool computeRemainder;

  /// Creates a shared multi-cycle divider implementation for a given signed
  /// arithmetic convention.
  MultiCycleDividerBase(
    MultiCycleDividerInterface interface, {
    required String definitionName,
    required this.computeRemainder,
    super.name = 'multi_cycle_divider',
    super.reserveName,
    super.reserveDefinitionName,
  })  : dataWidth = interface.dataWidth,
        logDataWidth = log2Ceil(interface.dataWidth),
        super(
          definitionName: definitionName,
        ) {
    intf = interface.clone()
      ..pairConnectIO(
        this,
        interface,
        PairRole.consumer,
        uniquify: (original) => '${super.name}_$original',
      );

    _build();
  }

  /// Negates a signed operand according to the arithmetic convention.
  @protected
  Logic negate(Logic x);

  /// Checks whether the raw divisor is zero for the current arithmetic model.
  @protected
  Logic isZeroDivisor(Logic rawDivisor);

  /// Guards the overflow-specific path in the remainder-building FSM.
  @protected
  Logic overflowSpecialCase(Logic bBuf, Logic signOut, Logic signNum) =>
      Const(0);

  void _build() {
    if (computeRemainder) {
      _buildWithRemainder();
    } else {
      _buildQuotientOnly();
    }
  }

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
    final currIndex = Logic(name: 'currIndex', width: logDataWidth + 1);

    intf.quotient <= outBuffer.getRange(0, dataWidth);
    intf.divZero <= ~bBuf.or();
    intf.remainder <= rBuf.getRange(0, dataWidth);

    final specialCase = overflowSpecialCase(bBuf, signOut, signNum);

    final fsm = FiniteStateMachine<MultiCycleDividerStates>(
      intf.clk,
      intf.reset,
      MultiCycleDividerStates.ready,
      [
        State<MultiCycleDividerStates>(
          MultiCycleDividerStates.ready,
          events: {
            intf.validIn & isZeroDivisor(intf.divisor):
                MultiCycleDividerStates.done,
            intf.validIn: MultiCycleDividerStates.process,
          },
          actions: [],
        ),
        State<MultiCycleDividerStates>(
          MultiCycleDividerStates.process,
          events: {
            specialCase |
                ~tmpShift.or() |
                tmpDifference[-1] |
                ~tmpDifference.or(): MultiCycleDividerStates.accumulate,
          },
          actions: [
            tmpShift < (bBuf << currIndex),
            If(
              specialCase,
              then: [tmpDifference < negate(Const(0, width: dataWidth + 1))],
              orElse: [tmpDifference < (aBuf - tmpShift)],
            ),
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
          events: {
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
          aBuf <
              mux(extDividendIn[dataWidth - 1] & intf.isSigned,
                  negate(extDividendIn), extDividendIn),
          bBuf <
              mux(extDivisorIn[dataWidth - 1] & intf.isSigned,
                  negate(extDivisorIn), extDivisorIn),
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

    final aBufConv = mux(signNum, negate(aBuf), aBuf);
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
        ElseIf(
          inState(MultiCycleDividerStates.process),
          [currIndex < (currIndex + Const(1, width: logDataWidth + 1))],
        ),
        Else([currIndex < Const(0, width: logDataWidth + 1)]),
      ])
    ]);

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
                  negate(extDividendIn), extDividendIn),
        ]),
        ElseIf(
          inState(MultiCycleDividerStates.process),
          [
            If(~tmpDifference[-1], then: [
              lastSuccess < (Const(1, width: dataWidth + 1) << currIndex),
              lastDifference < tmpDifference,
            ], orElse: [
              lastSuccess < lastSuccess,
              lastDifference < lastDifference,
            ]),
          ],
        ),
        Else([
          lastSuccess < 0,
          lastDifference < lastDifference,
        ]),
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
          outBuffer < mux(signOut, negate(outBuffer), outBuffer),
        ]),
        ElseIf(inState(MultiCycleDividerStates.accumulate), [
          outBuffer < (outBuffer + lastSuccess),
        ]),
        Else([outBuffer < outBuffer]),
      ])
    ]);
  }

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
            intf.validIn & isZeroDivisor(intf.divisor):
                MultiCycleDividerStates.done,
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
          aBuf <
              mux(extDividendIn[dataWidth - 1] & intf.isSigned,
                  negate(extDividendIn), extDividendIn),
          bBuf <
              mux(extDivisorIn[dataWidth - 1] & intf.isSigned,
                  negate(extDivisorIn), extDivisorIn),
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
          outBuffer < mux(signOut, negate(outBuffer), outBuffer),
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
