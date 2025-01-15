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

    final fl = nameLogic(
        'full_larger',
        mux(
          larger.isNormal,
          [larger.isNormal, larger.mantissa].swizzle(),
          [larger.mantissa, Const(0)].swizzle(),
        ));
    final fs = nameLogic(
        'full_smaller',
        mux(
          smaller.isNormal,
          [smaller.isNormal, smaller.mantissa].swizzle(),
          [smaller.mantissa, Const(0)].swizzle(),
        ));

    // Seidel: flp  larger preshift, normally in [2,4)
    final sigWidth = fl.width + 1;
    final largeShift = nameLogic(
        'largeShift',
        mux(effectiveSubtraction, fl.zeroExtend(sigWidth) << 1,
            fl.zeroExtend(sigWidth)));
    final smallShift = nameLogic(
        'largeShift',
        mux(effectiveSubtraction, fs.zeroExtend(sigWidth) << 1,
            fs.zeroExtend(sigWidth)));

    final zeroExp = a.zeroExponent;
    final largeOperand = largeShift;
    //
    // R Datapath:  Far exponents or addition
    //
    final extendWidthRPath =
        min(mantissaWidth + 3, pow(2, exponentWidth).toInt() - 3);

    final smallerFullRPath = nameLogic('smallerfull_rpath',
        [smallShift, Const(0, width: extendWidthRPath)].swizzle());

    final smallerAlignRPath = nameLogic(
        'smaller_align_rpath', smallerFullRPath >>> exponentSubtractor.sum);
    final smallerOperandRPath = nameLogic(
        'smaller_operand_rpath',
        smallerAlignRPath.slice(smallerAlignRPath.width - 1,
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

    final lowBitsRPath = nameLogic('lowbits_rpath',
        smallerAlignRPathFlopped.slice(extendWidthRPath - 1, 0));

    final lowAdderRPathSum = nameLogic(
        'lowadder_sum_rpath',
        OnesComplementAdder(carryRPath.zeroExtend(extendWidthRPath),
                mux(effectiveSubtractionFlopped, ~lowBitsRPath, lowBitsRPath),
                adderGen: adderGen, name: 'rpath_lowadder')
            .sum);

    final preStickyRPath = nameLogic('presticky_rpath',
        lowAdderRPathSum.slice(lowAdderRPathSum.width - 4, 0).or());
    final stickyBitRPath =
        nameLogic('stickybit_rpath', lowAdderRPathSum[-3] | preStickyRPath);

    final earlyGRSRPath = nameLogic(
        'earlyGRS_rpath',
        [
          lowAdderRPathSum.slice(
              lowAdderRPathSum.width - 2, lowAdderRPathSum.width - 3),
          preStickyRPath
        ].swizzle());

    final sumRPath = nameLogic(
        'sum_rpath', significandAdderRPath.sum.slice(mantissaWidth + 1, 0));
    // TODO(desmonddak): we should use a compound adder here
    final sumP1RPath = nameLogic('sump1_rpath',
        (significandAdderRPath.sum + 1).slice(mantissaWidth + 1, 0));

    final sumLeadZeroRPath = nameLogic('sumlead0_rpath',
        ~sumRPath[-1] & (aIsNormalFlopped | bIsNormalFlopped));
    final sumP1LeadZeroRPath = nameLogic('sump1lead0_rpath',
        ~sumP1RPath[-1] & (aIsNormalFlopped | bIsNormalFlopped));

    final selectRPath = nameLogic('select_rpath', lowAdderRPathSum[-1]);
    final shiftGRSRPath = nameLogic(
        'shiftGRS_rpath', [earlyGRSRPath[2], stickyBitRPath].swizzle());
    final mergedSumRPath = nameLogic(
        'mergedsum_rpath',
        mux(
            sumLeadZeroRPath,
            [sumRPath, earlyGRSRPath].swizzle().slice(sumRPath.width + 1, 0),
            [sumRPath, shiftGRSRPath].swizzle()));

    final mergedSumP1RPath = nameLogic(
        'mergedsump1_rpath',
        mux(
            sumP1LeadZeroRPath,
            [sumP1RPath, earlyGRSRPath].swizzle().slice(sumRPath.width + 1, 0),
            [sumP1RPath, shiftGRSRPath].swizzle()));

    final finalSumLGRSRPath = nameLogic('finalsumLGRS_rpath',
        mux(selectRPath, mergedSumP1RPath, mergedSumRPath));
    // RNE: guard & (lsb | round | sticky)
    final rndRPath = nameLogic(
        'rnd_rpath',
        finalSumLGRSRPath[2] &
            (finalSumLGRSRPath[3] |
                finalSumLGRSRPath[1] |
                finalSumLGRSRPath[0]));

    // Rounding from 1111 to 0000.
    final incExpRPath = nameLogic('inc_exp_rpath',
        rndRPath & sumLeadZeroRPath.eq(Const(1)) & sumP1LeadZeroRPath.eq(0));

    final firstZeroRPath = nameLogic(
        'firstzero_rpath', mux(selectRPath, ~sumP1RPath[-1], ~sumRPath[-1]));

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

    final sumMantissaRPath = nameLogic(
        'summantissa_rpath',
        mux(selectRPath, sumP1RPath, sumRPath) +
            rndRPath.zeroExtend(sumRPath.width));
    final mantissaRPath = nameLogic(
        'mantissa_rpath',
        sumMantissaRPath <<
            mux(selectRPath, sumP1LeadZeroRPath, sumLeadZeroRPath));

    //
    //  N Datapath here:  close exponents, subtraction
    //
    final smallOperandNPath = nameLogic(
        'smalloperand', smallShift >>> (a.exponent[0] ^ b.exponent[0]));

    final significandSubtractorNPath = OnesComplementAdder(
        largeOperand, smallOperandNPath,
        subtractIn: effectiveSubtraction,
        adderGen: adderGen,
        name: 'npath_significand_sub');

    final significandNPath = nameLogic('significand_npath',
        significandSubtractorNPath.sum.slice(smallOperandNPath.width - 1, 0));

    final validLeadOneNPath = Logic(name: 'valid_lead1_npath');
    final leadOneNPathPre = ParallelPrefixPriorityEncoder(
            significandNPath.reversed,
            ppGen: ppTree,
            valid: validLeadOneNPath,
            name: 'npath_leadingOne')
        .out;
    // Limit leadOne to exponent range and match widths
    final leadOneNPath = nameLogic(
        'lead1_npath',
        (leadOneNPathPre.width > exponentWidth)
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

    final preExpNPath =
        nameLogic('preexp_npath', expCalcNPath.sum.slice(exponentWidth - 1, 0));

    final posExpNPath = nameLogic('posexp_npath',
        preExpNPath.or() & ~expCalcNPath.sign & validLeadOneNPathFlopped);

    final exponentNPath =
        nameLogic('exp_npath', mux(posExpNPath, preExpNPath, zeroExp));

    final preMinShiftNPath = nameLogic('preminshift_npath',
        ~leadOneNPathFlopped.or() | ~largerExpFlopped.or());

    final minShiftNPath = nameLogic('minshift_npath',
        mux(posExpNPath | preMinShiftNPath, leadOneNPathFlopped, expDecr.out));
    final notSubnormalNPath = aIsNormalFlopped | bIsNormalFlopped;

    final shiftedSignificandNPath = nameLogic('shifted_significand_npath',
        (significandNPathFlopped << minShiftNPath).slice(mantissaWidth, 1));

    final finalSignificandNPath = nameLogic(
        'final_significand_npath',
        mux(
            notSubnormalNPath,
            shiftedSignificandNPath,
            significandNPathFlopped.slice(
                significandNPathFlopped.width - 1, 2)));

    final signNPath = nameLogic(
        'sign_npath',
        mux(significandSubtractorNPathSignFlopped, smallerSignFlopped,
            largerSignFlopped));

    final isR = nameLogic(
        'isR',
        deltaFlopped.gte(Const(2, width: delta.width)) |
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
