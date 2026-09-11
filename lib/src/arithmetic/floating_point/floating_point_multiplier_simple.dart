// Copyright (C) 2024-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_multiplier_simple.dart
// Implementation of a non-rounding floating-point multiplier.
//
// 2024 December 30
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A multiplier module for [FloatingPoint] logic.
class FloatingPointMultiplierSimple<FpTypeIn extends FloatingPoint,
        FpTypeOut extends FloatingPoint>
    extends FloatingPointMultiplier<FpTypeIn, FpTypeOut> {
  /// Multiply two [FloatingPoint] numbers [a] and [b], returning result
  /// in [product] [FloatingPoint].
  /// - [multGen] is a multiplier generator to be used in the mantissa
  /// multiplication.
  /// - [priorityGen] is a [PriorityEncoder] generator to be used in the
  /// leading one detection (default [RecursiveModulePriorityEncoder]).
  ///
  /// The multiplier supports a [product] with narrower exponent and/or
  /// mantissa fields than the inputs, in which case [roundingMode] is used to
  /// round the result and overflow saturates to infinity (or the largest
  /// finite value if [FloatingPoint.supportsInfinities] is `false`).
  FloatingPointMultiplierSimple(super.a, super.b,
      {super.clk,
      super.reset,
      super.enable,
      super.outProduct,
      super.roundingMode = FloatingPointRoundingMode.truncate,
      Multiplier Function(Logic a, Logic b,
              {Logic? clk, Logic? reset, Logic? enable, String name})
          multGen = NativeMultiplier.new,
      PriorityEncoder Function(Logic bitVector,
              {bool generateValid, String name})
          priorityGen = RecursiveModulePriorityEncoder.new,
      super.name,
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'FloatingPointMultiplierSimple_'
                    'E${a.exponent.width}M${a.mantissa.width}'
                    '${outProduct != null ? '_OE${outProduct.exponent.width}_'
                        'OM${outProduct.mantissa.width}' : ''}') {
    if (a.subNormalAsZero | b.subNormalAsZero) {
      throw ArgumentError('FloatingPointMultiplierSimple does not '
          'support denormal as zero (DAZ)');
    }
    if (internalProduct.subNormalAsZero) {
      throw ArgumentError('FloatingPointMultiplierSimple does not '
          'support flush to zero (FTZ)');
    }

    final aMantissa = mux(a.isNormal, [a.isNormal, a.mantissa].swizzle(),
            [a.mantissa, Const(0)].swizzle())
        .named('aMantissa');
    final bMantissa = mux(b.isNormal, [b.isNormal, b.mantissa].swizzle(),
            [b.mantissa, Const(0)].swizzle())
        .named('bMantissa');

    // Raw (unrounded) product mantissa width, independent of the output
    // mantissa width: this is always the full double-width product.
    final rawMantissaWidth = (a.mantissa.width + 1) * 2;

    // Sized to safely hold the sum of the input exponents (rebiased to the
    // output format) and the leading-one position within the raw mantissa
    // product, regardless of whether the output exponent/mantissa are
    // narrower or wider than the inputs.
    final expCalcWidth = max(
        max(exponentWidth, max(a.exponent.width, b.exponent.width)) + 2,
        log2Ceil(rawMantissaWidth + 1) + 1);
    final addBias =
        (a.bias.zeroExtend(expCalcWidth) + b.bias.zeroExtend(expCalcWidth))
            .named('addBias');
    final deltaBias =
        (product.bias.zeroExtend(expCalcWidth) - addBias).named('rebias');
    final addExp = (a.exponent.zeroExtend(expCalcWidth) +
            b.exponent.zeroExtend(expCalcWidth))
        .named('addExp');
    final productExp = (addExp + deltaBias).named('productExp');

    final mantissaMult = multGen(aMantissa, bMantissa,
        clk: clk, reset: reset, enable: enable, name: 'mantissa_mult');

    final mantissa =
        mantissaMult.product.getRange(0, rawMantissaWidth).named('mantissa');

    final isInf = (a.isAnInfinity | b.isAnInfinity).named('isInf');
    final invalidArithmetic =
        ((a.isAnInfinity | b.isAnInfinity) & (a.isAZero | b.isAZero))
            .named('invalidArithmetic');
    final invalidOperation =
        (a.isSignalingNaN | b.isSignalingNaN | invalidArithmetic)
            .named('invalidOperation');
    final isNaN = (a.isNaN | b.isNaN | invalidArithmetic).named('isNaN');
    final inputIsNaN = (a.isNaN | b.isNaN).named('inputIsNaN');
    final propagatedNaN = internalProduct.propagateNaN(a, b);

    final productExpLatch = localFlop(productExp);
    final aSignLatch =
        localFlop(a.sign).named('a_sign', naming: Naming.renameable);
    final bSignLatch =
        localFlop(b.sign).named('b_sign', naming: Naming.renameable);
    final isInfLatch = localFlop(isInf);
    final isNaNLatch = localFlop(isNaN);
    final invalidOperationLatch = localFlop(invalidOperation);
    final inputIsNaNLatch = localFlop(inputIsNaN);
    final nanSignLatch = localFlop(propagatedNaN.sign);
    final nanMantissaLatch = localFlop(propagatedNaN.mantissa);

    final leadingOnePosPre =
        priorityGen(mantissa.reversed, name: 'leading_one_encoder')
            .out
            .named('leadingOneRaw')
            .zeroExtend(expCalcWidth)
            .named('leadingOneRawExtended', naming: Naming.mergeable);

    final leadingOnePos = mux(
            leadingOnePosPre.gte(mantissa.width),
            Const(product.bias.value.toInt() + 1,
                width: leadingOnePosPre.width),
            leadingOnePosPre)
        .named('leadingOnePosition');

    final remainingExp =
        ((productExpLatch - leadingOnePos).named('productExpMinusLeadOne') + 1)
            .named('remainingExp');

    final fullMantissa = (mantissaWidth + 1 > mantissa.width)
        ? [
            mantissa,
            Const(0, width: mantissaWidth + 1 - mantissa.width, fill: true)
          ].swizzle().named('extendMantissa')
        : mantissa.named('fullMantissa');

    final shiftAmount = mux(
            productExpLatch[-1] | productExpLatch.lt(leadingOnePos),
            productExpLatch,
            leadingOnePos)
        .named('shiftAmount');
    final fullShift =
        SignedShifter(fullMantissa, shiftAmount, name: 'full_mantissa_shifter')
            .shifted
            .named('shiftMantissa');
    final retainedLsb = fullShift.width - mantissaWidth - 1;

    // A right shift on a fixed-width register can lose set bits below bit 0
    // (not just when the entire result becomes zero, as when only some of
    // the low bits shifted out were set). Recover those lost bits by
    // shifting the pre-shift mantissa left by the complementary amount: any
    // bits that would have fallen off the bottom land back at the top.
    final rightShiftAmount = shiftAmount.abs().named('rightShiftAmount');
    final isRightShift = shiftAmount[-1].named('isRightShift');
    final safeRightShift = mux(rightShiftAmount.gte(fullMantissa.width),
            Const(0, width: rightShiftAmount.width), rightShiftAmount)
        .named('safeRightShift');
    final partialLostBits = (isRightShift &
            (fullMantissa <<
                    (Const(fullMantissa.width, width: safeRightShift.width) -
                        safeRightShift))
                .or())
        .named('partialLostBits');
    final shiftedOutSticky =
        ((mantissa.or() & ~fullShift.or()) | partialLostBits)
            .named('shiftedOutSticky');
    final rounder = FloatingPointRounder(fullShift, retainedLsb,
        roundingMode: roundingMode,
        sign: aSignLatch ^ bSignLatch,
        extraSticky: shiftedOutSticky);
    final retainedSignificand =
        fullShift.getRange(retainedLsb).named('retainedSignificand');
    final roundedSignificand =
        (retainedSignificand.zeroExtend(retainedSignificand.width + 1) +
                rounder.doRound.zeroExtend(retainedSignificand.width + 1))
            .named('roundedSignificand');
    final roundingCarry = roundedSignificand[-1].named('roundingCarry');
    final roundedToNormal = ((remainingExp[-1] | ~remainingExp.or()) &
            roundedSignificand[retainedSignificand.width - 1])
        .named('roundedToNormal');
    final finalMantissa = mux(roundingCarry, roundedSignificand.slice(-2, 1),
            roundedSignificand.slice(-3, 0))
        .named('finalMantissa');
    final roundedExp = (remainingExp +
            (roundingCarry | roundedToNormal).zeroExtend(remainingExp.width))
        .named('roundedExponent');
    final largestFinite = product
        .valuePopulator()
        .ofConstant(FloatingPointConstants.largestNormal);
    final maxFiniteExponent =
        Const(largestFinite.exponent).zeroExtend(roundedExp.width);
    final maxFiniteMantissa = Const(largestFinite.mantissa);
    final finiteOverflow = (~roundedExp[-1] &
            (roundedExp.gt(maxFiniteExponent) |
                (roundedExp.eq(maxFiniteExponent) &
                    finalMantissa.gt(maxFiniteMantissa))))
        .named('finiteOverflow');
    final finiteRounderInexact = (rounder.inexact & ~isInfLatch & ~isNaNLatch)
        .named('finiteRounderInexact');
    final resultSign = (aSignLatch ^ bSignLatch).named('resultSign');
    final overflowToInfinity = switch (roundingMode) {
      FloatingPointRoundingMode.roundNearestEven ||
      FloatingPointRoundingMode.roundNearestTiesAway =>
        Const(1),
      FloatingPointRoundingMode.truncate ||
      FloatingPointRoundingMode.roundTowardsZero =>
        Const(0),
      FloatingPointRoundingMode.roundTowardsInfinity => ~resultSign,
      FloatingPointRoundingMode.roundTowardsNegativeInfinity => resultSign,
    };
    internalStatus.invalid <= invalidOperationLatch;
    internalStatus.divideByZero <= Const(0);
    internalStatus.overflow <= finiteOverflow & ~isInfLatch & ~isNaNLatch;
    internalStatus.underflow <=
        (roundedExp[-1] | ~roundedExp.or()) & finiteRounderInexact;
    internalStatus.inexact <=
        (finiteOverflow & ~isInfLatch & ~isNaNLatch) | finiteRounderInexact;

    Combinational([
      If(isNaNLatch, then: [
        internalProduct.sign <
            mux(inputIsNaNLatch, nanSignLatch, product.nan.sign),
        internalProduct.exponent < product.nan.exponent,
        internalProduct.mantissa <
            mux(inputIsNaNLatch, nanMantissaLatch, product.nan.mantissa),
      ], orElse: [
        If(isInfLatch, then: [
          internalProduct < product.inf(sign: resultSign),
        ], orElse: [
          If(finiteOverflow & overflowToInfinity, then: [
            internalProduct < product.inf(sign: resultSign),
          ], orElse: [
            If(finiteOverflow, then: [
              internalProduct < internalProduct.largestFinite(sign: resultSign),
            ], orElse: [
              internalProduct.sign < resultSign,
              If(roundedExp[-1], then: [
                internalProduct.exponent < Const(0, width: exponentWidth)
              ], orElse: [
                internalProduct.exponent <
                    roundedExp.getRange(0, exponentWidth),
              ]),
              internalProduct.mantissa < finalMantissa
            ])
          ])
        ])
      ])
    ]);
  }
}
