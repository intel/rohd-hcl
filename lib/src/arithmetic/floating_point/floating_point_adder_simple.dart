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
  /// - [ppTree] is an parallel prefix tree generator to be used in internal
  /// functions.
  FloatingPointAdderSimple(super.a, super.b,
      {super.clk,
      super.reset,
      super.enable,
      Adder Function(Logic a, Logic b, {Logic? carryIn}) adderGen =
          NativeAdder.new,
      ParallelPrefix Function(
              List<Logic> inps, Logic Function(Logic term1, Logic term2) op)
          ppTree = KoggeStone.new,
      super.name = 'floatingpoint_adder_simple'})
      : super() {
    final outputSum = FloatingPoint(
        exponentWidth: exponentWidth,
        mantissaWidth: mantissaWidth,
        name: 'sum');
    output('sum') <= outputSum;

    final (larger, smaller) = sortFp((super.a, super.b));

    final isInf = nameLogic('isInf', larger.isInfinity | smaller.isInfinity);
    final isNaN = nameLogic(
        'isNaN',
        larger.isNaN |
            smaller.isNaN |
            (larger.isInfinity &
                smaller.isInfinity &
                (larger.sign ^ smaller.sign)));

    // Align and add mantissas
    final expDiff = larger.exponent - smaller.exponent;
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

    final intSum = nameLogic('intsum', adder.sum.slice(adder.sum.width - 1, 0));

    final aSignLatched = localFlop(larger.sign);
    final aExpLatched = localFlop(larger.exponent);
    final sumLatched = localFlop(intSum);
    final isInfLatched = localFlop(isInf);
    final isNaNLatched = localFlop(isNaN);

    final mantissa = nameLogic('mantissa',
        sumLatched.reversed.getRange(0, min(intSum.width, intSum.width)));
    final leadOneValid = Logic(name: 'leadone_valid');
    final leadOnePre = ParallelPrefixPriorityEncoder(mantissa,
            ppGen: ppTree, valid: leadOneValid)
        .out;
    // Limit leadOne to exponent range and match widths
    final infExponent = outputSum.inf(sign: aSignLatched).exponent;
    final leadOne = nameLogic(
        'leadone',
        (leadOnePre.width > exponentWidth)
            ? mux(leadOnePre.gte(infExponent.zeroExtend(leadOnePre.width)),
                infExponent, leadOnePre.getRange(0, exponentWidth))
            : leadOnePre.zeroExtend(exponentWidth));

    final leadOneDominates =
        nameLogic('leadone_dominates', leadOne.gt(aExpLatched) | ~leadOneValid);
    final outExp = nameLogic('outexponent',
        mux(leadOneDominates, larger.zeroExponent, aExpLatched - leadOne + 1));

    final realIsInf =
        nameLogic('realisinf', isInfLatched | outExp.eq(infExponent));

    final shiftMantissabyExp = nameLogic(
        'shiftmantissa_exp',
        (sumLatched << aExpLatched + 1)
            .getRange(intSum.width - mantissaWidth, intSum.width));
    final shiftMantissabyLeadOne = nameLogic(
        'shiftmantissa_leadone',
        (sumLatched << leadOne + 1)
            .getRange(intSum.width - mantissaWidth, intSum.width));

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
          outputSum.exponent < aExpLatched - leadOne + 1,
          outputSum.mantissa < shiftMantissabyLeadOne,
        ])
      ])
    ]);
  }
}
