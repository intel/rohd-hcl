// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_adder_simple_dual.dart
// A very basic Floating-point adder component.
//
// 2024 August 30
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An adder module for FloatingPoint values
class FloatingPointAdderSimpleDual extends FloatingPointAdder {
  // /// Retrieve the [FloatingPoint] directly instead of as [FpType].
  // late final FloatingPoint sum =
  //     FloatingPoint(exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
  //       ..gets(output('fp'));

  /// Add two floating point numbers [a] and [b], returning result in [sum].
  /// - [adderGen] is an adder generator to be used in the primary adder
  /// functions.
  /// - [priorityGen] is a [PriorityEncoder] generator to be used in the
  /// leading one detection (default [RecursiveModulePriorityEncoder]).
  FloatingPointAdderSimpleDual(super.a, super.b,
      {super.clk,
      super.reset,
      super.enable,
      Adder Function(Logic a, Logic b, {Logic? carryIn}) adderGen =
          NativeAdder.new,
      PriorityEncoder Function(Logic bitVector, {Logic? valid, String name})
          priorityGen = RecursiveModulePriorityEncoder.new,
      super.name = 'floatingpoint_adder_simple_dual'})
      : super(
            definitionName: 'FloatingPointAdderSimpleDual_'
                'E${a.exponent.width}M${a.mantissa.width}') {
    final outputSum = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth, name: 'fp');
    // addOutput('fp', width: exponentWidth + mantissaWidth + 1);
    output('sum') <= outputSum;

    // check which of a and b is larger
    final ae = a.exponent;
    final be = b.exponent;

    final bExpIsLarger = ae.lt(be).named('bExpIsLarger');
    final isInf = (a.isAnInfinity | b.isAnInfinity).named('isInf');
    final isNaN = (a.isNaN |
            b.isNaN |
            (a.isAnInfinity & b.isAnInfinity & (a.sign ^ b.sign)))
        .named('isNaN');

    final aImplicit = a.explicitJBit ? Const(0) : Const(1);
    final bImplicit = b.explicitJBit ? Const(0) : Const(1);

    final expDiff =
        mux(bExpIsLarger, b.exponent - a.exponent, a.exponent - b.exponent)
            .named('expDiff');

    final aMantissa = mux(
        a.isNormal ^ aImplicit,
        [a.mantissa, Const(0, width: mantissaWidth + 2)].swizzle(),
        mux(
            a.isNormal,
            [Const(1), a.mantissa, Const(0, width: mantissaWidth + 1)]
                .swizzle(),
            [
              a.mantissa.getRange(0, mantissaWidth - 1),
              Const(0, width: mantissaWidth + 3)
            ].swizzle()));

    final bMantissa = mux(
        b.isNormal ^ bImplicit,
        [b.mantissa, Const(0, width: mantissaWidth + 2)].swizzle(),
        mux(
            b.isNormal,
            [Const(1), b.mantissa, Const(0, width: mantissaWidth + 1)]
                .swizzle(),
            [
              b.mantissa.getRange(0, mantissaWidth - 1),
              Const(0, width: mantissaWidth + 3)
            ].swizzle()));

    final largeExpMantissa = mux(bExpIsLarger, bMantissa, aMantissa);
    final largeExpSign = mux(bExpIsLarger, b.sign, a.sign);
    final smallExpMantissa =
        mux(bExpIsLarger, aMantissa, bMantissa) >>> expDiff;
    final smallExpSign = mux(bExpIsLarger, a.sign, b.sign);

    final carryL = Logic();
    final adderL = SignMagnitudeAdder(
        largeExpSign, largeExpMantissa, smallExpSign, smallExpMantissa,
        endAroundCarry: carryL,
        largestMagnitudeFirst: true,
        adderGen: adderGen);

    final carryS = Logic();
    final adderS = SignMagnitudeAdder(
        largeExpSign, smallExpMantissa, smallExpSign, largeExpMantissa,
        endAroundCarry: carryS,
        largestMagnitudeFirst: true,
        adderGen: adderGen);
    // Tricky:  if adderS has an end-around-carry, its magnitude is off
    // by 1 (and the mantissa paired with the positive sign in this adder is
    // biggest), so the other subtractor has the correct magnitude as sum.
    final intSum = mux(adderL.endAroundCarry!, adderS.sum, adderL.sum);

    final largeIsPositive =
        (bExpIsLarger & ~b.sign) | (~bExpIsLarger & ~a.sign);
    final smallIsPositive =
        (bExpIsLarger & ~a.sign) | (~bExpIsLarger & ~b.sign);

    final largeIsTrulyLarger = (adderL.endAroundCarry! & largeIsPositive) |
        (adderS.endAroundCarry! & smallIsPositive);

    final bIsTrulyLargest = (bExpIsLarger & largeIsTrulyLarger) |
        (~bExpIsLarger & ~largeIsTrulyLarger);

    final aSignLatched = localFlop(mux(bIsTrulyLargest, b.sign, a.sign));
    final aExpLatched = localFlop(mux(bExpIsLarger, b.exponent, a.exponent));
    final sumLatched = localFlop(intSum.slice(intSum.width - 1, 0));
    final isInfLatched = localFlop(isInf);
    final isNaNLatched = localFlop(isNaN);

    final mantissa = sumLatched.reversed
        .getRange(0, min(intSum.width, intSum.width))
        .named('mantissa');
    final leadOneValid = Logic(name: 'leadOneValid');
    final leadOnePre =
        priorityGen(mantissa, valid: leadOneValid).out.named('leadOnePre');
    // Limit leadOne to exponent range and match widths
    final infExponent = outputSum.inf(sign: aSignLatched).exponent;
    final leadOne = ((leadOnePre.width > exponentWidth)
            ? mux(leadOnePre.gte(infExponent.zeroExtend(leadOnePre.width)),
                infExponent, leadOnePre.getRange(0, exponentWidth))
            : leadOnePre.zeroExtend(exponentWidth))
        .named('leadOne');

    final leadOneDominates =
        (leadOne.gt(aExpLatched) | ~leadOneValid).named('leadOneDominates');

    final normalExp = (aExpLatched - leadOne + 1).named('normalExponent');
    final outExp = mux(leadOneDominates, outputSum.zeroExponent, normalExp)
        .named('outExponent');

    final realIsInf =
        (isInfLatched | outExp.eq(infExponent)).named('realIsInf');

    final shiftMantissabyExp =
        (sumLatched << (aExpLatched + 1).named('expPlus1'))
            .named('shiftMantissaByExp', naming: Naming.mergeable)
            .getRange(intSum.width - mantissaWidth, intSum.width)
            .named('shiftMantissaByExpSliced');

    final shiftMantissabyLeadOne =
        (sumLatched << (leadOne + 1).named('leadOnePlus1'))
            .named('sumShiftLeadOnePlus1')
            .getRange(intSum.width - mantissaWidth, intSum.width)
            .named('shiftMantissaLeadPlus1Sliced', naming: Naming.mergeable);

    Combinational([
      If.block([
        Iff(isNaNLatched, [
          outputSum < outputSum.nan,
        ]),
        ElseIf(realIsInf, [
          outputSum < outputSum.inf(sign: aSignLatched),
        ]),
        ElseIf(leadOneDominates, [
          outputSum.sign < aSignLatched,
          outputSum.exponent < outputSum.zeroExponent,
          outputSum.mantissa < shiftMantissabyExp,
        ]),
        Else([
          outputSum.sign < aSignLatched,
          outputSum.exponent < normalExp,
          outputSum.mantissa < shiftMantissabyLeadOne,
        ])
      ])
    ]);
  }
}
