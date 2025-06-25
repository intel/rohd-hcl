// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_adder_dualpath.dart
// A variable-width floating point adder using a dual path computation.
//
// 2024 August 30
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An adder module for variable FloatingPoint type.
// This is a Seidel/Even adder, dual-path implementation.
class FloatingPointAdderDualPath<FpTypeIn extends FloatingPoint,
        FpTypeOut extends FloatingPoint>
    extends FloatingPointAdder<FpTypeIn, FpTypeOut> {
  /// Add two floating point numbers [a] and [b], returning result in [sum].
  /// - [subtract] is an optional Logic input to do subtraction
  /// - [adderGen] is an adder generator to be used in the primary adder
  /// functions.
  /// - [widthGen] is the splitting function for creating the different adder
  /// blocks within the internal [CompoundAdder] used for mantissa addition.
  ///   Decreasing the split width will increase speed but also increase area.
  /// - [ppTree] is an ParallelPrefix generator for use in increment /decrement
  ///  functions.
  FloatingPointAdderDualPath(super.a, super.b,
      {Logic? subtract,
      super.clk,
      super.reset,
      super.enable,
      super.outSum,
      super.roundingMode = FloatingPointRoundingMode.roundNearestEven,
      Adder Function(Logic a, Logic b, {Logic? carryIn, String name}) adderGen =
          NativeAdder.new,
      List<int> Function(int) widthGen =
          CarrySelectCompoundAdder.splitSelectAdderAlgorithmSingleBlock,
      ParallelPrefix Function(
              List<Logic> inps, Logic Function(Logic term1, Logic term2) op)
          ppTree = KoggeStone.new,
      super.name = 'floating_point_adder_dualpath'})
      : super(
            definitionName: 'FloatingPointAdderDualPath_'
                'E${a.exponent.width}M${a.mantissa.width}') {
    if (a.explicitJBit || b.explicitJBit) {
      throw ArgumentError(
          'FloatingPointAdderDualPath does not support explicit J bit.');
    }
    if (roundingMode != FloatingPointRoundingMode.roundNearestEven) {
      throw RohdHclException('FloatingPointAdderDualPath only supports '
          'roundNearestEven.');
    }

    // Seidel: S.EFF = effectiveSubtraction
    final effectiveSubtraction =
        (a.sign ^ b.sign ^ (subtract ?? Const(0))).named('effSubtraction');
    final isNaN = (a.isNaN |
            b.isNaN |
            (a.isAnInfinity & b.isAnInfinity & effectiveSubtraction))
        .named('isNaN');
    final isInf = (a.isAnInfinity | b.isAnInfinity).named('isInf');

    final exponentSubtractor = OnesComplementAdder(
        super.a.exponent, super.b.exponent,
        subtract: true, adderGen: adderGen, name: 'exponent_sub');
    final signDelta = exponentSubtractor.sign.named('signDelta');

    final delta = exponentSubtractor.sum.named('expDelta');

    final fa = a.resolveSubNormalAsZero();
    final fb = b.resolveSubNormalAsZero();

    // Seidel: (sl, el, fl) = larger; (ss, es, fs) = smaller
    final swapper = FloatingPointConditionalSwap(fa, fb, signDelta);
    final larger = swapper.outA;
    final smaller = swapper.outB;

    final fl = mux(
            ~larger.isNormal ^ Const(larger.explicitJBit),
            [larger.mantissa, Const(0)].swizzle(),
            mux(
                larger.isNormal,
                [Const(1), larger.mantissa].swizzle(),
                [
                  larger.mantissa.getRange(0, mantissaWidth - 1),
                  Const(0, width: 2)
                ].swizzle()))
        .named('fullLarger');
    final fs = mux(
            ~smaller.isNormal ^ Const(smaller.explicitJBit),
            [smaller.mantissa, Const(0)].swizzle(),
            mux(
                smaller.isNormal,
                [Const(1), smaller.mantissa].swizzle(),
                [
                  smaller.mantissa.getRange(0, mantissaWidth - 1),
                  Const(0, width: 2)
                ].swizzle()))
        .named('fullSmaller');

    // Seidel: flp  larger preshift, normally in [2,4)
    final sigWidth = fl.width + 1;
    final largeShift = mux(effectiveSubtraction, fl.zeroExtend(sigWidth) << 1,
            fl.zeroExtend(sigWidth))
        .named('largeShift');
    final smallShift = mux(effectiveSubtraction, fs.zeroExtend(sigWidth) << 1,
            fs.zeroExtend(sigWidth))
        .named('smallShift');

    final zeroExp = internalSum.zeroExponent;
    final largeOperand = largeShift;
    //
    // R Datapath:  Far exponents or addition
    //
    final extendWidthRPath =
        min(mantissaWidth + 3, pow(2, exponentWidth).toInt() - 3);

    final smallerFullRPath = [smallShift, Const(0, width: extendWidthRPath)]
        .swizzle()
        .named('smallerFullRpath');

    final smallerAlignRPath = (smallerFullRPath >>> exponentSubtractor.sum)
        .named('smallerAlignedRpath');
    final smallerOperandRPath = smallerAlignRPath
        .slice(smallerAlignRPath.width - 1,
            smallerAlignRPath.width - largeOperand.width)
        .named('smallerOperandRpath');

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

    final significandAdderRPath = CarrySelectOnesComplementCompoundAdder(
        largeOperandFlopped, smallerOperandRPathFlopped,
        subtractIn: effectiveSubtractionFlopped,
        generateCarryOut: true,
        generateCarryOutP1: true,
        adderGen: adderGen,
        widthGen: widthGen,
        name: 'rpath_significand_adder');
    final carryRPath = significandAdderRPath.carryOut!;

    final lowBitsRPath = smallerAlignRPathFlopped
        .slice(extendWidthRPath - 1, 0)
        .named('lowbitsRpath');

    final lowAdderRPathSum = adderGen(carryRPath.zeroExtend(extendWidthRPath),
            mux(effectiveSubtractionFlopped, ~lowBitsRPath, lowBitsRPath),
            name: 'rpath_lowadder')
        .sum
        .named('lowAdderSumRpath');

    final preStickyRPath = lowAdderRPathSum
        .slice(lowAdderRPathSum.width - 4, 0)
        .or()
        .named('preStickyRpath');
    final stickyBitRPath =
        (lowAdderRPathSum[-3] | preStickyRPath).named('stickyBitRpath');

    final earlyGRSRPath = [
      lowAdderRPathSum.slice(
          lowAdderRPathSum.width - 2, lowAdderRPathSum.width - 3),
      preStickyRPath
    ].swizzle().named('earlyGRSRpath');

    final sumRPath =
        significandAdderRPath.sum.slice(mantissaWidth + 1, 0).named('sumRpath');
    final sumP1RPath = significandAdderRPath.sumP1
        .named('sumPlusOneRpath')
        .slice(mantissaWidth + 1, 0);

    final sumLeadZeroRPath =
        (~sumRPath[-1] & (aIsNormalFlopped | bIsNormalFlopped))
            .named('sumlead0Rpath');
    final sumP1LeadZeroRPath =
        (~sumP1RPath[-1] & (aIsNormalFlopped | bIsNormalFlopped))
            .named('sumP1lead0Rpath');

    final Logic selectRPath;
    if (roundingMode == FloatingPointRoundingMode.roundNearestEven) {
      selectRPath = lowAdderRPathSum[-1].named('selectRpath');
    } else {
      // TODO(desmonddak): This is an attempt to get the truncation working
      // but it is not correct, so we disable this mode for now.
      // The issue is that we need to handle both the carry from lower
      // bits as well as the additional rounding bit and this logic
      // is turning off both.
      // This case fails to truncate:  0 0000 0000,   1 0010 0000
      // selectRPath = Const(0).named('selectRpath');
      // This case fails to truncate:  0 0000 0000,   1 1010 0000
      selectRPath = lowAdderRPathSum[-1].named('selectRpath');
    }
    // R pipestage here:

    final shiftGRSRPath =
        [earlyGRSRPath[2], stickyBitRPath].swizzle().named('shiftGRSRpath');
    final mergedSumRPath = mux(
            sumLeadZeroRPath,
            [sumRPath, earlyGRSRPath]
                .swizzle()
                .named('sumEarlyGRSRpath')
                .slice(sumRPath.width + 1, 0),
            [sumRPath, shiftGRSRPath].swizzle())
        .named('mergedSumRpath');

    final mergedSumP1RPath = mux(
            sumP1LeadZeroRPath,
            [sumP1RPath, earlyGRSRPath]
                .swizzle()
                .named('sump1EarlyGRSRPath')
                .slice(sumRPath.width + 1, 0),
            [sumP1RPath, shiftGRSRPath].swizzle())
        .named('mergedSumP1RPath');

    final finalSumLGRSRPath = mux(selectRPath, mergedSumP1RPath, mergedSumRPath)
        .named('finalSumLGRSRpath');
    // RNE: guard & (lsb | round | sticky)
    final rndRPath = (finalSumLGRSRPath[2] &
            (finalSumLGRSRPath[3] |
                finalSumLGRSRPath[1] |
                finalSumLGRSRPath[0]))
        .named('rndRpath');

    // Rounding from 1111 to 0000.
    final Logic incExpRPath;
    if (roundingMode == FloatingPointRoundingMode.roundNearestEven) {
      incExpRPath =
          (rndRPath & sumLeadZeroRPath.eq(Const(1)) & sumP1LeadZeroRPath.eq(0))
              .named('incExpRrpath');
    } else {
      incExpRPath = Const(0).named('incExpRrpath');
    }

    final firstZeroRPath = mux(selectRPath, ~sumP1RPath[-1], ~sumRPath[-1])
        .named('firstZero_rpath');

    final expDecr = ParallelPrefixDecr(largerExpFlopped,
        ppGen: ppTree, name: 'expDecrement');
    final expIncr = ParallelPrefixIncr(largerExpFlopped,
        ppGen: ppTree, name: 'expIncrement');
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

    final Logic mantissaRPath;
    final sumMantissaRPath =
        mux(selectRPath, sumP1RPath, sumRPath).named('selectSumMantissa_rpath');
    if (roundingMode == FloatingPointRoundingMode.roundNearestEven) {
      final sumMantissaRPathRnd = (sumMantissaRPath +
              rndRPath.zeroExtend(sumRPath.width).named('rndExtend_rpath'))
          .named('sumMantissaRndRpath');
      mantissaRPath = (sumMantissaRPathRnd <<
              mux(selectRPath, sumP1LeadZeroRPath, sumLeadZeroRPath))
          .named('mantissaRpath');
    } else {
      mantissaRPath =
          (sumMantissaRPath << sumLeadZeroRPath).named('mantissaRpath');
    }

    //
    //  N Datapath here:  close exponents, subtraction
    //
    final smallOperandNPath =
        (smallShift >>> (a.exponent[0] ^ b.exponent[0])).named('smallOperand');

    // TODO(desmonddak): could we avoid the end-around-carry here or will that
    // cause too much to do for the leadingOne calculation. Could we reverse the
    // operands or is there no guarantee?  If so, would a dual-adder make sense
    // here?
    final significandSubtractorNPath = OnesComplementAdder(
        largeOperand, smallOperandNPath,
        subtractIn: effectiveSubtraction,
        adderGen: adderGen,
        name: 'npath_significand_sub');

    final significandNPath = significandSubtractorNPath.sum
        .slice(smallOperandNPath.width - 1, 0)
        .named('significandNpath');

    // N pipestage here:
    final significandNPathFlopped = localFlop(significandNPath);
    final significandSubtractorNPathSignFlopped =
        localFlop(significandSubtractorNPath.sign);
    final largerSignFlopped = localFlop(larger.sign);
    final smallerSignFlopped = localFlop(smaller.sign);

    final leadOneEncoderNPath = RecursiveModulePriorityEncoder(
        significandNPathFlopped.reversed,
        generateValid: true,
        name: 'npath_leadingOne');
    final leadOneNPathPre = leadOneEncoderNPath.out;
    final validLeadOneNPath = leadOneEncoderNPath.valid!;
    // Limit leadOne to exponent range and match widths
    final leadOneNPath = ((leadOneNPathPre.width > exponentWidth)
            ? mux(
                leadOneNPathPre
                    .gte(a.inf().exponent.zeroExtend(leadOneNPathPre.width)),
                a.inf().exponent,
                leadOneNPathPre.getRange(0, exponentWidth))
            : leadOneNPathPre.zeroExtend(exponentWidth))
        .named('leadOneNpath');

    final expCalcNPath = OnesComplementAdder(
        largerExpFlopped, leadOneNPath.zeroExtend(exponentWidth),
        subtractIn: Const(1), adderGen: adderGen, name: 'npath_expcalc');

    final preExpNPath =
        expCalcNPath.sum.slice(exponentWidth - 1, 0).named('preExpNpath');

    final posExpNPath =
        (preExpNPath.or() & ~expCalcNPath.sign & validLeadOneNPath)
            .named('posExpNpath');

    final exponentNPath =
        mux(posExpNPath, preExpNPath, zeroExp).named('exponentNpath');

    final preMinShiftNPath =
        (~leadOneNPath.or() | ~largerExpFlopped.or()).named('preMinShiftNpath');

    final minShiftNPath =
        mux(posExpNPath | preMinShiftNPath, leadOneNPath, expDecr.out)
            .named('minShiftNpath');
    final notSubnormalNPath = aIsNormalFlopped | bIsNormalFlopped;

    final shiftedSignificandNPath = (significandNPathFlopped << minShiftNPath)
        .named('shiftedSignificandNpath')
        .slice(mantissaWidth, 1);

    final finalSignificandNPath = mux(
            notSubnormalNPath,
            shiftedSignificandNPath,
            significandNPathFlopped.slice(significandNPathFlopped.width - 1, 2))
        .named('finalSignificandNpath');

    final signNPath = mux(significandSubtractorNPathSignFlopped,
            smallerSignFlopped, largerSignFlopped)
        .named('signNpath');

    final isR = (deltaFlopped.gte(Const(2, width: delta.width)) |
            ~effectiveSubtractionFlopped)
        .named('isR');
    final infExponent = internalSum.inf(sign: largerSignFlopped).exponent;

    final inf = internalSum.inf(sign: largerSignFlopped);

    final realIsInfRPath =
        exponentRPath.eq(infExponent).named('realIsInfRPath');

    final realIsInfNPath =
        exponentNPath.eq(infExponent).named('realIsInfNPath');

    final outSubNormalAsZero =
        internalSum.subNormalAsZero ? Const(1) : Const(0);

    Combinational([
      If(isNaNFlopped, then: [
        internalSum < internalSum.nan,
      ], orElse: [
        If(isInfFlopped, then: [
          internalSum < internalSum.inf(sign: largerSignFlopped),
        ], orElse: [
          If(isR, then: [
            If(realIsInfRPath, then: [
              internalSum < inf,
            ], orElse: [
              internalSum.sign < largerSignFlopped,
              internalSum.exponent < exponentRPath,
              internalSum.mantissa <
                  mux(
                      outSubNormalAsZero & ~exponentRPath.or(),
                      Const(0, width: internalSum.mantissa.width),
                      mantissaRPath.slice(mantissaRPath.width - 2, 1)),
            ]),
          ], orElse: [
            If(realIsInfNPath, then: [
              internalSum < inf,
            ], orElse: [
              internalSum.sign < signNPath,
              internalSum.exponent < exponentNPath,
              internalSum.mantissa <
                  mux(
                      outSubNormalAsZero & ~exponentNPath.or(),
                      Const(0, width: finalSignificandNPath.width),
                      finalSignificandNPath),
            ]),
          ])
        ])
      ])
    ]);
  }
}
