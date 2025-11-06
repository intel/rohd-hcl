// Copyright (C) 2025 Intel Corporation
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

  /// The result of [FloatingPoint] conversion
  @protected
  late final FpTypeOut _destination =
      destination.clone(name: 'destination') as FpTypeOut;

  /// Convert a [FloatingPoint] logic structure from one format to another.
  /// - [source] is the source format [FloatingPoint] logic structure.
  /// - [destination] is the destination format [FloatingPoint] logic
  /// structure.
  /// - [priorityGen] is a [PriorityEncoder] generator to be used in the
  /// leading one detection (default [RecursiveModulePriorityEncoder]).
  /// - [adderGen] can specify the [Adder] to use for exponent calculations.
  FloatingPointConverter(FpTypeIn source, this.destination,
      {PriorityEncoder Function(Logic bitVector,
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
                    'SM${source.exponent.width}_'
                    'DE${destination.exponent.width}_'
                    'DM${destination.exponent.width}') {
    if (source.subNormalAsZero) {
      throw ArgumentError(
          'FloatingPointConverter does not support denormal as zero (DAZ)');
    }
    if (destination.subNormalAsZero) {
      throw ArgumentError(
          'FloatingPointConverter does not support flush to zero (FTZ)');
    }
    destExponentWidth = destination.exponent.width;
    destMantissaWidth = destination.mantissa.width;
    source = (source.clone(name: 'source') as FpTypeIn)
      ..gets(addTypedInput('source', source));

    final destOut = addTypedOutput('destination',
        _destination.clone as FpTypeOut Function({String? name}));
    destOut <= _destination;
    destination <= destOut;

    // maxExpWidth: mantissa +2:
    //     1 for the hidden jbit and 1 for going past with leadingOneDetect
    final maxExpWidth = [
      source.exponent.width,
      destExponentWidth,
      log2Ceil(source.mantissa.width + 2),
      log2Ceil(destMantissaWidth + 2)
    ].reduce(max);
    final sBias = source.bias.zeroExtend(maxExpWidth).named('sourceBias');
    final dBias = destination.bias.zeroExtend(maxExpWidth).named('destBias');
    final se = source.exponent.zeroExtend(maxExpWidth).named('sourceExp');
    final mantissa = [
      source.isNormal & ~Const(source.explicitJBit),
      source.mantissa
    ].swizzle().named('mantissa');

    final nan = source.isNaN;
    final Logic infinity;
    final Logic destExponent;
    final Logic destMantissa;
    final Logic biasDiff;
    final Logic fullDiff;
    final Logic leadOne;
    final Logic leadOneValid;
    final Logic shift;

    if (destExponentWidth >= source.exponent.width) {
      // Narrow to Wide
      infinity = source.isAnInfinity;

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
                    source.exponent.zeroExtend(biasDiff.width) +
                    (~source.isNormal & Const(source.explicitJBit))
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
                      source.isNormal)
                  .replicate(maxExpWidth))
          .named('trueShift');

      final newMantissa = mux(trueShift[-1], mantissa >> (~trueShift + 1),
              mantissa << trueShift)
          .named('mantissaShift');

      final Logic roundedMantissa;
      final Logic roundIncExp;
      if (destMantissaWidth < source.mantissa.width) {
        final rounder =
            RoundRNE(newMantissa, source.mantissa.width - destMantissaWidth);

        final roundAdder = adderGen(
            newMantissa.slice(newMantissa.width - 2,
                newMantissa.width - destMantissaWidth - 1),
            rounder.doRound.zeroExtend(destMantissaWidth));
        roundedMantissa = roundAdder.sum
            .getRange(0, destMantissaWidth)
            .named('roundedMantissa');
        roundIncExp = roundAdder.sum[-1];
      } else {
        roundedMantissa = newMantissa;
        roundIncExp = Const(0);
      }
      final sliceMantissa = mux(
          (Const(source.explicitJBit) | ~source.isNormal) &
              Const(destination.explicitJBit),
          newMantissa.slice(-1, 1),
          newMantissa.slice(-2, 0));

      destMantissa = ((destMantissaWidth >= source.mantissa.width)
              ? [
                  sliceMantissa,
                  Const(0, width: destMantissaWidth - newMantissa.width + 1)
                ].swizzle()
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
              leadOneValid & Const(source.explicitJBit) & source.isNormal,
              mux(
                  se.gte(leadOne),
                  se - (leadOne - Const(1, width: maxExpWidth)),
                  Const(0, width: maxExpWidth)),
              se)
          .named('newExponent');

      final nextShift = mux(
              biasDiff.gte(newSe),
              source.isNormal.zeroExtend(maxExpWidth) + (biasDiff - newSe),
              Const(0, width: maxExpWidth))
          .named('nextShift');

      final jBitAdjust =
          (Const((source.explicitJBit ? -1 : 0), width: maxExpWidth) +
                  Const(destination.explicitJBit ? 1 : 0, width: maxExpWidth))
              .named('jBitAdjust');

      final tns = (nextShift - (se - newSe) + jBitAdjust).named('tns');

      final fullMantissa = [mantissa, Const(0, width: destMantissaWidth + 2)]
          .swizzle()
          .named('fullMantissa');

      final shiftMantissa =
          mux(tns[-1], fullMantissa << (~tns + 1), fullMantissa >>> tns)
              .named('shiftMantissa');

      final rounder =
          RoundRNE(shiftMantissa, fullMantissa.width - destMantissaWidth - 1);

      final postPredRndMantissa = shiftMantissa
          .slice(-2, shiftMantissa.width - destMantissaWidth - 1)
          .named('preRndMantissa');

      final roundAdder = adderGen(
          postPredRndMantissa,
          [Const(0, width: destMantissaWidth - 1), rounder.doRound]
              .swizzle()
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

      infinity = source.isAnInfinity |
          (newSe.gt(biasDiff) & (newSe - biasDiff).gt(maxDestExp)) |
          destExponent.zeroExtend(maxDestExp.width).gt(maxDestExp);
    }
    Combinational([
      If.block([
        Iff(nan, [
          _destination <
              FloatingPoint(
                      exponentWidth: destExponentWidth,
                      mantissaWidth: destMantissaWidth)
                  .nan,
        ]),
        ElseIf(infinity, [
          _destination <
              FloatingPoint(
                      exponentWidth: destExponentWidth,
                      mantissaWidth: destMantissaWidth)
                  .inf(sign: source.sign),
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
