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
import 'package:rohd_hcl/src/arithmetic/partial_product_sign_extend.dart';

/// A multiplier module for FloatingPoint logic.
class FloatingPointMultiplierSimple extends FloatingPointMultiplier {
  /// Multiply two FloatingPoint numbers [a] and [b], returning result
  /// in [product] FloatingPoint.
  /// - [radix] is the Booth encoder radix used with options [2,4,8,16]
  /// ((default=4).
  /// - [adderGen] is an adder generator to be used in the primary adder
  /// functions.
  /// - [ppTree] is an parallel prefix tree generator to be used in internal
  /// functions.
  FloatingPointMultiplierSimple(super.a, super.b,
      {super.clk,
      super.reset,
      super.enable,
      int radix = 4,
      Adder Function(Logic a, Logic b, {Logic? carryIn}) adderGen =
          NativeAdder.new,
      ParallelPrefix Function(
              List<Logic> inps, Logic Function(Logic term1, Logic term2) op)
          ppTree = KoggeStone.new,
      super.name}) {
    final product = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    output('product') <= product;
    final a = this.a;
    final b = this.b;

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

    final productExpLatch = localFlop(productExp);
    final aSignLatch = localFlop(a.sign);
    final bSignLatch = localFlop(b.sign);
    final isInfLatch = localFlop(isInf);
    final isNaNLatch = localFlop(isNaN);

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
          // TODO(desmonddak): use this line after trace issue is resolved
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
