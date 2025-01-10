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
  /// Swapping two FloatingPoint structures based on a conditional
  static (FloatingPoint, FloatingPoint) _swap(
          Logic swap, (FloatingPoint, FloatingPoint) toSwap) =>
      (
        toSwap.$1.clone()..gets(mux(swap, toSwap.$2, toSwap.$1)),
        toSwap.$2.clone()..gets(mux(swap, toSwap.$1, toSwap.$2))
      );

  /// Add two floating point numbers [a] and [b], returning result in [sum].
  /// - [adderGen] is an adder generator to be used in the primary adder
  /// functions.
  /// - [ppTree] is an parallel prefix tree generator to be used in internal
  /// functions.
  FloatingPointAdderSimple(super.a, super.b,
      {super.clk,
      super.reset,
      super.enable,
      Adder Function(Logic, Logic, {Logic? carryIn}) adderGen = NativeAdder.new,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))
          ppTree = KoggeStone.new,
      super.name = 'floatingpoint_adder_simple2'})
      : super() {
    final outputSum = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    output('sum') <= outputSum;

    // Ensure that the larger number is wired as 'a'
    final ae = this.a.exponent;
    final be = this.b.exponent;
    final am = this.a.mantissa;
    final bm = this.b.mantissa;
    final doSwap = ae.lt(be) |
        (ae.eq(be) & am.lt(bm)) |
        ((ae.eq(be) & am.eq(bm)) & super.a.sign);
    final FloatingPoint a;
    final FloatingPoint b;
    (a, b) = _swap(doSwap, (super.a, super.b));

    final isInf = a.isInfinity | b.isInfinity;
    final isNaN =
        a.isNaN | b.isNaN | (a.isInfinity & b.isInfinity & (a.sign ^ b.sign));

    // Align and add mantissas
    final expDiff = a.exponent - b.exponent;
    final aMantissa = mux(
        a.isNormal,
        [Const(1), a.mantissa, Const(0, width: mantissaWidth + 1)].swizzle(),
        [a.mantissa, Const(0, width: mantissaWidth + 2)].swizzle());
    final bMantissa = mux(
        b.isNormal,
        [Const(1), b.mantissa, Const(0, width: mantissaWidth + 1)].swizzle(),
        [b.mantissa, Const(0, width: mantissaWidth + 2)].swizzle());

    final adder = SignMagnitudeAdder(
        a.sign, aMantissa, b.sign, bMantissa >>> expDiff, adderGen);

    final intSum = adder.sum.slice(adder.sum.width - 1, 0);

    final aSignLatched = condFlop(clk, a.sign, en: enable, reset: reset);
    final aExpLatched = condFlop(clk, a.exponent, en: enable, reset: reset);
    final sumLatched = condFlop(clk, intSum, en: enable, reset: reset);
    final isInfLatched = condFlop(clk, isInf, en: enable, reset: reset);
    final isNaNLatched = condFlop(clk, isNaN, en: enable, reset: reset);

    final mantissa =
        sumLatched.reversed.getRange(0, min(intSum.width, intSum.width));
    final leadOneValid = Logic();
    final leadOnePre = ParallelPrefixPriorityEncoder(mantissa,
            ppGen: ppTree, valid: leadOneValid)
        .out;
    // Limit leadOne to exponent range and match widths
    final infExponent = outputSum.inf(inSign: aSignLatched).exponent;
    final leadOne = (leadOnePre.width > exponentWidth)
        ? mux(leadOnePre.gte(infExponent.zeroExtend(leadOnePre.width)),
            infExponent, leadOnePre.getRange(0, exponentWidth))
        : leadOnePre.zeroExtend(exponentWidth);

    final leadOneDominates = leadOne.gt(aExpLatched) | ~leadOneValid;
    final outExp =
        mux(leadOneDominates, a.zeroExponent, aExpLatched - leadOne + 1);

    final realIsInf = isInfLatched | outExp.eq(infExponent);

    Combinational([
      If.block([
        Iff(isNaNLatched, [
          outputSum < outputSum.nan,
        ]),
        ElseIf(realIsInf, [
          // ROHD 0.6.0 trace error if we use the following
          outputSum < outputSum.inf(inSign: aSignLatched),
          // outputSum.sign < aSignLatched,
          // outputSum.exponent < infExponent,
          // outputSum.mantissa < Const(0, width: mantissaWidth, fill: true),
        ]),
        ElseIf(leadOneDominates, [
          outputSum.sign < aSignLatched,
          outputSum.exponent < a.zeroExponent,
          outputSum.mantissa <
              (sumLatched << aExpLatched + 1)
                  .getRange(intSum.width - mantissaWidth, intSum.width),
        ]),
        Else([
          outputSum.sign < aSignLatched,
          outputSum.exponent < aExpLatched - leadOne + 1,
          outputSum.mantissa <
              (sumLatched << leadOne + 1)
                  .getRange(intSum.width - mantissaWidth, intSum.width),
        ])
      ])
    ]);
  }
}
