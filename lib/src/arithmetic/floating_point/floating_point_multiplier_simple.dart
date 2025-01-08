// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_multiplier_simple.dart
// Implementation of non-rounding floating-point multiplier
//
// 2024 December 30
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/arithmetic/partial_product_sign_extend.dart';

/// A multiplier module for FloatingPoint logic
class FloatingPointMultiplierSimple extends FloatingPointMultiplier {
  /// Multiply two FloatingPoint numbers [a] and [b], returning result
  /// in [product] FloatingPoint.
  /// - [adderGen] is an adder generator to be used in the primary adder
  /// functions.
  /// - [ppTree] is an parallel prefix tree generator to be used in internal
  /// functions.
  FloatingPointMultiplierSimple(super.a, super.b,
      {super.clk,
      super.reset,
      super.enable,
      int radix = 4,
      Adder Function(Logic, Logic, {Logic? carryIn}) adderGen = NativeAdder.new,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))
          ppTree = KoggeStone.new,
      super.name}) {
    final product = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    addOutput('product', width: product.width) <= product;
    final a = ia;
    final b = ib;

    final aMantissa = mux(a.isNormal, [a.isNormal, a.mantissa].swizzle(),
        [a.mantissa, Const(0)].swizzle());
    final bMantissa = mux(b.isNormal, [b.isNormal, b.mantissa].swizzle(),
        [b.mantissa, Const(0)].swizzle());

    final productExp = a.exponent.zeroExtend(exponentWidth + 2) +
        b.exponent.zeroExtend(exponentWidth + 2) -
        a.bias.zeroExtend(exponentWidth + 2);

    final pp = PartialProductGeneratorCompactRectSignExtension(
        aMantissa, bMantissa, RadixEncoder(radix));
    final compressor =
        ColumnCompressor(pp, clk: clk, reset: reset, enable: enable)
          ..compress();
    final adder = adderGen(compressor.extractRow(0), compressor.extractRow(1));
    // Input mantissas have implicit lead: product mantissa width is (mw+1)*2)
    final mantissa = adder.sum.getRange(0, (mantissaWidth + 1) * 2);

    final isInf = a.isInfinity | b.isInfinity;
    final isNaN = a.isNaN |
        b.isNaN |
        ((a.isInfinity | b.isInfinity) & (a.isZero | b.isZero));

    final productExpLatch = condFlop(clk, productExp, en: enable, reset: reset);
    final aSignLatch = condFlop(clk, a.sign, en: enable, reset: reset);
    final bSignLatch = condFlop(clk, b.sign, en: enable, reset: reset);
    final isInfLatch = condFlop(clk, isInf, en: enable, reset: reset);
    final isNaNLatch = condFlop(clk, isNaN, en: enable, reset: reset);

    final leadingOnePos = ParallelPrefixPriorityEncoder(mantissa.reversed,
            ppGen: ppTree, name: 'leading_one_encoder')
        .out
        .zeroExtend(exponentWidth + 2);

    final shifter = SignedShifter(
        mantissa,
        mux(productExpLatch[-1] | productExpLatch.lt(leadingOnePos),
            productExpLatch, leadingOnePos),
        name: 'mantissa_shifter');

    final remainingExp = productExpLatch - leadingOnePos + 1;

    final overFlow = isInfLatch |
        (~remainingExp[-1] &
            remainingExp.abs().gte(Const(1, width: exponentWidth, fill: true)
                .zeroExtend(exponentWidth + 2)));

    Combinational([
      If(isNaNLatch, then: [
        product < product.nan,
      ], orElse: [
        If(overFlow, then: [
          // product < product.inf(inSign: aSignLatch ^ bSignLatch),
          product.sign < aSignLatch ^ bSignLatch,
          product.exponent < product.nan.exponent,
          product.mantissa < Const(0, width: mantissaWidth, fill: true),
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
