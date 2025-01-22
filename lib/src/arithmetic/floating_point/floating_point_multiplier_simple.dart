// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_multiplier_simple.dart
// Implementation of a non-rounding floating-point multiplier.
//
// 2024 December 30
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A multiplier module for FloatingPoint logic.
class FloatingPointMultiplierSimple extends FloatingPointMultiplier {
  /// Multiply two FloatingPoint numbers [a] and [b], returning result
  /// in [product] FloatingPoint.
  /// - [multGen] is a multiplier generator to be used in the mantissa
  /// multiplication.
  /// - [ppTree] is an parallel prefix tree generator to be used in the
  /// leading one detection ([ParallelPrefixPriorityEncoder]).
  FloatingPointMultiplierSimple(super.a, super.b,
      {super.clk,
      super.reset,
      super.enable,
      Multiplier Function(Logic a, Logic b,
              {Logic? clk, Logic? reset, Logic? enable, String name})
          multGen = NativeMultiplier.new,
      ParallelPrefix Function(
              List<Logic> inps, Logic Function(Logic term1, Logic term2) op)
          ppTree = KoggeStone.new,
      super.name}) {
    final product = FloatingPoint(
        exponentWidth: exponentWidth,
        mantissaWidth: mantissaWidth,
        name: 'product');
    output('product') <= product;

    final aMantissa = mux(a.isNormal, [a.isNormal, a.mantissa].swizzle(),
            [a.mantissa, Const(0)].swizzle())
        .named('aMantissa');
    final bMantissa = mux(b.isNormal, [b.isNormal, b.mantissa].swizzle(),
            [b.mantissa, Const(0)].swizzle())
        .named('bMantissa');

    final expAdd = (a.exponent.zeroExtend(exponentWidth + 2) +
            b.exponent.zeroExtend(exponentWidth + 2))
        .named('exponent_add');

    final productExp =
        (expAdd - a.bias.zeroExtend(exponentWidth + 2)).named('productExp');

    final mantissaMult = multGen(aMantissa, bMantissa,
        clk: clk, reset: reset, enable: enable, name: 'mantissa_mult');

    final mantissa = mantissaMult.product
        .getRange(0, (mantissaWidth + 1) * 2)
        .named('mantissa');

    final isInf = (a.isInfinity | b.isInfinity).named('isInf');
    final isNaN = (a.isNaN |
            b.isNaN |
            ((a.isInfinity | b.isInfinity) & (a.isZero | b.isZero)))
        .named('isNaN');

    final productExpLatch = localFlop(productExp);
    final aSignLatch = localFlop(a.sign);
    final bSignLatch = localFlop(b.sign);
    final isInfLatch = localFlop(isInf);
    final isNaNLatch = localFlop(isNaN);

    final leadingOnePos = ParallelPrefixPriorityEncoder(mantissa.reversed,
            ppGen: ppTree, name: 'leading_one_encoder')
        .out
        .zeroExtend(exponentWidth + 2)
        .named('leadingOne');

    final shifter = SignedShifter(
        mantissa,
        mux(productExpLatch[-1] | productExpLatch.lt(leadingOnePos),
            productExpLatch, leadingOnePos),
        name: 'mantissa_shifter');

    final remainingExp =
        (productExpLatch - leadingOnePos + 1).named('remainingExp');

    final internalOverflow = (~remainingExp[-1] &
            remainingExp.abs().gte(Const(1, width: exponentWidth, fill: true)
                .zeroExtend(exponentWidth + 2)))
        .named('internal_overflow');

    final overFlow = (isInfLatch | internalOverflow).named('overflow');

    Combinational([
      If(isNaNLatch, then: [
        product < product.nan,
      ], orElse: [
        If(overFlow, then: [
          product < product.inf(sign: aSignLatch ^ bSignLatch),
        ], orElse: [
          product.sign < aSignLatch ^ bSignLatch,
          If(remainingExp[-1], then: [
            product.exponent < Const(0, width: exponentWidth)
          ], orElse: [
            product.exponent < remainingExp.getRange(0, exponentWidth),
          ]),
          // Remove the leading one for implicit representation
          product.mantissa <
              shifter.shifted.getRange(-mantissaWidth - 1, mantissa.width - 1)
        ])
      ])
    ]);
  }
}
