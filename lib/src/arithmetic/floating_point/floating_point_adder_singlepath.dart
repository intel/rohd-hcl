// Copyright (C) 2024-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_adder_singlepath.dart
// A single-path Floating-point adder component.
//
// 2024 August 30
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A single-path adder implementation for [FloatingPoint] values.
class FloatingPointAdderSinglePath<FpTypeIn extends FloatingPoint,
        FpTypeOut extends FloatingPoint>
    extends FloatingPointAdder<FpTypeIn, FpTypeOut> {
  /// Add two floating point numbers [a] and [b], returning result in [sum]. If
  /// a different output type is needed, you can provide that in [outSum].
  ///
  /// If the output is an explicit Jbit type, the option [normalizeOutput] can
  /// be turned off which allows for saving latency by not normalizing. This
  /// will lose accuracy unless the output is wide enough to not truncate or
  /// round the shifted output.
  /// - [adderGen] is an adder generator to be used in the primary adder
  ///   functions.
  /// - [widthGen] is the splitting function for creating the different adder
  ///   blocks within the internal [CompoundAdder] used for mantissa addition.
  ///   Decreasing the split width will increase speed but also increase area.
  ///
  FloatingPointAdderSinglePath(super.a, super.b,
      {super.outSum,
      super.clk,
      super.reset,
      super.enable,
      super.roundingMode = FloatingPointRoundingMode.roundNearestEven,
      bool normalizeOutput = true,
      Adder Function(Logic a, Logic b, {Logic? carryIn, String name}) adderGen =
          NativeAdder.new,
      List<int> Function(int) widthGen =
          CarrySelectCompoundAdder.splitSelectAdderAlgorithmSingleBlock,
      super.name = 'floatingpoint_adder_singlepath',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'FloatingPointAdderSinglePath_'
                    'E${a.exponent.width}M${a.mantissa.width}') {
    if (internalSum.exponent.width != a.exponent.width) {
      throw RohdHclException('This adder currently only supports '
          'output exponent width equal to input exponent width.');
    }
    if (internalSum.mantissa.width < a.mantissa.width) {
      throw RohdHclException('This adder currently only supports '
          'output mantissa width greater than or equal '
          'to input mantissa width.');
    }
    if (!normalizeOutput & !internalSum.explicitJBit) {
      throw RohdHclException('This adder only supports '
          'not normalizing anexplicit JBit output.');
    }
    final fa = a.resolveSubNormalAsZero();
    final fb = b.resolveSubNormalAsZero();

    final aExplicit = Const(a.explicitJBit);
    final bExplicit = Const(b.explicitJBit);
    final swapper = FloatingPointSortByExp(fa, fb,
        metaA: aExplicit, metaB: bExplicit, name: 'sorter_${a.name}_${b.name}');
    final larger = swapper.outA;
    final smaller = swapper.outB;
    final largerExplicit = swapper.outMetaA!;
    final smallerExplicit = swapper.outMetaB!;

    final effectiveSubtraction = (fa.sign ^ fb.sign).named('effSubtraction');

    final isInf = (larger.isAnInfinity | smaller.isAnInfinity).named('isInf');
    final invalidArithmetic = (larger.isAnInfinity &
            smaller.isAnInfinity &
            (larger.sign ^ smaller.sign))
        .named('invalidArithmetic');
    final invalidOperation =
        (super.a.isSignalingNaN | super.b.isSignalingNaN | invalidArithmetic)
            .named('invalidOperation');
    final isNaN =
        (larger.isNaN | smaller.isNaN | invalidArithmetic).named('isNaN');
    final inputIsNaN = (super.a.isNaN | super.b.isNaN).named('inputIsNaN');
    final propagatedNaN = internalSum.propagateNaN(super.a, super.b);

    final expDiff = (larger.exponent - smaller.exponent).named('expDiff');
    final largeMantissa = mux(
            ~larger.isNormal ^ largerExplicit,
            [larger.mantissa, Const(0)].swizzle(),
            mux(
                larger.isNormal,
                [Const(1), larger.mantissa].swizzle(),
                [
                  larger.mantissa.getRange(0, larger.mantissa.width - 1),
                  Const(0, width: 2)
                ].swizzle()))
        .named('largeMantissa');

    final smallMantissa = mux(
            ~smaller.isNormal ^ smallerExplicit,
            [smaller.mantissa, Const(0)].swizzle(),
            mux(
                smaller.isNormal,
                [Const(1), smaller.mantissa].swizzle(),
                [
                  smaller.mantissa.getRange(0, smaller.mantissa.width - 1),
                  Const(0, width: 2)
                ].swizzle()))
        .named('smallMantissa');

    final extendedWidth = min(
        1 +
            (mantissaWidth + 1) +
            (a.explicitJBit ? 1 : 0) +
            (b.explicitJBit ? 1 : 0),
        pow(2, exponentWidth).toInt() - 2);

    final largeFinalMantissa = largeMantissa;
    final smallExtendedMantissa = [
      smallMantissa,
      Const(0, width: extendedWidth)
    ].swizzle().named('smallExtendedMantissa');
    final smallShiftedMantissa =
        (smallExtendedMantissa >>> expDiff).named('smallShiftedMantissa');

    // Compute sticky bits past extendedWidth: expDiff - extendedWidth
    final int posWidth = max(expDiff.width, log2Ceil(smallMantissa.width));
    final eD = expDiff.zeroExtend(posWidth).named('eD');
    final eW = Const(extendedWidth, width: posWidth).named('eW');
    final rem =
        mux(eD.gte(eW), eD - eW, Const(0, width: posWidth)).named('rem');

    final chop = mux(
            rem.lt(Const(smallMantissa.width, width: rem.width)),
            Const(smallMantissa.width, width: rem.width) - rem,
            Const(0, width: rem.width))
        .named('chop');

    final stickyBits = (smallMantissa << chop).named('stickyBits');

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

    // Note: this predictor must search across the *full* combined
    // high-bits + extendedWidth low-bits range (not just the high bits),
    // even for implicit-jbit (non-explicit) outputs. Verified empirically:
    // narrowing this search to only `largeFinalMantissa.width` for
    // non-explicit-jbit outputs breaks correctness (e.g. 0.0 + 0.25 wrongly
    // computes 0.0), because when the large operand's high bits are all
    // zero (or cancel to zero during subtraction), the true leading one can
    // only be found within the low, extendedWidth-sized region.
    final limitSize = smallShiftedMantissa.width;
    final predictor = LeadingZeroAnticipateCarry(
        Const(0),
        [largeFinalMantissa, Const(0, width: extendedWidth)]
            .swizzle()
            .slice(limitSize - 1, 0),
        effectiveSubtraction,
        smallShiftedMantissa.slice(limitSize - 1, 0),
        endAroundCarry: carry);

    final lead1Prediction = predictor.leadingOne.named('lead1Prediction');

    final lead1PredictionValid =
        predictor.validLeadOne.named('lead1PredictionValid');

    final trueSignFlopped = localFlop(trueSign);
    final largerExpFlopped = localFlop(larger.exponent);
    final sumFlopped = localFlop(hSum);
    final sumP1Flopped = localFlop(hSumP1);
    final carryFlopped = localFlop(carry);
    final isInfFlopped = localFlop(isInf);
    final isNaNFlopped = localFlop(isNaN);
    final invalidOperationFlopped = localFlop(invalidOperation);
    final inputIsNaNFlopped = localFlop(inputIsNaN);
    final nanSignFlopped = localFlop(propagatedNaN.sign);
    final nanMantissaFlopped = localFlop(propagatedNaN.mantissa);
    final highBitsLSBFlopped = localFlop(highBitsLSB);
    final lowerBitsFlopped = localFlop(lowerBits);
    final lowBitsOrFlopped = localFlop(stickyBitsOr);
    final lowInvertFlopped = localFlop(lowBitsIncrement);
    final stickyBitsOrFlopped = localFlop(stickyBitsOr);

    final effectiveSubtractionFlopped = localFlop(effectiveSubtraction);
    final leadingZerosPredictionValidFlopped = localFlop(lead1PredictionValid);
    final lead1PredictionFlopped = localFlop(lead1Prediction);
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

    final trueLowBits = lowBitsSum.slice(lowBitsSum.width - 2, 0) |
        stickyBitsOrFlopped
            .zeroExtend(lowBitsSum.width - 1)
            .named('trueLowBits');

    final fullSumWithIncrement =
        [incrementHighLSB, trueLowBits].swizzle().named('fullMantissaWithIncr');

    final fullMantissa = fullSumWithIncrement
        .slice(fullSumWithIncrement.width - 2, 0)
        .named('fullMantissa');

    final shiftedPrediction = (fullSumWithIncrement << lead1PredictionFlopped)
        .named('shiftedPrediction');

    final lead1Final = mux(shiftedPrediction[-1], lead1PredictionFlopped,
            lead1PredictionFlopped + 1)
        .named('lead1Final');

    final shiftL1Final =
        mux(shiftedPrediction[-1], shiftedPrediction, shiftedPrediction << 1)
            .named('shiftL1Final')
            .slice(shiftedPrediction.width - (internalSum.explicitJBit ? 1 : 2),
                (internalSum.explicitJBit ? 1 : 0));

    final lead1Valid = leadingZerosPredictionValidFlopped;

    final infExponent =
        internalSum.inf(sign: trueSignFlopped).exponent.named('infExponent');

    final lead1 = ((lead1Final.width > exponentWidth)
            ? mux(lead1Final.gte(infExponent.zeroExtend(lead1Final.width)),
                infExponent, lead1Final.getRange(0, exponentWidth))
            : lead1Final.zeroExtend(exponentWidth))
        .named('lead1');

    final lead1Dominates =
        (lead1.gt(largerExpFlopped) | ~lead1Valid).named('lead1Dominates');

    final exponentWide = mux(
            lead1Dominates,
            internalSum.zeroExponent.zeroExtend(exponentWidth + 1),
            (largerExpFlopped.zeroExtend(exponentWidth + 1) -
                    lead1.zeroExtend(exponentWidth + 1) +
                    Const(1, width: exponentWidth + 1))
                .named('expMinusLead1'))
        .named('outExponentWide');
    final exponent =
        exponentWide.getRange(0, exponentWidth).named('outExponent');

    final shiftMantissaByExp =
        (fullMantissa << largerExpFlopped).named('shiftMantissaByExp');

    final mantissa =
        mux(lead1Dominates, shiftMantissaByExp, shiftL1Final).named('mantissa');

    final outExtendedWidth =
        max(0, extendedWidth - (mantissaWidth - larger.mantissa.width));
    // Note: `mantissaWidth` here is the *output* mantissa width (this
    // class's field), so when widening (mantissaWidth > input mantissa
    // width) the subtraction above algebraically cancels most of that
    // growth back out, leaving `outExtendedWidth` pinned to roughly the
    // *input* mantissa width regardless of how wide the output is. This
    // looks suspicious but is correct: `mantissa` above (via
    // `shiftMantissaByExp`/`shiftL1Final`) is already a register whose
    // width scales with `exponentWidth` (through the `<< largerExpFlopped`
    // shift), so `mantissaTrimmed`'s width still grows with the output
    // format as needed. Verified empirically with an exhaustive sweep
    // combining a wide exponent (allowing large shifts) with a much wider
    // output mantissa (e.g. widening mantissaWidth 4 -> 30 with
    // exponentWidth 6): 0 mismatches against the value-side oracle.
    final mantissaTrimmed =
        mantissa.getRange(outExtendedWidth + 1).named('mantissaTrimmed');

    Logic mantissaRound;
    Logic exponentRound;
    Logic roundingInexact;
    Logic roundingCarry;
    final rndPos = outExtendedWidth + 1;
    if (rndPos >= 2) {
      final rounder = FloatingPointRounder(
          mux(exponent.or(), mantissa,
                  mantissa >> (internalSum.explicitJBit ? 1 : 0))
              .named('mantissaJBitShift'),
          rndPos,
          roundingMode: roundingMode,
          sign: trueSignFlopped);
      final doRound = rounder.doRound.named('doRound');
      roundingInexact = rounder.inexact;

      final rndAdder = adderGen(
          mantissaTrimmed, doRound.zeroExtend(mantissaTrimmed.width),
          name: 'rndAdder');

      final newRnd = rndAdder.sum.named('newRnd');

      mantissaRound = newRnd
          .slice(internalSum.explicitJBit ? -1 : -2,
              -mantissaTrimmed.width - (internalSum.explicitJBit ? 0 : 1))
          .named('mantissaRound');

      final altmantissaRound = newRnd.slice(-2, -mantissaTrimmed.width - 1);

      mantissaRound = mux(
              exponent.gt(Const(0, width: exponent.width)) & ~mantissaRound[-1],
              altmantissaRound,
              mantissaRound)
          .slice(-1, -mantissaWidth)
          .named('mantissaRoundFinal');

      roundingCarry = rndAdder.sum[-1];
    } else {
      // No rounding needed, just use the mantissa as is. But mimic how the
      // rounding adder extends by one to keep the exact same computation
      // as above for now.
      mantissaRound = mantissaTrimmed
          .zeroExtend(mantissaTrimmed.width + 1)
          .slice(internalSum.explicitJBit ? -1 : -2,
              -mantissaTrimmed.width - (internalSum.explicitJBit ? 0 : 1));
      final altMantissaRound = mantissaTrimmed
          .zeroExtend(mantissaTrimmed.width + 1)
          .slice(-2, -mantissaTrimmed.width - 1);
      mantissaRound = mux(
              exponent.gt(Const(0, width: exponent.width)) & ~mantissaRound[-1],
              altMantissaRound,
              mantissaRound)
          .named('mantissaRoundPreFinal');
      if (mantissaRound.width < mantissaWidth) {
        mantissaRound = [
          mantissaRound,
          Const(0, width: mantissaWidth - mantissaRound.width)
        ].swizzle().named('mantissaRoundFinal');
      }
      roundingCarry = Const(0);
      roundingInexact = Const(0);
    }
    final exponentRoundWide =
        (exponentWide + roundingCarry.zeroExtend(exponent.width + 1))
            .named('exponentRoundWide');
    exponentRound =
        exponentRoundWide.getRange(0, exponent.width).named('exponentRound');
    // Handle Flush to Zero subnormal case
    mantissaRound = (internalSum.subNormalAsZero
        ? mux(lead1Dominates | ~exponentRound.or(),
            Const(0, width: mantissaRound.width), mantissaRound)
        : mantissaRound);

    final largestFinite = internalSum
        .valuePopulator()
        .ofConstant(FloatingPointConstants.largestNormal);
    final maxFiniteExponent =
        Const(largestFinite.exponent).zeroExtend(exponentRoundWide.width);
    final maxFiniteMantissa = Const(largestFinite.mantissa);
    final overflow = (exponentRoundWide.gt(maxFiniteExponent) |
            (exponentRoundWide.eq(maxFiniteExponent) &
                mantissaRound.gt(maxFiniteMantissa)))
        .named('overflow');
    final overflowToInfinity = switch (roundingMode) {
      FloatingPointRoundingMode.roundNearestEven ||
      FloatingPointRoundingMode.roundNearestTiesAway =>
        Const(1),
      FloatingPointRoundingMode.truncate ||
      FloatingPointRoundingMode.roundTowardsZero =>
        Const(0),
      FloatingPointRoundingMode.roundTowardsInfinity => ~trueSignFlopped,
      FloatingPointRoundingMode.roundTowardsNegativeInfinity => trueSignFlopped,
    };
    final finiteOverflow =
        (overflow & ~isInfFlopped & ~isNaNFlopped).named('finiteOverflow');
    internalStatus.invalid <= invalidOperationFlopped;
    internalStatus.divideByZero <= Const(0);
    internalStatus.overflow <= finiteOverflow;
    internalStatus.underflow <=
        ~exponentRound.or() & roundingInexact & ~isNaNFlopped;
    internalStatus.inexact <= finiteOverflow | roundingInexact;

    Combinational([
      If.block([
        Iff(isNaNFlopped, [
          internalSum.sign <
              mux(inputIsNaNFlopped, nanSignFlopped, internalSum.nan.sign),
          internalSum.exponent < internalSum.nan.exponent,
          internalSum.mantissa <
              mux(inputIsNaNFlopped, nanMantissaFlopped,
                  internalSum.nan.mantissa),
        ]),
        ElseIf(isInfFlopped, [
          internalSum < internalSum.inf(sign: trueSignFlopped),
        ]),
        ElseIf(overflow & ~overflowToInfinity, [
          internalSum < internalSum.largestFinite(sign: trueSignFlopped),
        ]),
        ElseIf(overflow, [
          internalSum < internalSum.inf(sign: trueSignFlopped),
        ]),
        ElseIf(lead1Dominates, [
          internalSum.sign < trueSignFlopped,
          internalSum.exponent < internalSum.zeroExponent,
          internalSum.mantissa < mantissaRound,
        ]),
        Else([
          internalSum.sign < trueSignFlopped,
          internalSum.exponent < exponentRound,
          internalSum.mantissa < mantissaRound,
        ])
      ])
    ]);
  }
}
