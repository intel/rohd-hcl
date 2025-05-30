// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_adder_simple.dart
// A very basic Floating-point adder component.
//
// 2024 August 30
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An adder module for FloatingPoint values
class FloatingPointAdderSimple<FpType extends FloatingPoint>
    extends FloatingPointAdder<FpType> {
  /// Add two floating point numbers [a] and [b], returning result in [sum].
  /// If a different output type is needed, you can provide that in [outSum].
  /// - [adderGen] is an adder generator to be used in the primary adder
  ///   functions.
  /// - [widthGen] is the splitting function for creating the different adder
  ///   blocks within the internal [CompoundAdder] used for mantissa addition.
  ///   Decreasing the split width will increase speed but also increase area.
  FloatingPointAdderSimple(super.a, super.b,
      {super.outSum,
      super.clk,
      super.reset,
      super.enable,
      Adder Function(Logic a, Logic b, {Logic? carryIn, String name}) adderGen =
          NativeAdder.new,
      List<int> Function(int) widthGen =
          CarrySelectCompoundAdder.splitSelectAdderAlgorithmSingleBlock,
      super.name = 'floatingpoint_adder_simple'})
      : super(
            definitionName: 'FloatingPointAdderSimple_'
                'E${a.exponent.width}M${a.mantissa.width}') {
    if (a.explicitJBit != b.explicitJBit) {
      throw RohdHclException('Floating point adder does not support '
          'inputs of different jBit types.');
    }
    // Would prefer to use getter here for setting, but the getter
    // translates the type from Logic to FloatingPoint.
    output('sum') <= outputSum;

    final (larger, smaller) = FloatingPointUtilities.sortByExp((a, b));

    final effectiveSubtraction = (a.sign ^ b.sign).named('effSubtraction');

    final isInf = (larger.isAnInfinity | smaller.isAnInfinity).named('isInf');
    final isNaN = (larger.isNaN |
            smaller.isNaN |
            (larger.isAnInfinity &
                smaller.isAnInfinity &
                (larger.sign ^ smaller.sign)))
        .named('isNaN');

    final expDiff = (larger.exponent - smaller.exponent).named('expDiff');
    final largeMantissa = mux(
            ~larger.isNormal ^ Const(larger.explicitJBit),
            [larger.mantissa, Const(0)].swizzle(),
            mux(
                larger.isNormal,
                [Const(1), larger.mantissa].swizzle(),
                [
                  larger.mantissa.getRange(0, mantissaWidth - 1),
                  Const(0, width: 2)
                ].swizzle()))
        .named('largeMantissa');

    final smallMantissa = mux(
            ~smaller.isNormal ^ Const(smaller.explicitJBit),
            [smaller.mantissa, Const(0)].swizzle(),
            mux(
                smaller.isNormal,
                [Const(1), smaller.mantissa].swizzle(),
                [
                  smaller.mantissa.getRange(0, mantissaWidth - 1),
                  Const(0, width: 2)
                ].swizzle()))
        .named('smallMantissa');

    final extendedWidth = min(
        1 + (mantissaWidth + 1) + ((a.explicitJBit) ? 2 : 0),
        pow(2, exponentWidth).toInt() - 2);

    final largeFinalMantissa = largeMantissa;
    final smallExtendedMantissa = [
      smallMantissa,
      Const(0, width: extendedWidth)
    ].swizzle().named('smallExtendedMantissa');
    final smallShiftedMantissa =
        (smallExtendedMantissa >>> expDiff).named('smallShiftedMantissa');

    // Compute sticky bits past extendedWidth: expDiff - extendedWidth
    final eW = Const(extendedWidth, width: expDiff.width).named('eW');
    final rem =
        mux(expDiff.gt(eW), expDiff - eW, Const(0, width: expDiff.width))
            .named('rem');

    final stickyBits =
        (smallMantissa << Const(smallMantissa.width, width: rem.width) - rem)
            .named('stickyBits');
    final stickyBitsOr = stickyBits.or();

    final largeNarrowMantissa = largeFinalMantissa;
    final smallNarrowMantissa = smallShiftedMantissa.getRange(extendedWidth);

    final highBitsAdder = CarrySelectOnesComplementCompoundAdder(
        largeNarrowMantissa, smallNarrowMantissa,
        generateCarryOut: true,
        generateCarryOutP1: true,
        subtractIn: effectiveSubtraction,
        widthGen: widthGen,
        adderGen: adderGen);

    final carry = highBitsAdder.carryOut!;

    final hSum = highBitsAdder.sum.named('highBitsSum');
    final hSumP1 = highBitsAdder.sumP1.named('highBitsSumP1');

    final lowerBits =
        smallShiftedMantissa.getRange(0, extendedWidth).named('lowerBits');

    final trueSign = mux(carry, larger.sign, smaller.sign).named('trueSign');

    final lowBitsIncrement = (effectiveSubtraction & carry & expDiff.neq(0))
        .named('lowBitsIncrement');

    final carryBits = ~lowerBits.or();

    final highBitsLSB =
        (carryBits & (~stickyBitsOr & lowBitsIncrement)).named('highBitsLSB');

    // TODO(desmonddak): This can work on narrow if not explicit-jbit
    // We could optimize by splitting the search across the pipestage for
    // high and low bits (low only matter for explicit-jbit)
    final limitSize = smallShiftedMantissa.width;
    final predictor = LeadingZeroAnticipate(
        Const(0),
        [largeFinalMantissa, Const(0, width: extendedWidth)]
            .swizzle()
            .slice(limitSize - 1, 0),
        effectiveSubtraction,
        smallShiftedMantissa.slice(limitSize - 1, 0),
        endAroundCarry: carry);

    final lead1Prediction = predictor.leadingOne!.named('lead1Prediction');

    final lead1PredictionValid =
        predictor.validLeadOne!.named('lead1PredictionValid');

    final trueSignFlopped = localFlop(trueSign);
    final largerExpFlopped = localFlop(larger.exponent);
    final sumFlopped = localFlop(hSum);
    final sumP1Flopped = localFlop(hSumP1);
    final carryFlopped = localFlop(carry);
    final isInfFlopped = localFlop(isInf);
    final isNaNFlopped = localFlop(isNaN);
    final highBitsLSBFlopped = localFlop(highBitsLSB);
    final lowerBitsFlopped = localFlop(lowerBits);
    final lowBitsOrFlopped = localFlop(stickyBitsOr);
    final lowInvertFlopped = localFlop(lowBitsIncrement);

    final effectiveSubtractionFlopped = localFlop(effectiveSubtraction);
    final leadingZerosPredictionValidFlopped = localFlop(lead1PredictionValid);
    final leadingZerosPredictionFlopped = localFlop(lead1Prediction);
    final expDiffFlopped = localFlop(expDiff);

    var incrementHighLSB = (sumFlopped +
            ((highBitsLSBFlopped | expDiffFlopped.eq(0)) &
                    effectiveSubtractionFlopped &
                    carryFlopped)
                .zeroExtend(sumFlopped.width))
        .named('incrementHighLSB');

    final incrementHighLSBN = mux(
            (highBitsLSBFlopped | expDiffFlopped.eq(0)) &
                effectiveSubtractionFlopped &
                carryFlopped,
            sumP1Flopped,
            sumFlopped)
        .named('incrementHighLSB');
    incrementHighLSB = incrementHighLSBN;

    final lowerBitsPolarity =
        mux(lowInvertFlopped, ~lowerBitsFlopped, lowerBitsFlopped)
            .named('lowerBitsPolarity');

    final lowBitsSum = adderGen(
            (~lowBitsOrFlopped & lowInvertFlopped).zeroExtend(lowerBits.width),
            lowerBitsPolarity)
        .sum
        .named('lowBitsSum');

    final fullSumWithIncrement = [
      incrementHighLSB,
      lowBitsSum.slice(lowBitsSum.width - 2, 0)
    ].swizzle().named('fullMantissaWithIncr');

    final fullMantissa = fullSumWithIncrement
        .slice(fullSumWithIncrement.width - 2, 0)
        .named('fullMantissa');

    final lead1PredictionFlopped = leadingZerosPredictionFlopped;

    final shiftedPrediction = (fullSumWithIncrement << lead1PredictionFlopped)
        .named('shiftedPrediction');

    final lead1Final = mux(shiftedPrediction[-1], lead1PredictionFlopped,
            lead1PredictionFlopped + 1)
        .named('lead1Final');

    final shiftL1Final =
        mux(shiftedPrediction[-1], shiftedPrediction, shiftedPrediction << 1)
            .slice(shiftedPrediction.width - (outputSum.explicitJBit ? 1 : 2),
                (outputSum.explicitJBit ? 1 : 0))
            .named('shiftL1Final');

    final lead1Valid = leadingZerosPredictionValidFlopped;

    final infExponent =
        outputSum.inf(sign: trueSignFlopped).exponent.named('infExponent');

    final lead1 = ((lead1Final.width > exponentWidth)
            ? mux(lead1Final.gte(infExponent.zeroExtend(lead1Final.width)),
                infExponent, lead1Final.getRange(0, exponentWidth))
            : lead1Final.zeroExtend(exponentWidth))
        .named('lead1');

    final lead1Dominates =
        (lead1.gt(largerExpFlopped) | ~lead1Valid).named('lead1Dominates');

    final exponent = mux(
            lead1Dominates,
            outputSum.zeroExponent,
            (largerExpFlopped - lead1 + Const(1, width: lead1.width))
                .named('expMinusLead1'))
        .named('outExponent');

    final shiftMantissaByExp =
        (fullMantissa << largerExpFlopped).named('shiftMantissaByExp');

    final mantissa =
        mux(lead1Dominates, shiftMantissaByExp, shiftL1Final).named('mantissa');

    final doRound =
        RoundRNE(mantissa, extendedWidth + 1).doRound.named('doRound');

    final mantissaTrimmed =
        mantissa.getRange(extendedWidth + 1).named('mantissaTrimmed');

    final rndAdder =
        adderGen(mantissaTrimmed, doRound.zeroExtend(mantissaWidth));

    final newRnd = rndAdder.sum;

    var mantissaRound = newRnd.slice(outputSum.explicitJBit ? -1 : -2,
        -mantissaWidth - (outputSum.explicitJBit ? 0 : 1));

    final altmantissaRound = newRnd.slice(-2, -mantissaWidth - 1);

    mantissaRound = mux(
            exponent.gt(Const(0, width: exponent.width)) & ~mantissaRound[-1],
            altmantissaRound,
            mantissaRound)
        .named('mantissaRoundFinal');

    final exponentRound =
        exponent + rndAdder.sum[-1].zeroExtend(exponent.width);

    final realIsInf =
        (isInfFlopped | exponent.eq(infExponent)).named('realIsInf');

    Combinational([
      If.block([
        Iff(isNaNFlopped, [
          outputSum < outputSum.nan,
        ]),
        ElseIf(realIsInf, [
          outputSum < outputSum.inf(sign: trueSignFlopped),
        ]),
        ElseIf(lead1Dominates, [
          outputSum.sign < trueSignFlopped,
          outputSum.exponent < outputSum.zeroExponent,
          outputSum.mantissa < mantissaRound,
        ]),
        Else([
          outputSum.sign < trueSignFlopped,
          outputSum.exponent < exponentRound,
          outputSum.mantissa < mantissaRound,
        ])
      ])
    ]);
  }
}
