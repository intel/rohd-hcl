// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_adder_round.dart
// A variable-width floating point adder with rounding
//
// 2024 August 30
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Conditionally constructs a positive edge triggered flip condFlop on [clk].
///
/// It returns either [FlipFlop.q] if [clk] is valid or [d] if not.
///
/// When the optional [en] is provided, an additional input will be created for
/// condFlop. If optional [en] is high or not provided, output will vary as per
/// input[d]. For low [en], output remains frozen irrespective of input [d].
///
/// When the optional [reset] is provided, the condFlop will be reset
/// (active-high).
/// If no [resetValue] is provided, the reset value is always `0`. Otherwise,
/// it will reset to the provided [resetValue].
Logic condFlop(
  Logic? clk,
  Logic d, {
  Logic? en,
  Logic? reset,
  dynamic resetValue,
}) =>
    (clk == null)
        ? d
        : flop(
            clk,
            d,
            en: en,
            reset: reset,
            resetValue: resetValue,
          );

/// An adder module for variable FloatingPoint type with rounding.
// This is a Seidel/Even adder, dual-path implementation.
class FloatingPointAdderRound extends Module {
  /// Must be greater than 0.
  final int exponentWidth;

  /// Must be greater than 0.
  final int mantissaWidth;

  /// The [clk]:  if a valid clock signal is passed in, a pipestage is added to
  /// the adder to help optimize frequency.
  Logic? clk;

  /// Optional [reset], used only if a [clk] is not null to reset the pipeline
  /// flops.
  Logic? reset;

  /// Optional [enable], used only if a [clk] is not null to enable the pipeline
  /// flops.
  Logic? enable;

  /// Output [FloatingPoint] representing the sum of two input [FloatingPoint]s
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
  FloatingPointAdderRound(FloatingPoint a, FloatingPoint b,
      {Logic? subtract,
      this.clk,
      this.reset,
      this.enable,
      Adder Function(Logic, Logic, {Logic? carryIn}) adderGen =
          ParallelPrefixAdder.new,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))
          ppTree = KoggeStone.new,
      super.name = 'floating_point_adder_round'})
      : exponentWidth = a.exponent.width,
        mantissaWidth = a.mantissa.width {
    if (b.exponent.width != exponentWidth ||
        b.mantissa.width != mantissaWidth) {
      throw RohdHclException('FloatingPoint widths must match');
    }
    if (clk != null) {
      clk = addInput('clk', clk!);
    }
    if (reset != null) {
      reset = addInput('reset', reset!);
    }
    if (enable != null) {
      enable = addInput('enable', enable!);
    }
    a = a.clone()..gets(addInput('a', a, width: a.width));
    b = b.clone()..gets(addInput('b', b, width: b.width));
    addOutput('sum', width: _sum.width) <= _sum;

    final exponentSubtractor = OnesComplementAdder(a.exponent, b.exponent,
        subtract: true, adderGen: adderGen, name: 'exponent_sub');
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

    final smallerAlignRPath = smallerFullRPath >>> exponentSubtractor.sum;
    final smallerOperandRPath = smallerAlignRPath.slice(
        smallerAlignRPath.width - 1,
        smallerAlignRPath.width - largeOperand.width);

    /// R Pipestage here:
    final aIsNormalLatched =
        condFlop(clk, a.isNormal(), en: enable, reset: reset);
    final bIsNormalLatched =
        condFlop(clk, b.isNormal(), en: enable, reset: reset);
    final effectiveSubtractionLatched =
        condFlop(clk, effectiveSubtraction, en: enable, reset: reset);
    final largeOperandLatched =
        condFlop(clk, largeOperand, en: enable, reset: reset);
    final smallerOperandRPathLatched =
        condFlop(clk, smallerOperandRPath, en: enable, reset: reset);
    final smallerAlignRPathLatched =
        condFlop(clk, smallerAlignRPath, en: enable, reset: reset);
    final largerExpLatched =
        condFlop(clk, larger.exponent, en: enable, reset: reset);
    final deltaLatched = condFlop(clk, delta, en: enable, reset: reset);

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

    final leadOneNPath = mux(
        significandNPath.or(),
        ParallelPrefixPriorityEncoder(significandNPath.reversed,
                ppGen: ppTree, name: 'npath_leadingOne')
            .out
            .zeroExtend(exponentWidth),
        Const(15, width: exponentWidth));

    // N pipestage here:
    final significandNPathLatched =
        condFlop(clk, significandNPath, en: enable, reset: reset);
    final significandSubtractorNPathSignLatched = condFlop(
        clk, significandSubtractorNPath.sign,
        en: enable, reset: reset);
    final leadOneNPathLatched =
        condFlop(clk, leadOneNPath, en: enable, reset: reset);
    final largerSignLatched =
        condFlop(clk, larger.sign, en: enable, reset: reset);
    final smallerSignLatched =
        condFlop(clk, smaller.sign, en: enable, reset: reset);

    final expCalcNPath = OnesComplementAdder(
        largerExpLatched, leadOneNPathLatched.zeroExtend(exponentWidth),
        subtractIn: effectiveSubtractionLatched,
        adderGen: adderGen,
        name: 'npath_expcalc');

    final preExpNPath = expCalcNPath.sum.slice(exponentWidth - 1, 0);

    final posExpNPath = preExpNPath.or() & ~expCalcNPath.sign;

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
    _sum <=
        mux(
            isR,
            [
              largerSignLatched,
              exponentRPath,
              mantissaRPath.slice(mantissaRPath.width - 2, 1)
            ].swizzle(),
            [signNPath, exponentNPath, finalSignificandNPath].swizzle());
  }
}
