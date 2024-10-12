// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_adder.dart
// A variable-width floating point adder with rounding
//
// 2024 August 30
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An adder module for variable FloatingPoint type with rounding.
// This is the Seidel/Even adder, dual-path
class FloatingPointAdder extends Module {
  /// Must be greater than 0.
  final int exponentWidth;

  /// Must be greater than 0.
  final int mantissaWidth;

  /// Output [FloatingPoint] computed
  late final FloatingPoint sum =
      FloatingPoint(exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        ..gets(output('sum'));

  /// The result of [FloatingPoint] addition
  @protected
  late final FloatingPoint _sum =
      FloatingPoint(exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// Swapping two FloatingPoint structures based on a conditional
  static (FloatingPoint, FloatingPoint) _swap(
          Logic swap, (FloatingPoint, FloatingPoint) toSwap) =>
      (
        toSwap.$1.clone()..gets(mux(swap, toSwap.$2, toSwap.$1)),
        toSwap.$2.clone()..gets(mux(swap, toSwap.$1, toSwap.$2))
      );

  /// Add two floating point numbers [a] and [b], returning result in [sum].
  /// [subtract] is an optional Logic input to do subtraction
  /// [adderGen] is an adder generator to be used in the primary adder
  /// functions.
  /// [ppTree] is an ParallelPrefix generator for use in increment /decrement
  ///  functions.
  FloatingPointAdder(FloatingPoint a, FloatingPoint b,
      {Logic? subtract,
      Adder Function(Logic, Logic) adderGen = ParallelPrefixAdder.new,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))
          ppTree = KoggeStone.new,
      super.name = 'floating_point_adder'})
      : exponentWidth = a.exponent.width,
        mantissaWidth = a.mantissa.width {
    if (b.exponent.width != exponentWidth ||
        b.mantissa.width != mantissaWidth) {
      throw RohdHclException('FloatingPoint widths must match');
    }
    a = a.clone()..gets(addInput('a', a, width: a.width));
    b = b.clone()..gets(addInput('b', b, width: b.width));
    addOutput('sum', width: _sum.width) <= _sum;

    final exponentSubtractor = OnesComplementAdder(a.exponent, b.exponent,
        subtract: true, adderGen: adderGen);
    final signDelta = exponentSubtractor.sign;

    final delta = exponentSubtractor.sum;

    // Seidel: (sl, el, fl) = larger; (ss, es, fs) = smaller
    final (larger, smaller) = _swap(signDelta, (a, b));

    final fl = mux(
        larger.isNormal(),
        [larger.isNormal(), larger.mantissa].swizzle(),
        [larger.mantissa, Const(0)].swizzle());
    final fs = mux(
        smaller.isNormal(),
        [smaller.isNormal(), smaller.mantissa].swizzle(),
        [smaller.mantissa, Const(0)].swizzle());

    // Seidel: S.EFF = effectiveSubtraction
    final effectiveSubtraction = a.sign ^ b.sign ^ (subtract ?? Const(0));

    // Seidel: flp  larger preshift, normally in [2,4)
    final sigWidth = fl.width + 1;
    final largeShift = mux(effectiveSubtraction, fl.zeroExtend(sigWidth) << 1,
        fl.zeroExtend(sigWidth));
    final smallShift = mux(effectiveSubtraction, fs.zeroExtend(sigWidth) << 1,
        fs.zeroExtend(sigWidth));

    final zeroExp = Const(0, width: exponentWidth);

    final largeOperand = largeShift;
    //
    // R Datapath:  Far exponents or addition
    //
    final extendWidthRPath =
        min(mantissaWidth + 3, pow(2, exponentWidth).toInt() - 3);

    final smallerFullRPath =
        [smallShift, Const(0, width: extendWidthRPath)].swizzle();
    smallerFullRPath <= smallerFullRPath.withSet(extendWidthRPath, smallShift);

    final smallerAlignRPath = smallerFullRPath >>> exponentSubtractor.sum;
    final smallerOperandRPath = smallerAlignRPath.slice(
        smallerAlignRPath.width - 1,
        smallerAlignRPath.width - largeOperand.width);

    final carryRPath = Logic();
    final significandAdderRPath = OnesComplementAdder(
        largeOperand, smallerOperandRPath,
        subtractIn: effectiveSubtraction,
        carryOut: carryRPath,
        adderGen: adderGen);

    final lowBitsRPath = smallerAlignRPath.slice(extendWidthRPath - 1, 0);
    final lowAdderRPath = OnesComplementAdder(
        carryRPath.zeroExtend(extendWidthRPath),
        mux(effectiveSubtraction, ~lowBitsRPath, lowBitsRPath),
        adderGen: adderGen);

    final preStickyRPath =
        lowAdderRPath.sum.slice(lowAdderRPath.sum.width - 4, 0).or();
    final stickyBitRPath = lowAdderRPath.sum[-3] | preStickyRPath;

    final earlyGRSRPath = [
      lowAdderRPath.sum
          .slice(lowAdderRPath.sum.width - 2, lowAdderRPath.sum.width - 3),
      preStickyRPath
    ].swizzle();

    final sumRPath = significandAdderRPath.sum.slice(mantissaWidth + 1, 0);
    final sumP1RPath =
        (significandAdderRPath.sum + 1).slice(mantissaWidth + 1, 0);

    final sumLeadZeroRPath = ~sumRPath[-1] & (a.isNormal() | b.isNormal());
    final sumP1LeadZeroRPath = ~sumP1RPath[-1] & (a.isNormal() | b.isNormal());

    final selectRPath = lowAdderRPath.sum[-1];
    final shiftGRSRPath = [earlyGRSRPath[2], stickyBitRPath].swizzle();
    final mergedSumRPath = mux(
        sumLeadZeroRPath,
        [sumRPath, earlyGRSRPath].swizzle().slice(sumRPath.width + 1, 0),
        [sumRPath, shiftGRSRPath].swizzle());

    final mergedSumP1RPath = mux(
        sumP1LeadZeroRPath,
        [sumP1RPath, earlyGRSRPath].swizzle().slice(sumRPath.width + 1, 0),
        [sumP1RPath, shiftGRSRPath].swizzle());

    final finalSumLGRSRPath =
        mux(selectRPath, mergedSumP1RPath, mergedSumRPath);
    // RNE: guard & (lsb | round | sticky)
    final rndRPath = finalSumLGRSRPath[2] &
        (finalSumLGRSRPath[3] | finalSumLGRSRPath[1] | finalSumLGRSRPath[0]);

    // Rounding from 1111 to 0000.
    final incExpRPath =
        rndRPath & sumLeadZeroRPath.eq(Const(1)) & sumP1LeadZeroRPath.eq(0);

    final firstZeroRPath = mux(selectRPath, ~sumP1RPath[-1], ~sumRPath[-1]);

    final exponentRPath = Logic(width: larger.exponent.width);
    Combinational([
      If.block([
        // Subtract 1 from exponent
        Iff(~incExpRPath & effectiveSubtraction & firstZeroRPath, [
          exponentRPath < ParallelPrefixDecr(larger.exponent, ppGen: ppTree).out
        ]),
        // Add 1 to exponent
        ElseIf(
            ~effectiveSubtraction &
                (incExpRPath & firstZeroRPath | ~incExpRPath & ~firstZeroRPath),
            [
              exponentRPath <
                  ParallelPrefixIncr(larger.exponent, ppGen: ppTree).out
            ]),
        // Add 2 to exponent
        ElseIf(incExpRPath & effectiveSubtraction & ~firstZeroRPath,
            [exponentRPath < larger.exponent << 1]),
        Else([exponentRPath < larger.exponent])
      ])
    ]);

    final sumMantissaRPath = mux(selectRPath, sumP1RPath, sumRPath) +
        rndRPath.zeroExtend(sumRPath.width);
    final mantissaRPath = sumMantissaRPath <<
        mux(selectRPath, sumP1LeadZeroRPath, sumLeadZeroRPath);

    //
    //  N Datapath here:  close exponents, subtraction
    //
    final smallOperandNPath = smallShift >>> (a.exponent[0] ^ b.exponent[0]);

    final significandSubtractorNPath = OnesComplementAdder(
        largeOperand, smallOperandNPath,
        subtractIn: effectiveSubtraction, adderGen: adderGen);

    final significandNPath =
        significandSubtractorNPath.sum.slice(smallOperandNPath.width - 1, 0);

    final leadOneNPath = mux(
        significandNPath.or(),
        ParallelPrefixPriorityEncoder(significandNPath.reversed, ppGen: ppTree)
            .out
            .zeroExtend(exponentWidth),
        Const(15, width: exponentWidth));

    final expCalcNPath = OnesComplementAdder(
        larger.exponent, leadOneNPath.zeroExtend(larger.exponent.width),
        subtractIn: effectiveSubtraction, adderGen: adderGen);

    final preExpNPath = expCalcNPath.sum.slice(exponentWidth - 1, 0);

    final posExpNPath = preExpNPath.or() & ~expCalcNPath.sign;

    final exponentNPath = mux(posExpNPath, preExpNPath, zeroExp);

    final preMinShiftNPath = ~leadOneNPath.or() | ~larger.exponent.or();

    final minShiftNPath =
        mux(posExpNPath | preMinShiftNPath, leadOneNPath, larger.exponent - 1);
    final notSubnormalNPath = a.isNormal() | b.isNormal();

    final shiftedSignificandNPath =
        (significandNPath << minShiftNPath).slice(mantissaWidth, 1);

    final finalSignificandNPath = mux(
        notSubnormalNPath,
        shiftedSignificandNPath,
        significandNPath.slice(significandNPath.width - 1, 2));

    final signNPath =
        mux(significandSubtractorNPath.sign, smaller.sign, larger.sign);

    final isR = delta.gte(Const(2, width: delta.width)) | ~effectiveSubtraction;
    _sum <=
        mux(
            isR,
            [
              larger.sign,
              exponentRPath,
              mantissaRPath.slice(mantissaRPath.width - 2, 1)
            ].swizzle(),
            [signNPath, exponentNPath, finalSignificandNPath].swizzle());
  }
}
