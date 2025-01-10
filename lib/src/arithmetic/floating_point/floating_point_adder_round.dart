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

    // Ensure that the larger number is wired as 'a'
    final ae = this.a.exponent;
    final be = this.b.exponent;
    final am = this.a.mantissa;
    final bm = this.b.mantissa;
    final doSwap = ae.lt(be) |
        (ae.eq(be) & am.lt(bm)) |
        ((ae.eq(be) & am.eq(bm)) & this.a.sign);

    final FloatingPoint a;
    final FloatingPoint b;
    (a, b) = swap(doSwap, (super.a, super.b));

    // Seidel: S.EFF = effectiveSubtraction
    final effectiveSubtraction = a.sign ^ b.sign ^ (subtract ?? Const(0));
    final isNaN = a.isNaN |
        b.isNaN |
        (a.isInfinity & b.isInfinity & effectiveSubtraction);
    final isInf = a.isInfinity | b.isInfinity;

    final exponentSubtractor = OnesComplementAdder(a.exponent, b.exponent,
        subtract: true, adderGen: adderGen, name: 'exponent_sub');
    final signDelta = exponentSubtractor.sign;

    final delta = exponentSubtractor.sum;

    // Seidel: (sl, el, fl) = larger; (ss, es, fs) = smaller
    final (larger, smaller) = swap(signDelta, (a, b));

    final fl = mux(
        larger.isNormal,
        [larger.isNormal, larger.mantissa].swizzle(),
        [larger.mantissa, Const(0)].swizzle());
    final fs = mux(
        smaller.isNormal,
        [smaller.isNormal, smaller.mantissa].swizzle(),
        [smaller.mantissa, Const(0)].swizzle());

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

    final smallerAlignRPath = smallerFullRPath >>> exponentSubtractor.sum;
    final smallerOperandRPath = smallerAlignRPath.slice(
        smallerAlignRPath.width - 1,
        smallerAlignRPath.width - largeOperand.width);

    /// R Pipestage here:
    final aIsNormalLatched = localFlop(a.isNormal);
    final bIsNormalLatched = localFlop(b.isNormal);
    final effectiveSubtractionLatched = localFlop(effectiveSubtraction);
    final largeOperandLatched = localFlop(largeOperand);
    final smallerOperandRPathLatched = localFlop(smallerOperandRPath);
    final smallerAlignRPathLatched = localFlop(smallerAlignRPath);
    final largerExpLatched = localFlop(larger.exponent);
    final deltaLatched = localFlop(delta);
    final isInfLatched = localFlop(isInf);
    final isNaNLatched = localFlop(isNaN);

    final carryRPath = Logic();
    final significandAdderRPath = OnesComplementAdder(
        largeOperandLatched, smallerOperandRPathLatched,
        subtractIn: effectiveSubtractionLatched,
        carryOut: carryRPath,
        adderGen: adderGen,
        name: 'rpath_significand_adder');

    final lowBitsRPath =
        smallerAlignRPathLatched.slice(extendWidthRPath - 1, 0);
    final lowAdderRPath = OnesComplementAdder(
        carryRPath.zeroExtend(extendWidthRPath),
        mux(effectiveSubtractionLatched, ~lowBitsRPath, lowBitsRPath),
        adderGen: adderGen,
        name: 'rpath_lowadder');

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

    final sumLeadZeroRPath =
        ~sumRPath[-1] & (aIsNormalLatched | bIsNormalLatched);
    final sumP1LeadZeroRPath =
        ~sumP1RPath[-1] & (aIsNormalLatched | bIsNormalLatched);

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

    final expDecr = ParallelPrefixDecr(largerExpLatched,
        ppGen: ppTree, name: 'exp_decrement');
    final expIncr = ParallelPrefixIncr(largerExpLatched,
        ppGen: ppTree, name: 'exp_increment');
    final exponentRPath = Logic(width: exponentWidth);
    Combinational([
      If.block([
        // Subtract 1 from exponent
        Iff(~incExpRPath & effectiveSubtractionLatched & firstZeroRPath,
            [exponentRPath < expDecr.out]),
        // Add 1 to exponent
        ElseIf(
            ~effectiveSubtractionLatched &
                (incExpRPath & firstZeroRPath | ~incExpRPath & ~firstZeroRPath),
            [exponentRPath < expIncr.out]),
        // Add 2 to exponent
        ElseIf(incExpRPath & effectiveSubtractionLatched & ~firstZeroRPath,
            [exponentRPath < largerExpLatched << 1]),
        Else([exponentRPath < largerExpLatched])
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
        subtractIn: effectiveSubtraction,
        adderGen: adderGen,
        name: 'npath_significand_sub');

    final significandNPath =
        significandSubtractorNPath.sum.slice(smallOperandNPath.width - 1, 0);

    final validLeadOneNPath = Logic();
    final leadOneNPathPre = ParallelPrefixPriorityEncoder(
            significandNPath.reversed,
            ppGen: ppTree,
            valid: validLeadOneNPath,
            name: 'npath_leadingOne')
        .out;
    // Limit leadOne to exponent range and match widths
    final leadOneNPath = (leadOneNPathPre.width > exponentWidth)
        ? mux(
            leadOneNPathPre
                .gte(a.inf().exponent.zeroExtend(leadOneNPathPre.width)),
            a.inf().exponent,
            leadOneNPathPre.getRange(0, exponentWidth))
        : leadOneNPathPre.zeroExtend(exponentWidth);

    // N pipestage here:
    final significandNPathLatched = localFlop(significandNPath);
    final significandSubtractorNPathSignLatched =
        localFlop(significandSubtractorNPath.sign);
    final leadOneNPathLatched = localFlop(leadOneNPath);
    final validLeadOneNPathLatched = localFlop(validLeadOneNPath);
    final largerSignLatched = localFlop(larger.sign);
    final smallerSignLatched = localFlop(smaller.sign);

    final expCalcNPath = OnesComplementAdder(
        largerExpLatched, leadOneNPathLatched.zeroExtend(exponentWidth),
        subtractIn: effectiveSubtractionLatched,
        adderGen: adderGen,
        name: 'npath_expcalc');

    final preExpNPath = expCalcNPath.sum.slice(exponentWidth - 1, 0);

    final posExpNPath =
        preExpNPath.or() & ~expCalcNPath.sign & validLeadOneNPathLatched;

    final exponentNPath = mux(posExpNPath, preExpNPath, zeroExp);

    final preMinShiftNPath = ~leadOneNPathLatched.or() | ~largerExpLatched.or();

    final minShiftNPath =
        mux(posExpNPath | preMinShiftNPath, leadOneNPathLatched, expDecr.out);
    final notSubnormalNPath = aIsNormalLatched | bIsNormalLatched;

    final shiftedSignificandNPath =
        (significandNPathLatched << minShiftNPath).slice(mantissaWidth, 1);

    final finalSignificandNPath = mux(
        notSubnormalNPath,
        shiftedSignificandNPath,
        significandNPathLatched.slice(significandNPathLatched.width - 1, 2));

    final signNPath = mux(significandSubtractorNPathSignLatched,
        smallerSignLatched, largerSignLatched);

    final isR = deltaLatched.gte(Const(2, width: delta.width)) |
        ~effectiveSubtractionLatched;

    Combinational([
      If(isNaNLatched, then: [
        outputSum < outputSum.nan,
      ], orElse: [
        If(isInfLatched, then: [
          outputSum < outputSum.inf(sign: largerSignLatched),
        ], orElse: [
          If(isR, then: [
            outputSum.sign < largerSignLatched,
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
