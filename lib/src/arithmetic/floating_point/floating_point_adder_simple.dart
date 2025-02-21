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
class FloatingPointAdderSimple extends FloatingPointAdder {
  /// Add two floating point numbers [a] and [b], returning result in [sum].
  /// - [adderGen] is an adder generator to be used in the primary adder
  /// functions.
  /// - [priorityGen] is a [PriorityEncoder] generator to be used in the
  /// leading one detection (default [RecursiveModulePriorityEncoder]).
  FloatingPointAdderSimple(super.a, super.b,
      {super.clk,
      super.reset,
      super.enable,
      Adder Function(Logic a, Logic b, {Logic? carryIn}) adderGen =
          NativeAdder.new,
      PriorityEncoder Function(Logic bitVector, {Logic? valid, String name})
          priorityGen = RecursiveModulePriorityEncoder.new,
      super.name = 'floatingpoint_adder_simple'})
      : super(
            definitionName: 'FloatingPointAdderSimple_'
                'E${a.exponent.width}M${a.mantissa.width}') {
    final outputSum = FloatingPoint(
        exponentWidth: exponentWidth,
        mantissaWidth: mantissaWidth,
        name: 'sum');
    output('sum') <= outputSum;

    final (larger, smaller) = sortFp((super.a, super.b));

    final isInf = (larger.isAnInfinity | smaller.isAnInfinity).named('isInf');
    final isNaN = (larger.isNaN |
            smaller.isNaN |
            (larger.isAnInfinity &
                smaller.isAnInfinity &
                (larger.sign ^ smaller.sign)))
        .named('isNaN');

    // Align and add mantissas
    final expDiff = (larger.exponent - smaller.exponent).named('expDiff');
    final aMantissa = mux(
        larger.isNormal,
        [Const(1), larger.mantissa, Const(0, width: mantissaWidth + 1)]
            .swizzle(),
        [larger.mantissa, Const(0, width: mantissaWidth + 2)].swizzle());
    final bMantissa = mux(
        smaller.isNormal,
        [Const(1), smaller.mantissa, Const(0, width: mantissaWidth + 1)]
            .swizzle(),
        [smaller.mantissa, Const(0, width: mantissaWidth + 2)].swizzle());

    final adder = SignMagnitudeAdder(
        larger.sign, aMantissa, smaller.sign, bMantissa >>> expDiff, adderGen);

    final intSum = adder.sum.slice(adder.sum.width - 1, 0).named('intSum');

    final aSignLatched = localFlop(larger.sign);
    final aExpLatched = localFlop(larger.exponent);
    final sumLatched = localFlop(intSum);
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
    final outExp = mux(leadOneDominates, larger.zeroExponent, normalExp)
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
          outputSum.exponent < larger.zeroExponent,
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
