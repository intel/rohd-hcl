// Copyright (C) 2024-2026 Intel Corporation
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

/// A fast adder module for variable width [FloatingPoint] logic signals.
// This is a Seidel/Even adder, dual-path implementation.
class FloatingPointAdderDualPath<FpTypeIn extends FloatingPoint,
        FpTypeOut extends FloatingPoint>
    extends FloatingPointAdder<FpTypeIn, FpTypeOut> {
  /// Add two floating point numbers [a] and [b], returning result in [sum].
  /// - [subtract] is an optional [Logic] input to do subtraction.
  /// - [adderGen] is an adder generator to be used in the primary adder
  ///   functions.
  /// - [widthGen] is the splitting function for creating the different adder.
  ///   blocks within the internal [CompoundAdder] used for mantissa addition.
  ///   Decreasing the split width will increase speed but also increase area.
  /// - [ppTree] is a [ParallelPrefix] generator for use in increment /decrement
  ///   functions.
  ///
  ///  If [outSum] is provided, it will be used as the output type, otherwise
  /// the output type will be the same as the input type [a]. Note that
  /// [FloatingPointAdderDualPath] does not support explicit j-bit types.
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
      super.name = 'floating_point_adder_dualpath',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'FloatingPointAdderDualPath_'
                    'E${a.exponent.width}M${a.mantissa.width}') {
    if (a.explicitJBit || b.explicitJBit) {
      throw ArgumentError(
          'FloatingPointAdderDualPath does not support explicit J bit.');
    }

    if (internalSum.explicitJBit) {
      throw ArgumentError(
          'FloatingPointAdderDualPath does not support explicit J bit output.');
    }

    // Seidel: S.EFF = effectiveSubtraction.
    final isInf = (a.isAnInfinity | b.isAnInfinity).named('isInf');

    final exponentSubtractor = OnesComplementAdder(
        super.a.exponent, super.b.exponent,
        subtract: true, adderGen: adderGen, name: 'exponent_sub');
    final signDelta = exponentSubtractor.sign.named('signDelta');

    final delta = exponentSubtractor.sum.named('expDelta');

    final fa = a.resolveSubNormalAsZero();
    final fb = b.resolveSubNormalAsZero();

    final effectiveSubtraction =
        (fa.sign ^ fb.sign ^ (subtract ?? Const(0))).named('effSubtraction');
    final invalidArithmetic =
        (a.isAnInfinity & b.isAnInfinity & effectiveSubtraction)
            .named('invalidArithmetic');
    final invalidOperation =
        (a.isSignalingNaN | b.isSignalingNaN | invalidArithmetic)
            .named('invalidOperation');
    final isNaN = (a.isNaN | b.isNaN | invalidArithmetic).named('isNaN');
    final inputIsNaN = (a.isNaN | b.isNaN).named('inputIsNaN');
    final propagatedNaN = internalSum.propagateNaN(a, b);
    // Seidel: (sl, el, fl) = larger; (ss, es, fs) = smaller.
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

    // Seidel: flp  larger preshift, normally in [2,4).
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
    // R Datapath:  Far exponents or addition.
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
    final farShiftWidth = max(delta.width, log2Ceil(smallShift.width) + 1);
    final farShift = mux(
            delta
                .zeroExtend(farShiftWidth)
                .gte(Const(extendWidthRPath, width: farShiftWidth)),
            delta.zeroExtend(farShiftWidth) -
                Const(extendWidthRPath, width: farShiftWidth),
            Const(0, width: farShiftWidth))
        .named('farShiftRpath');
    final farChop = mux(
            farShift.lt(Const(smallShift.width, width: farShiftWidth)),
            Const(smallShift.width, width: farShiftWidth) - farShift,
            Const(0, width: farShiftWidth))
        .named('farChopRpath');
    final farStickyRPath = (smallShift << farChop).or().named('farStickyRpath');

    /// R Pipestage here:
    final aIsNormalFlopped = localFlop(a.isNormal);
    final bIsNormalFlopped = localFlop(b.isNormal);
    final effectiveSubtractionFlopped = localFlop(effectiveSubtraction);
    final largeOperandFlopped = localFlop(largeOperand);
    final smallerOperandRPathFlopped = localFlop(smallerOperandRPath);
    final smallerAlignRPathFlopped = localFlop(smallerAlignRPath);
    final farStickyRPathFlopped = localFlop(farStickyRPath);
    final largerExpFlopped = localFlop(larger.exponent);
    final largerSignFlopped = localFlop(larger.sign);
    final deltaFlopped = localFlop(delta);
    final isInfFlopped = localFlop(isInf);
    final isNaNFlopped = localFlop(isNaN);
    final invalidOperationFlopped = localFlop(invalidOperation);
    final inputIsNaNFlopped = localFlop(inputIsNaN);
    final nanSignFlopped = localFlop(propagatedNaN.sign);
    final nanMantissaFlopped = localFlop(propagatedNaN.mantissa);

    final significandAdderRPath = CarrySelectOnesComplementCompoundAdder(
        largeOperandFlopped, smallerOperandRPathFlopped,
        subtract: effectiveSubtractionFlopped,
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
        .slice(mantissaWidth + 1, 0)
        .named('sumPlusOneRpath');

    final sumLeadZeroRPath =
        (~sumRPath[-1] & (aIsNormalFlopped | bIsNormalFlopped))
            .named('sumlead0Rpath');
    final sumP1LeadZeroRPath =
        (~sumP1RPath[-1] & (aIsNormalFlopped | bIsNormalFlopped))
            .named('sumP1lead0Rpath');

    final selectRPath = (lowAdderRPathSum[-1] &
            ~(effectiveSubtractionFlopped & farStickyRPathFlopped))
        .named('selectRpath');
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
                .named('sumP1EarlyGRSRPath')
                .slice(sumRPath.width + 1, 0),
            [sumP1RPath, shiftGRSRPath].swizzle().named('sumP1ShiftGRSRPath'))
        .named('mergedSumP1RPath');

    final sumRounderRPath = FloatingPointRounder.fromGRS(
        retainedLsb: mergedSumRPath[3],
        guard: mergedSumRPath[2],
        roundBit: mergedSumRPath[1],
        sticky: mergedSumRPath[0],
        extraSticky: farStickyRPathFlopped,
        roundingMode: roundingMode,
        sign: largerSignFlopped);
    final sumP1RounderRPath = FloatingPointRounder.fromGRS(
        retainedLsb: mergedSumP1RPath[3],
        guard: mergedSumP1RPath[2],
        roundBit: mergedSumP1RPath[1],
        sticky: mergedSumP1RPath[0],
        extraSticky: farStickyRPathFlopped,
        roundingMode: roundingMode,
        sign: largerSignFlopped);
    final lowBitsAfterNormalizeRPath =
        lowBitsRPath.slice(lowBitsRPath.width - 2, 0).or();
    Logic inexactForRPathCandidate(Logic leadZero) =>
        (mux(leadZero, lowBitsAfterNormalizeRPath, lowBitsRPath.or()) |
                farStickyRPathFlopped)
            .named('candidateInexactRpath');
    final sumInexactRPath =
        (sumRounderRPath.inexact | inexactForRPathCandidate(sumLeadZeroRPath))
            .named('sumInexactRpath');
    final sumP1InexactRPath = (sumP1RounderRPath.inexact |
            inexactForRPathCandidate(sumP1LeadZeroRPath))
        .named('sumP1InexactRpath');
    Logic roundForRPathCandidate(FloatingPointRounder rounder, Logic inexact) =>
        switch (roundingMode) {
          FloatingPointRoundingMode.truncate ||
          FloatingPointRoundingMode.roundTowardsZero =>
            Const(0),
          FloatingPointRoundingMode.roundNearestEven ||
          FloatingPointRoundingMode.roundNearestTiesAway =>
            rounder.doRound,
          FloatingPointRoundingMode.roundTowardsInfinity =>
            ~largerSignFlopped & inexact,
          FloatingPointRoundingMode.roundTowardsNegativeInfinity =>
            largerSignFlopped & inexact,
        };
    final roundSumRPath =
        roundForRPathCandidate(sumRounderRPath, sumInexactRPath)
            .named('roundSumRpath');
    final roundSumP1RPath =
        roundForRPathCandidate(sumP1RounderRPath, sumP1InexactRPath)
            .named('roundSumP1Rpath');

    final sumP2RPath =
        ParallelPrefixIncr(sumP1RPath, ppGen: ppTree, name: 'sumPlusTwoRpath')
            .out
            .named('sumP2Rpath');
    final sumP2CarryRPath = sumP1RPath.and().named('sumP2CarryRpath');
    final sumP3RPath =
        ParallelPrefixIncr(sumP2RPath, ppGen: ppTree, name: 'sumPlusThreeRpath')
            .out
            .named('sumP3Rpath');
    final sumP3CarryRPath = sumP2RPath.and().named('sumP3CarryRpath');
    final sumP2LeadZeroRPath = (~sumP2RPath[-1] &
            ~sumP2CarryRPath &
            (aIsNormalFlopped | bIsNormalFlopped))
        .named('sumP2lead0Rpath');
    final sumP3LeadZeroRPath = (~sumP3RPath[-1] &
            ~sumP3CarryRPath &
            (aIsNormalFlopped | bIsNormalFlopped))
        .named('sumP3lead0Rpath');

    final normalizedSumRPath =
        (sumRPath << sumLeadZeroRPath).named('normalizedSumRpath');
    final normalizedSumP1RPath =
        (sumP1RPath << sumP1LeadZeroRPath).named('normalizedSumP1Rpath');
    final normalizedSumP2RPath =
        (sumP2RPath << sumP2LeadZeroRPath).named('normalizedSumP2Rpath');
    final normalizedSumP3RPath =
        (sumP3RPath << sumP3LeadZeroRPath).named('normalizedSumP3Rpath');
    final roundedTargetSumRPath = mux(sumLeadZeroRPath | sumRPath[0],
            normalizedSumP1RPath, normalizedSumP2RPath)
        .named('roundedTargetSumRpath');
    final roundedTargetSumP1RPath = mux(sumP1LeadZeroRPath | sumP1RPath[0],
            normalizedSumP2RPath, normalizedSumP3RPath)
        .named('roundedTargetSumP1Rpath');
    final roundedSumBranchRPath =
        mux(roundSumRPath, roundedTargetSumRPath, normalizedSumRPath)
            .named('roundedSumBranchRpath');
    final roundedSumP1BranchRPath =
        mux(roundSumP1RPath, roundedTargetSumP1RPath, normalizedSumP1RPath)
            .named('roundedSumP1BranchRpath');
    final mantissaRPath =
        mux(selectRPath, roundedSumP1BranchRPath, roundedSumBranchRPath)
            .named('mantissaRpath');

    final expDecr = ParallelPrefixDecr(largerExpFlopped,
        ppGen: ppTree, name: 'expDecrement');
    final expIncr = ParallelPrefixIncr(largerExpFlopped,
        ppGen: ppTree, name: 'expIncrement');
    final maxExponentRPath = Const(1, width: exponentWidth, fill: true);
    final expIncr2Raw =
        ParallelPrefixIncr(expIncr.out, ppGen: ppTree, name: 'expIncrement2')
            .out;
    final expIncr2 =
        mux(expIncr.out.eq(maxExponentRPath), maxExponentRPath, expIncr2Raw)
            .named('expIncrementedTwice');

    Logic exponentForRPathCandidate(Logic candidate, {Logic? overflow}) => mux(
        (overflow ?? Const(0)) & ~effectiveSubtractionFlopped,
        expIncr2,
        mux(
            effectiveSubtractionFlopped,
            mux(~candidate[-1], expDecr.out, largerExpFlopped),
            mux(candidate[-1], expIncr.out, largerExpFlopped)));

    final exponentSumRPath =
        exponentForRPathCandidate(sumRPath).named('exponentSumRpath');
    final exponentSumP1RPath =
        exponentForRPathCandidate(sumP1RPath).named('exponentSumP1Rpath');
    final exponentSumP2RPath =
        exponentForRPathCandidate(sumP2RPath, overflow: sumP2CarryRPath)
            .named('exponentSumP2Rpath');
    final exponentSumP3RPath =
        exponentForRPathCandidate(sumP3RPath, overflow: sumP3CarryRPath)
            .named('exponentSumP3Rpath');
    final roundedTargetExponentSumRPath = mux(sumLeadZeroRPath | sumRPath[0],
            exponentSumP1RPath, exponentSumP2RPath)
        .named('roundedTargetExponentSumRpath');
    final roundedTargetExponentSumP1RPath = mux(
            sumP1LeadZeroRPath | sumP1RPath[0],
            exponentSumP2RPath,
            exponentSumP3RPath)
        .named('roundedTargetExponentSumP1Rpath');
    final roundedExponentSumBranchRPath =
        mux(roundSumRPath, roundedTargetExponentSumRPath, exponentSumRPath)
            .named('roundedExponentSumBranchRpath');
    final roundedExponentSumP1BranchRPath = mux(roundSumP1RPath,
            roundedTargetExponentSumP1RPath, exponentSumP1RPath)
        .named('roundedExponentSumP1BranchRpath');
    final exponentRPath = mux(selectRPath, roundedExponentSumP1BranchRPath,
            roundedExponentSumBranchRPath)
        .named('exponentRpath');
    final maxExponentMinusOne =
        Const((1 << exponentWidth) - 2, width: exponentWidth);
    Logic exponentOverflowForRPathCandidate(Logic candidate,
            {Logic? overflow}) =>
        ~effectiveSubtractionFlopped &
        mux(overflow ?? Const(0), largerExpFlopped.gte(maxExponentMinusOne),
            candidate[-1] & largerExpFlopped.and());
    final exponentOverflowSumRPath =
        exponentOverflowForRPathCandidate(sumRPath);
    final exponentOverflowSumP1RPath =
        exponentOverflowForRPathCandidate(sumP1RPath);
    final exponentOverflowSumP2RPath = exponentOverflowForRPathCandidate(
        sumP2RPath,
        overflow: sumP2CarryRPath);
    final exponentOverflowSumP3RPath = exponentOverflowForRPathCandidate(
        sumP3RPath,
        overflow: sumP3CarryRPath);
    final roundedTargetExponentOverflowSumRPath = mux(
        sumLeadZeroRPath | sumRPath[0],
        exponentOverflowSumP1RPath,
        exponentOverflowSumP2RPath);
    final roundedTargetExponentOverflowSumP1RPath = mux(
        sumP1LeadZeroRPath | sumP1RPath[0],
        exponentOverflowSumP2RPath,
        exponentOverflowSumP3RPath);
    final roundedExponentOverflowSumBranchRPath = mux(roundSumRPath,
        roundedTargetExponentOverflowSumRPath, exponentOverflowSumRPath);
    final roundedExponentOverflowSumP1BranchRPath = mux(roundSumP1RPath,
        roundedTargetExponentOverflowSumP1RPath, exponentOverflowSumP1RPath);
    final exponentOverflowRPath = mux(
            selectRPath,
            roundedExponentOverflowSumP1BranchRPath,
            roundedExponentOverflowSumBranchRPath)
        .named('exponentOverflowRpath');

    //
    //  N Datapath here:  close exponents, subtraction.
    //
    final smallOperandNPath =
        (smallShift >>> (a.exponent[0] ^ b.exponent[0])).named('smallOperand');

    // Exponent ordering cannot determine mantissa magnitude on the N-path, so
    // end-around carry resolves ambiguous subtraction.
    // A dual adder could shorten the critical path at roughly double the area.
    final significandSubtractorNPath = OnesComplementAdder(
        largeOperand, smallOperandNPath,
        subtract: effectiveSubtraction,
        adderGen: adderGen,
        name: 'npath_significand_sub');

    final significandNPath = significandSubtractorNPath.sum
        .slice(smallOperandNPath.width - 1, 0)
        .named('significandNpath');

    // N pipestage here:
    final significandNPathFlopped = localFlop(significandNPath);
    final significandSubtractorNPathSignFlopped =
        localFlop(significandSubtractorNPath.sign);
    final smallerSignFlopped = localFlop(smaller.sign);

    final leadOneEncoderNPath = RecursiveModulePriorityEncoder(
        significandNPathFlopped.reversed,
        generateValid: true,
        name: 'npath_leadingOne');
    final leadOneNPathPre = leadOneEncoderNPath.out;
    final validLeadOneNPath = leadOneEncoderNPath.valid!;
    // Limit leadOne to exponent range and match widths.
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
        subtract: Const(1), adderGen: adderGen, name: 'npath_expcalc');

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

    final shiftedSignificandNPathFull =
        (significandNPathFlopped << minShiftNPath)
            .named('shiftedSignificandFullNpath');
    final shiftedSignificandNPath =
        shiftedSignificandNPathFull.slice(mantissaWidth, 1);

    final finalSignificandNPath = mux(
            notSubnormalNPath,
            shiftedSignificandNPath,
            significandNPathFlopped.slice(significandNPathFlopped.width - 1, 2))
        .named('finalSignificandNpath');

    final exactZeroSign = Const(
        roundingMode == FloatingPointRoundingMode.roundTowardsNegativeInfinity);
    final signNPath = mux(
            ~validLeadOneNPath,
            exactZeroSign,
            mux(significandSubtractorNPathSignFlopped, smallerSignFlopped,
                largerSignFlopped))
        .named('signNpath');
    final nPathRounder = FloatingPointRounder.fromGRS(
        retainedLsb: mux(notSubnormalNPath, shiftedSignificandNPathFull[1],
            significandNPathFlopped[2]),
        guard: mux(notSubnormalNPath, shiftedSignificandNPathFull[0],
            significandNPathFlopped[1]),
        roundBit: mux(notSubnormalNPath, Const(0), significandNPathFlopped[0]),
        roundingMode: roundingMode,
        sign: signNPath);
    final finalSignificandP1NPath = ParallelPrefixIncr(finalSignificandNPath,
            ppGen: ppTree, name: 'npath_round_increment')
        .out
        .named('finalSignificandP1Npath');
    final roundCarryNPath = (nPathRounder.doRound & finalSignificandNPath.and())
        .named('roundCarryNpath');
    final roundedSignificandNPath = mux(nPathRounder.doRound,
            finalSignificandP1NPath, finalSignificandNPath)
        .named('roundedSignificandNpath');
    final exponentP1NPath = ParallelPrefixIncr(exponentNPath,
            ppGen: ppTree, name: 'npath_exponent_increment')
        .out;
    final roundedExponentNPath =
        mux(roundCarryNPath, exponentP1NPath, exponentNPath)
            .named('roundedExponentNpath');

    final isR = (deltaFlopped.gte(Const(2, width: delta.width)) |
            ~effectiveSubtractionFlopped)
        .named('isR');
    final inf = internalSum.inf(sign: largerSignFlopped);
    final largestFinite = internalSum
        .valuePopulator()
        .ofConstant(FloatingPointConstants.largestNormal);
    final maxFiniteExponent = Const(largestFinite.exponent);
    final maxFiniteMantissa = Const(largestFinite.mantissa);
    final outputMantissaRPath = mantissaRPath.slice(mantissaRPath.width - 2, 1);
    final finiteOverflowRPath = (exponentOverflowRPath |
            exponentRPath.gt(maxFiniteExponent) |
            (exponentRPath.eq(maxFiniteExponent) &
                outputMantissaRPath.gt(maxFiniteMantissa)))
        .named('finiteOverflowRpath');
    final exponentOverflowNPath =
        (roundCarryNPath & exponentNPath.and()).named('exponentOverflowNpath');
    final finiteOverflowNPath = (exponentOverflowNPath |
            roundedExponentNPath.gt(maxFiniteExponent) |
            (roundedExponentNPath.eq(maxFiniteExponent) &
                roundedSignificandNPath.gt(maxFiniteMantissa)))
        .named('finiteOverflowNpath');
    final overflowToInfinity = switch (roundingMode) {
      FloatingPointRoundingMode.roundNearestEven ||
      FloatingPointRoundingMode.roundNearestTiesAway =>
        Const(1),
      FloatingPointRoundingMode.truncate ||
      FloatingPointRoundingMode.roundTowardsZero =>
        Const(0),
      FloatingPointRoundingMode.roundTowardsInfinity => ~largerSignFlopped,
      FloatingPointRoundingMode.roundTowardsNegativeInfinity =>
        largerSignFlopped,
    };
    final outSubNormalAsZero =
        internalSum.subNormalAsZero ? Const(1) : Const(0);
    final selectedExponent = mux(isR, exponentRPath, roundedExponentNPath);
    final finiteOverflow = (mux(isR, finiteOverflowRPath, finiteOverflowNPath) &
            ~isInfFlopped &
            ~isNaNFlopped)
        .named('finiteOverflow');
    final rPathInexact = mux(selectRPath, sumP1InexactRPath, sumInexactRPath)
        .named('rPathInexact');
    final operationInexact =
        mux(isR, rPathInexact, nPathRounder.inexact).named('operationInexact');
    internalStatus.invalid <= invalidOperationFlopped;
    internalStatus.divideByZero <= Const(0);
    internalStatus.overflow <= finiteOverflow;
    internalStatus.underflow <=
        ~selectedExponent.or() & operationInexact & ~isNaNFlopped;
    internalStatus.inexact <= finiteOverflow | operationInexact;

    Combinational([
      If(isNaNFlopped, then: [
        internalSum.sign <
            mux(inputIsNaNFlopped, nanSignFlopped, internalSum.nan.sign),
        internalSum.exponent < internalSum.nan.exponent,
        internalSum.mantissa <
            mux(inputIsNaNFlopped, nanMantissaFlopped,
                internalSum.nan.mantissa),
      ], orElse: [
        If(isInfFlopped, then: [
          internalSum < internalSum.inf(sign: largerSignFlopped),
        ], orElse: [
          If(isR, then: [
            If(finiteOverflowRPath & overflowToInfinity, then: [
              internalSum < inf,
            ], orElse: [
              If(finiteOverflowRPath, then: [
                internalSum <
                    internalSum.largestFinite(sign: largerSignFlopped),
              ], orElse: [
                internalSum.sign < largerSignFlopped,
                internalSum.exponent < exponentRPath,
                internalSum.mantissa <
                    mux(
                        outSubNormalAsZero & ~exponentRPath.or(),
                        Const(0, width: internalSum.mantissa.width),
                        mantissaRPath.slice(mantissaRPath.width - 2, 1)),
              ])
            ]),
          ], orElse: [
            If(finiteOverflowNPath & overflowToInfinity, then: [
              internalSum < inf,
            ], orElse: [
              If(finiteOverflowNPath, then: [
                internalSum < internalSum.largestFinite(sign: signNPath),
              ], orElse: [
                internalSum.sign < signNPath,
                internalSum.exponent < roundedExponentNPath,
                internalSum.mantissa <
                    mux(
                        outSubNormalAsZero & ~roundedExponentNPath.or(),
                        Const(0, width: roundedSignificandNPath.width),
                        roundedSignificandNPath),
              ])
            ]),
          ])
        ])
      ])
    ]);
  }
}
