// Copyright (C) 2024 Intel Corporation
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
  /// - [ppGen] is an adder generator to be used in the primary adder
  /// functions.
  FloatingPointAdderSimple(super.a, super.b,
      {super.clk,
      super.reset,
      super.enable,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic)) ppGen =
          KoggeStone.new,
      super.name = 'floatingpoint_adder_simple2'})
      : super() {
    final outputSum = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    addOutput('sum', width: outputSum.width) <= outputSum;

    // Ensure that the larger number is wired as 'a'
    final doSwap = ia.exponent.lt(ib.exponent) |
        (ia.exponent.eq(ib.exponent) & ia.mantissa.lt(ib.mantissa)) |
        ((ia.exponent.eq(ib.exponent) & ia.mantissa.eq(ib.mantissa)) & ib.sign);
    final FloatingPoint a;
    final FloatingPoint b;
    (a, b) = _swap(doSwap, (ia, ib));

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
        a.sign,
        aMantissa,
        b.sign,
        bMantissa >>> expDiff,
        (a, b, {carryIn}) =>
            ParallelPrefixAdder(a, b, carryIn: carryIn, ppGen: ppGen));

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
            ppGen: ppGen, valid: leadOneValid)
        .out;
    // Limit leadOne to exponent range and match widths
    // ROHD 0.6.0 trace error if we use this as well
    // final infExponent = outputSum.inf(inSign: aSignLatched).exponent;
    // We use hardcoding isntead
    final infExponent = Const(1, width: exponentWidth, fill: true);
    final leadOne = (leadOnePre.width > exponentWidth)
        ? mux(leadOnePre.gte(infExponent.zeroExtend(leadOnePre.width)),
            infExponent, leadOnePre.getRange(0, exponentWidth))
        : leadOnePre.zeroExtend(exponentWidth);

    final leadOneDominates = leadOne.gt(aExpLatched) | ~leadOneValid;
    final outExp =
        mux(leadOneDominates, a.zeroExponent, aExpLatched - leadOne + 1);

    // ROHD 0.6.0 trace error if we use either of the following:
    // (I think trace is not able to figure out this dependency)
    // final realIsInf = isInfLatched | outExp.eq(a.inf().exponent);
    // final realIsInf = isInfLatched | outExp.eq(outputSum.inf().exponent);
    final realIsInf = isInfLatched | outExp.eq(infExponent);

    Combinational([
      If.block([
        Iff(isNaNLatched, [
          outputSum < outputSum.nan,
        ]),
        ElseIf(realIsInf, [
          // ROHD 0.6.0 trace error if we use the following
          // outputSum < outputSum.inf(inSign: aSignLatched),
          outputSum.sign < aSignLatched,
          outputSum.exponent < infExponent,
          outputSum.mantissa < Const(0, width: mantissaWidth, fill: true),
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
