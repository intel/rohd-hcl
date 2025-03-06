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
        exponentWidth: exponentWidth,
        mantissaWidth: mantissaWidth,
        name: 'sum');
    output('sum') <= outputSum;

    // check which of a and b is larger
    final ae = a.exponent;
    final be = b.exponent;
    final am = a.mantissa;
    final bm = b.mantissa;
    final bIsLarger = (ae.lt(be) |
            (ae.eq(be) & am.lt(bm)) |
            ((ae.eq(be) & am.eq(bm)) & a.sign))
        .named('bIsLarger');

    final isInf = (a.isAnInfinity | b.isAnInfinity).named('isInf');
    final isNaN = (a.isNaN |
            b.isNaN |
            (a.isAnInfinity & b.isAnInfinity & (a.sign ^ b.sign)))
        .named('isNaN');

    final aImplicit = a.implicitJBit ? Const(1) : Const(0);
    final bImplicit = b.implicitJBit ? Const(1) : Const(0);

    // compute both differences of exponents in parallel
    final expDiff1 = (a.exponent - b.exponent).named('expDiff1');
    final expDiff2 = (b.exponent - a.exponent).named('expDiff2');

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

    // perform 2 parallel mantissa additions
    final adder1 = SignMagnitudeAdder(
        a.sign, aMantissa, b.sign, bMantissa >>> expDiff1,
        largestMagnitudeFirst: true, adderGen: adderGen);
    final adder2 = SignMagnitudeAdder(
        b.sign, bMantissa, a.sign, aMantissa >>> expDiff2,
        largestMagnitudeFirst: true, adderGen: adderGen);

    final intSum1 = adder1.sum.slice(adder1.sum.width - 1, 0).named('intSum1');
    final intSum2 = adder2.sum.slice(adder2.sum.width - 1, 0).named('intSum2');

    final aSignLatched = localFlop(mux(bIsLarger, b.sign, a.sign));
    final aExpLatched = localFlop(mux(bIsLarger, b.exponent, a.exponent));
    final sumLatched = localFlop(mux(bIsLarger, intSum2, intSum1));
    final isInfLatched = localFlop(isInf);
    final isNaNLatched = localFlop(isNaN);

    final mantissa = sumLatched.reversed
        .getRange(0, min(intSum1.width, intSum1.width))
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
            .getRange(intSum1.width - mantissaWidth, intSum1.width)
            .named('shiftMantissaByExpSliced');

    final shiftMantissabyLeadOne =
        (sumLatched << (leadOne + 1).named('leadOnePlus1'))
            .named('sumShiftLeadOnePlus1')
            .getRange(intSum1.width - mantissaWidth, intSum1.width)
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
