// Copyright (C) 2025-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_converter.dart
// A Floating-point to floating-point arbitrary width converter.
//
// 2025 January 28 2025
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/arithmetic/floating_point/explicit_j_bit_canonicalization.dart';

/// A converter module between different [FloatingPoint] logic signals.
class FloatingPointConverter<FpTypeIn extends FloatingPoint,
    FpTypeOut extends FloatingPoint> extends Module {
  /// Source exponent width
  final int sourceExponentWidth;

  /// Source mantissa width
  final int sourceMantissaWidth;

  /// Destination exponent width
  late final int destExponentWidth;

  /// Destination mantissa width
  late final int destMantissaWidth;

  /// Output [FloatingPoint] computed
  final FpTypeOut destination;

  /// IEEE 754 exception status for this conversion.
  late final FloatingPointStatus status;

  /// Internal exception status.
  late final FloatingPointStatus _status;

  /// The result of [FloatingPoint] conversion
  @protected
  late final FpTypeOut _destination =
      destination.cloneTyped(name: 'destination');

  /// Convert a [FloatingPoint] logic structure from one format to another.
  /// - [source] is the source format [FloatingPoint] logic structure.
  /// - [destination] is the destination format [FloatingPoint] logic
  /// structure.
  /// - [roundingMode] selects how discarded precision and finite overflow are
  /// rounded.
  /// - [priorityGen] is a [PriorityEncoder] generator to be used in the
  /// leading one detection (default [RecursiveModulePriorityEncoder]).
  /// - [adderGen] can specify the [Adder] to use for exponent calculations.
  /// - [alignExplicitJBit] canonicalizes explicit-J-bit inputs before
  /// conversion, including unnormalized and noncanonical zero encodings.
  /// Aligned explicit-J sources require IEEE infinity and signaling-NaN
  /// encodings and at least two exponent bits; explicit-J destinations
  /// additionally require a fraction bit and IEEE special values.
  FloatingPointConverter(FpTypeIn source, this.destination,
      {FloatingPointRoundingMode roundingMode =
          FloatingPointRoundingMode.roundNearestEven,
      bool alignExplicitJBit = false,
      PriorityEncoder Function(Logic bitVector,
              {bool generateValid, String name})
          priorityGen = RecursiveModulePriorityEncoder.new,
      Adder Function(Logic a, Logic b, {Logic? carryIn}) adderGen =
          NativeAdder.new,
      super.name = 'floating_point_converter',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : sourceExponentWidth = source.exponent.width,
        sourceMantissaWidth = source.mantissa.width,
        super(
          definitionName: definitionName ??
              'FloatingPointConverter_'
                  'SE${source.exponent.width}_'
                  'SM${source.mantissa.width}_'
                  'SJ${source.explicitJBit ? 1 : 0}_'
                  'DE${destination.exponent.width}_'
                  'DM${destination.mantissa.width}_'
                  'DJ${destination.explicitJBit ? 1 : 0}_'
                  'R${roundingMode.name}'
                  '${alignExplicitJBit && source.explicitJBit ? '_A1' : ''}',
        ) {
    if (source.subNormalAsZero) {
      throw ArgumentError(
          'FloatingPointConverter does not support denormal as zero (DAZ)');
    }
    if (destination.subNormalAsZero) {
      throw ArgumentError(
          'FloatingPointConverter does not support flush to zero (FTZ)');
    }
    if (alignExplicitJBit && source.explicitJBit) {
      if (!source.supportsInfinities || !source.supportsSignalingNaNs) {
        throw ArgumentError(
            'Aligned explicit-J conversion requires IEEE special values.');
      }
      if (destination.explicitJBit &&
          (destination.mantissa.width < 2 ||
              !destination.supportsInfinities ||
              !destination.supportsSignalingNaNs)) {
        throw ArgumentError('Aligned conversion to an explicit-J format '
            'requires a fraction bit and IEEE special values.');
      }
    }
    destExponentWidth = destination.exponent.width;
    destMantissaWidth = destination.mantissa.width;
    source = addTypedInput('source', source);

    final destOut = addTypedOutput('destination', _destination.cloneTyped);
    destOut <= _destination;
    destination <= destOut;
    _status = FloatingPointStatus(name: 'internalStatus');
    status = addTypedOutput('status', _status.clone);
    status <= _status;

    final calculationSource = alignExplicitJBit && source.explicitJBit
        ? canonicalizeExplicitJBit(source, priorityGen: priorityGen)
        : source;
    if (alignExplicitJBit &&
        source.explicitJBit &&
        !destination.explicitJBit &&
        destination.supportsInfinities &&
        destination.supportsSignalingNaNs &&
        destExponentWidth == source.exponent.width &&
        destMantissaWidth == source.mantissa.width - 1) {
      _status.invalid <= source.isSignalingNaN;
      _status.divideByZero <= Const(0);
      _status.overflow <= Const(0);
      _status.underflow <= Const(0);
      _status.inexact <= Const(0);
      Combinational([
        If.block([
          Iff(source.isNaN, [
            _destination < _destination.quietNaNFrom(source),
          ]),
          ElseIf(source.isAnInfinity, [
            _destination < _destination.inf(sign: source.sign),
          ]),
          Else([
            _destination.sign < calculationSource.sign,
            _destination.exponent < calculationSource.exponent,
            _destination.mantissa <
                calculationSource.mantissa.getRange(0, destMantissaWidth),
          ]),
        ]),
      ]);
      return;
    }

    if (alignExplicitJBit && source.explicitJBit) {
      final implicitSource = FloatingPoint(
        exponentWidth: source.exponent.width,
        mantissaWidth: source.mantissa.width - 1,
        name: 'canonical_implicit_source',
      );
      implicitSource.sign <= calculationSource.sign;
      implicitSource.exponent <= calculationSource.exponent;
      implicitSource.mantissa <=
          calculationSource.mantissa.getRange(0, source.mantissa.width - 1);
      final implicitDestination = destination.explicitJBit
          ? FloatingPoint(
              exponentWidth: destExponentWidth,
              mantissaWidth: destMantissaWidth - 1,
              name: 'implicit_destination',
            )
          : destination.clone(name: 'implicit_destination');
      final converter = FloatingPointConverter(
        implicitSource,
        implicitDestination,
        roundingMode: roundingMode,
        priorityGen: priorityGen,
        adderGen: adderGen,
      );
      _status.invalid <= source.isSignalingNaN;
      _status.divideByZero <= converter.status.divideByZero;
      _status.overflow <= converter.status.overflow;
      _status.underflow <= converter.status.underflow;
      _status.inexact <= converter.status.inexact;
      if (destination.explicitJBit) {
        Combinational([
          If.block([
            Iff(source.isNaN, [
              _destination < _destination.quietNaNFrom(source),
            ]),
            ElseIf(source.isAnInfinity, [
              _destination < _destination.inf(sign: source.sign),
            ]),
            Else([
              _destination.sign < implicitDestination.sign,
              _destination.exponent < implicitDestination.exponent,
              _destination.mantissa <
                  [
                    implicitDestination.exponent.or(),
                    implicitDestination.mantissa,
                  ].concat(),
            ]),
          ]),
        ]);
      } else {
        _destination <= implicitDestination;
      }
      return;
    }

    // maxExpWidth: mantissa +2:
    //     1 for the hidden jbit and 1 for going past with leadingOneDetect
    final maxExpWidth = [
      source.exponent.width,
      destExponentWidth,
      (source.mantissa.width + 2).log2Ceil,
      (destMantissaWidth + 2).log2Ceil
    ].reduce(max);
    final sBias =
        calculationSource.bias.zeroExtend(maxExpWidth).named('sourceBias');
    final dBias = destination.bias.zeroExtend(maxExpWidth).named('destBias');
    final se =
        calculationSource.exponent.zeroExtend(maxExpWidth).named('sourceExp');
    final mantissa = [
      calculationSource.isNormal & ~Const(calculationSource.explicitJBit),
      calculationSource.mantissa
    ].concat().named('mantissa');

    final nan = source.isNaN;
    final Logic overflow;
    final Logic destExponent;
    final Logic destMantissa;
    final Logic biasDiff;
    final Logic fullDiff;
    final Logic leadOne;
    final Logic leadOneValid;
    final Logic shift;
    final Logic roundingInexact;

    if (destExponentWidth >= source.exponent.width) {
      // Narrow to Wide
      if (destExponentWidth > source.exponent.width) {
        biasDiff = (dBias - sBias).named('biasDiff');

        final leadOneEncoder = priorityGen(mantissa.reversed,
            generateValid: true, name: 'lead_one_encoder');
        final leadOnePre = leadOneEncoder.out;
        leadOneValid = leadOneEncoder.valid!;
        leadOne =
            mux(leadOneValid, leadOnePre.zeroExtend(maxExpWidth), biasDiff)
                .named('leadOne');

        fullDiff = mux(
                Const(source.explicitJBit),
                biasDiff +
                    calculationSource.exponent.zeroExtend(biasDiff.width) +
                    (~calculationSource.isNormal & Const(source.explicitJBit))
                        .zeroExtend(maxExpWidth),
                biasDiff)
            .named('fullDiff');

        shift = mux(fullDiff.gte(leadOne) & leadOneValid, leadOne, fullDiff)
            .named('shift');
      } else {
        biasDiff = Const(0, width: maxExpWidth);
        fullDiff = Const(0, width: maxExpWidth);
        leadOne = Const(0, width: maxExpWidth);
        leadOneValid = Const(0);
        shift = Const(0, width: maxExpWidth);
      }

      final trueShift = (shift +
              (Const(destination.explicitJBit & !source.explicitJBit) &
                      calculationSource.isNormal)
                  .replicate(maxExpWidth))
          .named('trueShift');

      final newMantissa = mux(trueShift[-1], mantissa >> (~trueShift + 1),
              mantissa << trueShift)
          .named('mantissaShift');

      // Whether the shift above actually promoted a real leading bit into
      // the topmost position of [newMantissa] (a full left-shift
      // normalization landing exactly on the leading one), as opposed to
      // that position still holding a placeholder or freshly shifted-in
      // fill bit. This must check the final [trueShift] (not just [shift]),
      // since the destination j-bit adjustment folded into [trueShift] can
      // turn what would be a promoting left-shift into a net right-shift.
      // When the destination doesn't store an explicit j-bit, any promoted
      // bit is implicit and must still be dropped from the stored mantissa,
      // matching the placeholder case.
      final topBitMeaningful = (leadOneValid &
              ~trueShift[-1] &
              trueShift.eq(leadOne) &
              Const(destination.explicitJBit))
          .named('topBitMeaningful');

      final Logic roundedMantissa;
      final Logic roundIncExp;
      if (destMantissaWidth < source.mantissa.width) {
        // The retained/rounded window shifts up by one bit position when
        // the topmost bit of [newMantissa] is meaningful (see
        // [topBitMeaningful]) versus when it is just a placeholder; compute
        // both statically-sized variants and select the right one at
        // runtime, since the window bounds must be compile-time constants.
        final rounderPlaceholderTop = FloatingPointRounder(
            newMantissa, source.mantissa.width - destMantissaWidth,
            roundingMode: roundingMode, sign: source.sign);
        final roundAdderPlaceholderTop = adderGen(
            newMantissa.slice(newMantissa.width - 2,
                newMantissa.width - destMantissaWidth - 1),
            rounderPlaceholderTop.doRound.zeroExtend(destMantissaWidth));

        final rounderRealTop = FloatingPointRounder(
            newMantissa, newMantissa.width - destMantissaWidth,
            roundingMode: roundingMode, sign: source.sign);
        final roundAdderRealTop = adderGen(
            newMantissa.slice(
                newMantissa.width - 1, newMantissa.width - destMantissaWidth),
            rounderRealTop.doRound.zeroExtend(destMantissaWidth));

        roundingInexact = mux(topBitMeaningful, rounderRealTop.inexact,
                rounderPlaceholderTop.inexact)
            .named('roundingInexact');
        final roundAdderSum = mux(topBitMeaningful, roundAdderRealTop.sum,
                roundAdderPlaceholderTop.sum)
            .named('roundAdderSum');
        roundedMantissa = roundAdderSum
            .getRange(0, destMantissaWidth)
            .named('roundedMantissa');
        roundIncExp = roundAdderSum[-1];
      } else {
        roundedMantissa = newMantissa;
        roundIncExp = Const(0);
        roundingInexact = Const(0);
      }
      final sliceMantissa = mux(
          topBitMeaningful, newMantissa.slice(-1, 1), newMantissa.slice(-2, 0));

      destMantissa = ((destMantissaWidth >= source.mantissa.width)
              ? [
                  sliceMantissa,
                  Const(0, width: destMantissaWidth - newMantissa.width + 1)
                ].concat()
              : roundedMantissa)
          .named('destMantissa');

      final Logic preExponent;
      if (destExponentWidth > source.exponent.width) {
        final predictExp = (se + biasDiff).named('predictExp');
        final predictSub = mux(
                fullDiff.gte(leadOne) & leadOneValid,
                fullDiff - (leadOne - Const(1, width: leadOne.width)),
                fullDiff - shift)
            .named('predictSubExp');
        preExponent = mux(shift.gt(Const(0, width: shift.width)), predictSub,
                predictExp) +
            roundIncExp.zeroExtend(predictSub.width);
      } else {
        preExponent = se + roundIncExp.zeroExtend(se.width).named('rndIncExp');
      }
      destExponent =
          preExponent.getRange(0, destExponentWidth).named('destExponent');

      final largestFinite = destination
          .valuePopulator()
          .ofConstant(FloatingPointConstants.largestNormal);
      final maxDestExp = Const(largestFinite.exponent, width: maxExpWidth);
      final maxDestMantissa = Const(largestFinite.mantissa);
      overflow = destExponent.zeroExtend(maxExpWidth).gt(maxDestExp) |
          (destExponent.zeroExtend(maxExpWidth).eq(maxDestExp) &
              destMantissa.gt(maxDestMantissa));
    } else {
      // Wide to Narrow exponent
      final biasDiff = (sBias - dBias).named('biasDiff');

      final leadOneEncoder = priorityGen(mantissa.reversed,
          generateValid: true, name: 'lead_one_encoder');
      final leadOnePre = leadOneEncoder.out;
      final leadOneValid = leadOneEncoder.valid!;
      final leadOne =
          mux(leadOneValid, leadOnePre.zeroExtend(maxExpWidth), biasDiff)
              .named('leadOne');

      final newSe = mux(
              leadOneValid &
                  Const(source.explicitJBit) &
                  calculationSource.isNormal,
              mux(
                  se.gte(leadOne),
                  se - (leadOne - Const(1, width: maxExpWidth)),
                  Const(0, width: maxExpWidth)),
              se)
          .named('newExponent');

      final nextShift = mux(
              biasDiff.gte(newSe),
              calculationSource.isNormal.zeroExtend(maxExpWidth) +
                  (biasDiff - newSe),
              Const(0, width: maxExpWidth))
          .named('nextShift');

      final jBitAdjust =
          (Const((source.explicitJBit ? -1 : 0), width: maxExpWidth) +
                  Const(destination.explicitJBit ? 1 : 0, width: maxExpWidth))
              .named('jBitAdjust');

      final tns = (nextShift - (se - newSe) + jBitAdjust).named('tns');

      final fullMantissa = [mantissa, Const(0, width: destMantissaWidth + 2)]
          .concat()
          .named('fullMantissa');

      final shiftMantissa =
          mux(tns[-1], fullMantissa << (~tns + 1), fullMantissa >>> tns)
              .named('shiftMantissa');

      final shiftedOutSticky =
          (~tns[-1] & fullMantissa.neq(shiftMantissa << tns))
              .named('shiftedOutSticky');

      final rounder = FloatingPointRounder(
          shiftMantissa, fullMantissa.width - destMantissaWidth - 1,
          roundingMode: roundingMode,
          sign: source.sign,
          extraSticky: shiftedOutSticky);
      roundingInexact = rounder.inexact;

      final postPredRndMantissa = shiftMantissa
          .slice(-2, shiftMantissa.width - destMantissaWidth - 1)
          .named('preRndMantissa');

      final roundAdder = adderGen(
          postPredRndMantissa,
          [Const(0, width: destMantissaWidth - 1), rounder.doRound]
              .concat()
              .named('rndIncrement'));
      final roundIncExp = roundAdder.sum[-1];
      final rawMantissa = roundAdder.sum;

      final newSlice = roundIncExp & Const(destination.explicitJBit);

      final sliceMantissa =
          mux(newSlice, rawMantissa.slice(-1, 1), rawMantissa.slice(-2, 0));

      destMantissa = sliceMantissa.getRange(0, destMantissaWidth);

      final predictEN = mux(biasDiff.gte(newSe), Const(0, width: maxExpWidth),
              newSe - biasDiff)
          .named('predictExponent');

      destExponent = (predictEN + roundIncExp.zeroExtend(predictEN.width))
          .getRange(0, destExponentWidth)
          .named('destExponent');

      final maxDestExp = Const(
          destination.floatingPointValue.maxExponent +
              destination.floatingPointValue.bias,
          width: maxExpWidth);
      final largestFinite = destination
          .valuePopulator()
          .ofConstant(FloatingPointConstants.largestNormal);
      final maxDestMantissa = Const(largestFinite.mantissa);

      overflow = (newSe.gt(biasDiff) & (newSe - biasDiff).gt(maxDestExp)) |
          destExponent.zeroExtend(maxDestExp.width).gt(maxDestExp) |
          (destExponent.zeroExtend(maxDestExp.width).eq(maxDestExp) &
              destMantissa.gt(maxDestMantissa));
    }
    final overflowToInfinity = switch (roundingMode) {
      FloatingPointRoundingMode.roundNearestEven ||
      FloatingPointRoundingMode.roundNearestTiesAway =>
        Const(1),
      FloatingPointRoundingMode.truncate ||
      FloatingPointRoundingMode.roundTowardsZero =>
        Const(0),
      FloatingPointRoundingMode.roundTowardsInfinity => ~source.sign,
      FloatingPointRoundingMode.roundTowardsNegativeInfinity => source.sign,
    };
    final finiteOverflow =
        (overflow & ~source.isAnInfinity & ~nan).named('finiteOverflow');
    final finiteRoundingInexact =
        (roundingInexact & ~source.isAnInfinity & ~nan)
            .named('finiteRoundingInexact');
    _status.invalid <= source.isSignalingNaN;
    _status.divideByZero <= Const(0);
    _status.overflow <= finiteOverflow;
    _status.underflow <= ~destExponent.or() & finiteRoundingInexact;
    _status.inexact <= finiteOverflow | finiteRoundingInexact;
    Combinational([
      If.block([
        Iff(nan, [
          _destination < _destination.quietNaNFrom(source),
        ]),
        ElseIf(source.isAnInfinity | (overflow & overflowToInfinity), [
          _destination < _destination.inf(sign: source.sign),
        ]),
        ElseIf(overflow, [
          _destination < _destination.largestFinite(sign: source.sign),
        ]),
        Else([
          _destination.sign < source.sign,
          _destination.exponent < destExponent,
          _destination.mantissa < destMantissa,
        ]),
      ]),
    ]);
  }
}
