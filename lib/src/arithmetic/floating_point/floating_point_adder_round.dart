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
    final effectiveSubtraction = Logic(name: 'eff_subtract')
      ..gets(a.sign ^ b.sign ^ (subtract ?? Const(0)));
    final isNaN = Logic(name: 'isNaN')
      ..gets(a.isNaN |
          b.isNaN |
          (a.isInfinity & b.isInfinity & effectiveSubtraction));
    final isInf = Logic(name: 'isInf')..gets(a.isInfinity | b.isInfinity);

    final exponentSubtractor = OnesComplementAdder(
        super.a.exponent, super.b.exponent,
        subtract: true, adderGen: adderGen, name: 'exponent_sub');
    final signDelta = Logic(name: 'signDelta')..gets(exponentSubtractor.sign);

    final delta = Logic(name: 'expdelta', width: exponentSubtractor.sum.width)
      ..gets(exponentSubtractor.sum);

    // Seidel: (sl, el, fl) = larger; (ss, es, fs) = smaller
    final (larger, smaller) = swap(signDelta, (a, b));

    // return;

    final fl = Logic(name: 'full_larger', width: mantissaWidth + 1)
      ..gets(mux(
        larger.isNormal,
        [larger.isNormal, larger.mantissa].swizzle(),
        [larger.mantissa, Const(0)].swizzle(),
      ));
    final fs = Logic(name: 'full_smaller', width: mantissaWidth + 1)
      ..gets(mux(
        smaller.isNormal,
        [smaller.isNormal, smaller.mantissa].swizzle(),
        [smaller.mantissa, Const(0)].swizzle(),
      ));

    // Seidel: flp  larger preshift, normally in [2,4)
    final sigWidth = fl.width + 1;
    final largeShift = Logic(name: 'largeShift', width: sigWidth)
      ..gets(mux(effectiveSubtraction, fl.zeroExtend(sigWidth) << 1,
          fl.zeroExtend(sigWidth)));
    final smallShift = Logic(name: 'largeShift', width: sigWidth)
      ..gets(mux(effectiveSubtraction, fs.zeroExtend(sigWidth) << 1,
          fs.zeroExtend(sigWidth)));

    final zeroExp = a.zeroExponent;
    final largeOperand = largeShift;
    //
    // R Datapath:  Far exponents or addition
    //
    final extendWidthRPath =
        min(mantissaWidth + 3, pow(2, exponentWidth).toInt() - 3);

    final smallerFullRPath = Logic(
        name: 'smallerfull_rpath', width: smallShift.width + extendWidthRPath)
      ..gets([smallShift, Const(0, width: extendWidthRPath)].swizzle());

    final smallerAlignRPath =
        Logic(name: 'smaller_align_rpath', width: smallerFullRPath.width)
          ..gets(smallerFullRPath >>> exponentSubtractor.sum);
    final smallerOperandRPath =
        Logic(name: 'smaller_operand_rpath', width: largeOperand.width)
          ..gets(smallerAlignRPath.slice(smallerAlignRPath.width - 1,
              smallerAlignRPath.width - largeOperand.width));

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

    final lowBitsRPath = Logic(name: 'lowbits_rpath', width: extendWidthRPath)
      ..gets(smallerAlignRPathFlopped.slice(extendWidthRPath - 1, 0));

    final lowAdderRPathSum =
        Logic(name: 'lowadder_sum_rpath', width: extendWidthRPath + 1)
          ..gets(OnesComplementAdder(carryRPath.zeroExtend(extendWidthRPath),
                  mux(effectiveSubtractionFlopped, ~lowBitsRPath, lowBitsRPath),
                  adderGen: adderGen, name: 'rpath_lowadder')
              .sum);

    final preStickyRPath = Logic(name: 'presticky_rpath')
      ..gets(lowAdderRPathSum.slice(lowAdderRPathSum.width - 4, 0).or());
    final stickyBitRPath = Logic(name: 'stickybit_rpath')
      ..gets(lowAdderRPathSum[-3] | preStickyRPath);

    final earlyGRSRPath = Logic(name: 'earlyGRS_rpath', width: 3)
      ..gets([
        lowAdderRPathSum.slice(
            lowAdderRPathSum.width - 2, lowAdderRPathSum.width - 3),
        preStickyRPath
      ].swizzle());

    final sumRPath = Logic(name: 'sum_rpath', width: mantissaWidth + 2)
      ..gets(significandAdderRPath.sum.slice(mantissaWidth + 1, 0));
    // TODO(desmonddak): we should use a compound adder here
    final sumP1RPath = Logic(name: 'sump1_rpath', width: mantissaWidth + 2)
      ..gets((significandAdderRPath.sum + 1).slice(mantissaWidth + 1, 0));

    final sumLeadZeroRPath = Logic(name: 'sumlead0_rpath')
      ..gets(~sumRPath[-1] & (aIsNormalFlopped | bIsNormalFlopped));
    final sumP1LeadZeroRPath = Logic(name: 'sump1lead0_rpath')
      ..gets(~sumP1RPath[-1] & (aIsNormalFlopped | bIsNormalFlopped));

    final selectRPath = Logic(name: 'select_rpath')..gets(lowAdderRPathSum[-1]);
    final shiftGRSRPath = Logic(name: 'shiftGRS_rpath', width: 2)
      ..gets([earlyGRSRPath[2], stickyBitRPath].swizzle());
    final mergedSumRPath =
        Logic(name: 'mergedsum_rpath', width: sumRPath.width + 2)
          ..gets(mux(
              sumLeadZeroRPath,
              [sumRPath, earlyGRSRPath].swizzle().slice(sumRPath.width + 1, 0),
              [sumRPath, shiftGRSRPath].swizzle()));

    final mergedSumP1RPath = Logic(
        name: 'mergedsump1_rpath', width: sumRPath.width + 2)
      ..gets(mux(
          sumP1LeadZeroRPath,
          [sumP1RPath, earlyGRSRPath].swizzle().slice(sumRPath.width + 1, 0),
          [sumP1RPath, shiftGRSRPath].swizzle()));

    final finalSumLGRSRPath =
        Logic(name: 'finalsumLGRS_rpath', width: mergedSumRPath.width)
          ..gets(mux(selectRPath, mergedSumP1RPath, mergedSumRPath));
    // RNE: guard & (lsb | round | sticky)
    final rndRPath = Logic(name: 'rnd_rpath')
      ..gets(finalSumLGRSRPath[2] &
          (finalSumLGRSRPath[3] | finalSumLGRSRPath[1] | finalSumLGRSRPath[0]));

    // Rounding from 1111 to 0000.
    final incExpRPath = Logic(name: 'inc_exp_rpath')
      ..gets(
          rndRPath & sumLeadZeroRPath.eq(Const(1)) & sumP1LeadZeroRPath.eq(0));

    final firstZeroRPath = Logic(name: 'firstzero_rpath')
      ..gets(mux(selectRPath, ~sumP1RPath[-1], ~sumRPath[-1]));

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
        Logic(name: 'summantissa_rpath', width: sumRPath.width)
          ..gets(mux(selectRPath, sumP1RPath, sumRPath) +
              rndRPath.zeroExtend(sumRPath.width));
    final mantissaRPath =
        Logic(name: 'mantissa_rpath', width: sumMantissaRPath.width)
          ..gets(sumMantissaRPath <<
              mux(selectRPath, sumP1LeadZeroRPath, sumLeadZeroRPath));

    //
    //  N Datapath here:  close exponents, subtraction
    //
    final smallOperandNPath =
        Logic(name: 'smalloperand', width: smallShift.width)
          ..gets(smallShift >>> (a.exponent[0] ^ b.exponent[0]));

    final significandSubtractorNPath = OnesComplementAdder(
        largeOperand, smallOperandNPath,
        subtractIn: effectiveSubtraction,
        adderGen: adderGen,
        name: 'npath_significand_sub');

    final significandNPath = Logic(
        name: 'significand_npath', width: smallOperandNPath.width)
      ..gets(
          significandSubtractorNPath.sum.slice(smallOperandNPath.width - 1, 0));

    final validLeadOneNPath = Logic(name: 'valid_lead1_npath');
    final leadOneNPathPre = ParallelPrefixPriorityEncoder(
            significandNPath.reversed,
            ppGen: ppTree,
            valid: validLeadOneNPath,
            name: 'npath_leadingOne')
        .out;
    // Limit leadOne to exponent range and match widths
    final leadOneNPath = Logic(name: 'lead1_npath', width: exponentWidth)
      ..gets((leadOneNPathPre.width > exponentWidth)
          ? mux(
              leadOneNPathPre
                  .gte(a.inf().exponent.zeroExtend(leadOneNPathPre.width)),
              a.inf().exponent,
              leadOneNPathPre.getRange(0, exponentWidth))
          : leadOneNPathPre.zeroExtend(exponentWidth));

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

    final preExpNPath = Logic(name: 'preexp_npath', width: exponentWidth)
      ..gets(expCalcNPath.sum.slice(exponentWidth - 1, 0));

    final posExpNPath = Logic(name: 'posexp_npath')
      ..gets(preExpNPath.or() & ~expCalcNPath.sign & validLeadOneNPathFlopped);

    final exponentNPath = Logic(name: 'exp_npath', width: exponentWidth)
      ..gets(mux(posExpNPath, preExpNPath, zeroExp));

    final preMinShiftNPath = Logic(name: 'preminshift_npath')
      ..gets(~leadOneNPathFlopped.or() | ~largerExpFlopped.or());

    final minShiftNPath = Logic(
        name: 'minshift_npath', width: leadOneNPathFlopped.width)
      ..gets(mux(
          posExpNPath | preMinShiftNPath, leadOneNPathFlopped, expDecr.out));
    final notSubnormalNPath = aIsNormalFlopped | bIsNormalFlopped;

    final shiftedSignificandNPath = Logic(
        name: 'shifted_significand_npath', width: mantissaWidth)
      ..gets(
          (significandNPathFlopped << minShiftNPath).slice(mantissaWidth, 1));

    final finalSignificandNPath = Logic(
        name: 'final_significand_npath',
        width: significandNPathFlopped.width - 2)
      ..gets(mux(notSubnormalNPath, shiftedSignificandNPath,
          significandNPathFlopped.slice(significandNPathFlopped.width - 1, 2)));

    final signNPath = Logic(name: 'sign_npath')
      ..gets(mux(significandSubtractorNPathSignFlopped, smallerSignFlopped,
          largerSignFlopped));

    final isR = Logic(name: 'isR')
      ..gets(deltaFlopped.gte(Const(2, width: delta.width)) |
          ~effectiveSubtractionFlopped);

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
