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
      super.outProduct,
      Multiplier Function(Logic a, Logic b,
              {Logic? clk, Logic? reset, Logic? enable, String name})
          multGen = NativeMultiplier.new,
      ParallelPrefix Function(
              List<Logic> inps, Logic Function(Logic term1, Logic term2) op)
          ppTree = KoggeStone.new,
      super.name}) {
    final aMantissa = mux(a.isNormal, [a.isNormal, a.mantissa].swizzle(),
            [a.mantissa, Const(0)].swizzle())
        .named('aMantissa');
    final bMantissa = mux(b.isNormal, [b.isNormal, b.mantissa].swizzle(),
            [b.mantissa, Const(0)].swizzle())
        .named('bMantissa');

    final expCalcWidth = exponentWidth + 2;
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

    final mantissa = mantissaMult.product
        .getRange(0, (a.mantissa.width + 1) * 2)
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

    final leadingOnePosPre = ParallelPrefixPriorityEncoder(mantissa.reversed,
            ppGen: ppTree, name: 'leading_one_encoder')
        .out
        .zeroExtend(exponentWidth + 2)
        .named('leadingOne');

    final leadingOnePos = mux(
        leadingOnePosPre.gt(mantissa.width),
        Const(product.bias.value.toInt() + 1, width: leadingOnePosPre.width),
        leadingOnePosPre);

    final remainingExp =
        (productExpLatch - leadingOnePos + 1).named('remainingExp');

    final internalOverflow = (~remainingExp[-1] &
            remainingExp.abs().gte(Const(1, width: exponentWidth, fill: true)
                .zeroExtend(exponentWidth + 2)))
        .named('internal_overflow');

    final overFlow = (isInfLatch | internalOverflow).named('overflow');

    final fullMantissa = (mantissaWidth + 1 > mantissa.width)
        ? [
            mantissa,
            Const(0, width: mantissaWidth + 1 - mantissa.width, fill: true)
          ].swizzle().named('extendMantissa')
        : mantissa.named('fullMantissa');

    final fullShift = SignedShifter(
            fullMantissa,
            mux(productExpLatch[-1] | productExpLatch.lt(leadingOnePos),
                productExpLatch, leadingOnePos),
            name: 'full_mantissa_shifter')
        .shifted
        .named('shiftMantissa');
    final finalMantissa = fullShift
        .getRange(fullShift.width - mantissaWidth - 1, fullShift.width - 1)
        .named('finalMantissa');

    Combinational([
      If(isNaNLatch, then: [
        internalProduct < product.nan,
      ], orElse: [
        If(overFlow, then: [
          internalProduct < product.inf(sign: aSignLatch ^ bSignLatch),
        ], orElse: [
          internalProduct.sign < aSignLatch ^ bSignLatch,
          If(remainingExp[-1], then: [
            internalProduct.exponent < Const(0, width: exponentWidth)
          ], orElse: [
            internalProduct.exponent < remainingExp.getRange(0, exponentWidth),
          ]),
          internalProduct.mantissa < finalMantissa
        ])
      ])
    ]);
  }
}
