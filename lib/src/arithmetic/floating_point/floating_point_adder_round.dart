// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_adder_round.dart
// A variable-width floating point adder with rounding
//
// 2024 August 30
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An adder module for variable FloatingPoint type with rounding.
// This is a Seidel/Even adder, dual-path implementation.
class FloatingPointAdderRound extends FloatingPointAdder {
  /// Add two floating point numbers [a] and [b], returning result in [sum].
  /// [subtract] is an optional Logic input to do subtraction
  /// [adderGen] is an adder generator to be used in the primary adder
  /// functions.
  /// [ppTree] is an ParallelPrefix generator for use in increment /decrement
  ///  functions.
  FloatingPointAdderRound(super.a, super.b,
      {Logic? subtract,
      super.clk,
      super.reset,
      super.enable,
      Adder Function(Logic a, Logic b, {Logic? carryIn}) adderGen =
          NativeAdder.new,
      ParallelPrefix Function(
              List<Logic> inps, Logic Function(Logic term1, Logic term2) op)
          ppTree = KoggeStone.new,
      super.name = 'floating_point_adder_round'}) {
    final outputSum = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    output('sum') <= outputSum;

    // Seidel: S.EFF = effectiveSubtraction
    final effectiveSubtraction =
        (a.sign ^ b.sign ^ (subtract ?? Const(0))).named('effSubtraction');
    final isNaN = (a.isNaN |
            b.isNaN |
            (a.isInfinity & b.isInfinity & effectiveSubtraction))
        .named('isNaN');
    final isInf = (a.isInfinity | b.isInfinity).named('isInf');

    final exponentSubtractor = OnesComplementAdder(
        super.a.exponent, super.b.exponent,
        subtract: true, adderGen: adderGen, name: 'exponent_sub');
    final signDelta = exponentSubtractor.sign.named('signDelta');

    final delta = exponentSubtractor.sum.named('expDelta');

    // Seidel: (sl, el, fl) = larger; (ss, es, fs) = smaller
    final (larger, smaller) = swap(signDelta, (a, b));

    final fl = mux(
      larger.isNormal,
      [larger.isNormal, larger.mantissa].swizzle(),
      [larger.mantissa, Const(0)].swizzle(),
    ).named('fullLarger');
    final fs = mux(
      smaller.isNormal,
      [smaller.isNormal, smaller.mantissa].swizzle(),
      [smaller.mantissa, Const(0)].swizzle(),
    ).named('fullSmaller');

    // Seidel: flp  larger preshift, normally in [2,4)
    final sigWidth = fl.width + 1;
    final largeShift = mux(effectiveSubtraction, fl.zeroExtend(sigWidth) << 1,
            fl.zeroExtend(sigWidth))
        .named('largeShift');
    final smallShift = mux(effectiveSubtraction, fs.zeroExtend(sigWidth) << 1,
            fs.zeroExtend(sigWidth))
        .named('smallShift');

    final zeroExp = a.zeroExponent;
    final largeOperand = largeShift;
    //
    // R Datapath:  Far exponents or addition
    //
    final extendWidthRPath =
        min(mantissaWidth + 3, pow(2, exponentWidth).toInt() - 3);

    final smallerFullRPath = [smallShift, Const(0, width: extendWidthRPath)]
        .swizzle()
        .named('smallerFull_rpath');

    final smallerAlignRPath = (smallerFullRPath >>> exponentSubtractor.sum)
        .named('smallerAligned_rpath');
    final smallerOperandRPath = smallerAlignRPath
        .slice(smallerAlignRPath.width - 1,
            smallerAlignRPath.width - largeOperand.width)
        .named('smallerOperand_rpath');

    /// R Pipestage here:
    final aIsNormalFlopped = localFlop(a.isNormal);
    final bIsNormalFlopped = localFlop(b.isNormal);
    final effectiveSubtractionFlopped = localFlop(effectiveSubtraction);
    final largeOperandFlopped = localFlop(largeOperand);
    final smallerOperandRPathFlopped = localFlop(smallerOperandRPath);
    final smallerAlignRPathFlopped = localFlop(smallerAlignRPath);
    final largerExpFlopped = localFlop(larger.exponent);
    final deltaFlopped = localFlop(delta);
    final isInfFlopped = localFlop(isInf);
    final isNaNFlopped = localFlop(isNaN);

    final carryRPath = Logic(name: 'carry_rpath');
    final significandAdderRPath = OnesComplementAdder(
        largeOperandFlopped, smallerOperandRPathFlopped,
        subtractIn: effectiveSubtractionFlopped,
        carryOut: carryRPath,
        adderGen: adderGen,
        name: 'rpath_significand_adder');

    final lowBitsRPath = smallerAlignRPathFlopped
        .slice(extendWidthRPath - 1, 0)
        .named('lowbits_rpath');

    final lowAdderRPathSum = OnesComplementAdder(
            carryRPath.zeroExtend(extendWidthRPath),
            mux(effectiveSubtractionFlopped, ~lowBitsRPath, lowBitsRPath),
            adderGen: adderGen,
            name: 'rpath_lowadder')
        .sum
        .named('lowAdderSum_rpath');

    final preStickyRPath = lowAdderRPathSum
        .slice(lowAdderRPathSum.width - 4, 0)
        .or()
        .named('preSticky_rpath');
    final stickyBitRPath =
        (lowAdderRPathSum[-3] | preStickyRPath).named('stickyBit_rpath');

    final earlyGRSRPath = [
      lowAdderRPathSum.slice(
          lowAdderRPathSum.width - 2, lowAdderRPathSum.width - 3),
      preStickyRPath
    ].swizzle().named('earlyGRS_rpath');

    final sumRPath = significandAdderRPath.sum
        .slice(mantissaWidth + 1, 0)
        .named('sum_rpath');
    // TODO(desmonddak): we should use a compound adder here
    final sumP1RPath = (significandAdderRPath.sum + 1)
        .named('sumPlusOne_rpath')
        .slice(mantissaWidth + 1, 0);

    final sumLeadZeroRPath =
        (~sumRPath[-1] & (aIsNormalFlopped | bIsNormalFlopped))
            .named('sumlead0_rpath');
    final sumP1LeadZeroRPath =
        (~sumP1RPath[-1] & (aIsNormalFlopped | bIsNormalFlopped))
            .named('sumP1lead0_rpath');

    final selectRPath = lowAdderRPathSum[-1].named('selectRpath');
    final shiftGRSRPath =
        [earlyGRSRPath[2], stickyBitRPath].swizzle().named('shiftGRS_rpath');
    final mergedSumRPath = mux(
            sumLeadZeroRPath,
            [sumRPath, earlyGRSRPath]
                .swizzle()
                .named('sum_earlyGRS_rpath')
                .slice(sumRPath.width + 1, 0),
            [sumRPath, shiftGRSRPath].swizzle())
        .named('mergedSum_rpath');

    final mergedSumP1RPath = mux(
            sumP1LeadZeroRPath,
            [sumP1RPath, earlyGRSRPath]
                .swizzle()
                .named('sump1_earlyGRS')
                .slice(sumRPath.width + 1, 0),
            [sumP1RPath, shiftGRSRPath].swizzle())
        .named('mergedSumP1');

    final finalSumLGRSRPath = mux(selectRPath, mergedSumP1RPath, mergedSumRPath)
        .named('finalSumLGRS_rpath');
    // RNE: guard & (lsb | round | sticky)
    final rndRPath = (finalSumLGRSRPath[2] &
            (finalSumLGRSRPath[3] |
                finalSumLGRSRPath[1] |
                finalSumLGRSRPath[0]))
        .named('rnd_rpath');

    // Rounding from 1111 to 0000.
    final incExpRPath =
        (rndRPath & sumLeadZeroRPath.eq(Const(1)) & sumP1LeadZeroRPath.eq(0))
            .named('inc_exp_rpath');

    final firstZeroRPath = mux(selectRPath, ~sumP1RPath[-1], ~sumRPath[-1])
        .named('firstZero_rpath');

    final expDecr = ParallelPrefixDecr(largerExpFlopped,
        ppGen: ppTree, name: 'exp_decrement');
    final expIncr = ParallelPrefixIncr(largerExpFlopped,
        ppGen: ppTree, name: 'exp_increment');
    final exponentRPath = Logic(width: exponentWidth);
    Combinational([
      If.block([
        // Subtract 1 from exponent
        Iff(~incExpRPath & effectiveSubtractionFlopped & firstZeroRPath,
            [exponentRPath < expDecr.out]),
        // Add 1 to exponent
        ElseIf(
            ~effectiveSubtractionFlopped &
                (incExpRPath & firstZeroRPath | ~incExpRPath & ~firstZeroRPath),
            [exponentRPath < expIncr.out]),
        // Add 2 to exponent
        ElseIf(incExpRPath & effectiveSubtractionFlopped & ~firstZeroRPath,
            [exponentRPath < largerExpFlopped << 1]),
        Else([exponentRPath < largerExpFlopped])
      ])
    ]);

    final sumMantissaRPath =
        mux(selectRPath, sumP1RPath, sumRPath).named('selectSumMantissa_rpath');
    // TODO(desmonddak):  the '+' operator fails to pick up names directly
    final sumMantissaRPathRnd = (sumMantissaRPath +
            rndRPath.zeroExtend(sumRPath.width).named('rndExtend_rpath'))
        .named('sumMantissaRnd_rpath');
    final mantissaRPath = (sumMantissaRPathRnd <<
            mux(selectRPath, sumP1LeadZeroRPath, sumLeadZeroRPath))
        .named('mantissa_rpath');

    //
    //  N Datapath here:  close exponents, subtraction
    //
    final smallOperandNPath =
        (smallShift >>> (a.exponent[0] ^ b.exponent[0])).named('smallOperand');

    final significandSubtractorNPath = OnesComplementAdder(
        largeOperand, smallOperandNPath,
        subtractIn: effectiveSubtraction,
        adderGen: adderGen,
        name: 'npath_significand_sub');

    final significandNPath = significandSubtractorNPath.sum
        .slice(smallOperandNPath.width - 1, 0)
        .named('significand_npath');

    final validLeadOneNPath = Logic(name: 'valid_lead1_npath');
    final leadOneNPathPre = ParallelPrefixPriorityEncoder(
            significandNPath.reversed,
            ppGen: ppTree,
            valid: validLeadOneNPath,
            name: 'npath_leadingOne')
        .out;
    // Limit leadOne to exponent range and match widths
    final leadOneNPath = ((leadOneNPathPre.width > exponentWidth)
            ? mux(
                leadOneNPathPre
                    .gte(a.inf().exponent.zeroExtend(leadOneNPathPre.width)),
                a.inf().exponent,
                leadOneNPathPre.getRange(0, exponentWidth))
            : leadOneNPathPre.zeroExtend(exponentWidth))
        .named('leadOne_npath');

    // N pipestage here:
    final significandNPathFlopped = localFlop(significandNPath);
    final significandSubtractorNPathSignFlopped =
        localFlop(significandSubtractorNPath.sign);
    final leadOneNPathFlopped = localFlop(leadOneNPath);
    final validLeadOneNPathFlopped = localFlop(validLeadOneNPath);
    final largerSignFlopped = localFlop(larger.sign);
    final smallerSignFlopped = localFlop(smaller.sign);

    final expCalcNPath = OnesComplementAdder(
        largerExpFlopped, leadOneNPathFlopped.zeroExtend(exponentWidth),
        subtractIn: effectiveSubtractionFlopped,
        adderGen: adderGen,
        name: 'npath_expcalc');

    final preExpNPath =
        expCalcNPath.sum.slice(exponentWidth - 1, 0).named('preExp_npath');

    final posExpNPath =
        (preExpNPath.or() & ~expCalcNPath.sign & validLeadOneNPathFlopped)
            .named('posexp_npath');

    final exponentNPath =
        mux(posExpNPath, preExpNPath, zeroExp).named('exponent_npath');

    final preMinShiftNPath =
        (~leadOneNPathFlopped.or() | ~largerExpFlopped.or())
            .named('preminshift_npath');

    final minShiftNPath =
        mux(posExpNPath | preMinShiftNPath, leadOneNPathFlopped, expDecr.out)
            .named('minShift_npath');
    final notSubnormalNPath = aIsNormalFlopped | bIsNormalFlopped;

    final shiftedSignificandNPath = (significandNPathFlopped << minShiftNPath)
        .named('shiftedSignificand_npath')
        .slice(mantissaWidth, 1);

    final finalSignificandNPath = mux(
            notSubnormalNPath,
            shiftedSignificandNPath,
            significandNPathFlopped.slice(significandNPathFlopped.width - 1, 2))
        .named('finalSignificand_npath');

    final signNPath = mux(significandSubtractorNPathSignFlopped,
            smallerSignFlopped, largerSignFlopped)
        .named('sign_npath');

    final isR = (deltaFlopped.gte(Const(2, width: delta.width)) |
            ~effectiveSubtractionFlopped)
        .named('isR');

    Combinational([
      If(isNaNFlopped, then: [
        outputSum < outputSum.nan,
      ], orElse: [
        If(isInfFlopped, then: [
          outputSum < outputSum.inf(sign: largerSignFlopped),
        ], orElse: [
          If(isR, then: [
            outputSum.sign < largerSignFlopped,
            outputSum.exponent < exponentRPath,
            outputSum.mantissa <
                mantissaRPath.slice(mantissaRPath.width - 2, 1),
          ], orElse: [
            outputSum.sign < signNPath,
            outputSum.exponent < exponentNPath,
            outputSum.mantissa < finalSignificandNPath,
          ])
        ])
      ])
    ]);
  }
}
