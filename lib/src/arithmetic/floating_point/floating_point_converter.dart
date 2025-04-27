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

/// A converter module for FloatingPoint values
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
              {bool outputValid, String name})
          priorityGen = RecursiveModulePriorityEncoder.new,
      Adder Function(Logic a, Logic b, {Logic? carryIn}) adderGen =
          NativeAdder.new,
      super.name})
      : sourceExponentWidth = source.exponent.width,
        sourceMantissaWidth = source.mantissa.width,
        super(
            definitionName: 'FloatingPointConverter_${source.runtimeType}_'
                '${destination.runtimeType}') {
    destExponentWidth = destination.exponent.width;
    destMantissaWidth = destination.mantissa.width;
    source = (source.clone(name: 'source') as FpTypeIn)
      ..gets(addInput('source', source, width: source.width));
    addOutput('destination', width: _destination.width) <= _destination;
    destination <= output('destination');

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
            outputValid: true, name: 'lead_one_encoder');
        final leadOnePre = leadOneEncoder.out;
        leadOneValid = leadOneEncoder.valid!;
        leadOne =
            mux(leadOneValid, leadOnePre.zeroExtend(maxExpWidth), biasDiff)
                .named('leadOne');

        fullDiff = mux(
            Const(source.explicitJBit),
            biasDiff +
                source.exponent.zeroExtend(biasDiff.width) +
                mux(~source.isNormal & Const(source.explicitJBit),
                    Const(1, width: maxExpWidth), Const(0, width: maxExpWidth)),
            biasDiff);
        shift = mux(fullDiff.gte(leadOne) & leadOneValid, leadOne, fullDiff)
            .named('shift');
      } else {
        biasDiff = Const(0, width: maxExpWidth);
        fullDiff = Const(0, width: maxExpWidth);
        leadOne = Const(0, width: maxExpWidth);
        leadOneValid = Const(0);
        shift = Const(0, width: maxExpWidth);
      }

      final trueShift = shift +
          mux(
              Const(destination.explicitJBit) &
                  source.isNormal &
                  ~Const(source.explicitJBit),
              Const(-1, width: maxExpWidth),
              Const(0, width: maxExpWidth));

      final newMantissa = mux(trueShift[-1], mantissa >> (~trueShift + 1),
              mantissa << trueShift)
          .named('mantissaShift');

      final Logic roundedMantissa;
      final Logic roundIncExp;
      if (destMantissaWidth < source.mantissa.width) {
        final rounder =
            RoundRNE(newMantissa, source.mantissa.width - destMantissaWidth);

        final roundAdder = adderGen(
            newMantissa.reversed.getRange(1, destMantissaWidth + 1).reversed,
            rounder.doRound.zeroExtend(destMantissaWidth));
        roundedMantissa = roundAdder.sum
            .named('roundedMantissa')
            .getRange(0, destMantissaWidth);
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
                ].swizzle().named('clippedMantissa')
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
        preExponent =
            mux(shift.gt(Const(0, width: shift.width)), predictSub, predictExp)
                    .named('unRndDestExponent') +
                roundIncExp.zeroExtend(predictSub.width).named('rndIncExp');
      } else {
        preExponent = se + roundIncExp.zeroExtend(se.width).named('rndIncExp');
      }
      destExponent =
          preExponent.getRange(0, destExponentWidth).named('destExponent');
    } else {
      // Wide to Narrow exponent
      final biasDiff = (sBias - dBias).named('biasDiff');

      final leadOneEncoder = priorityGen(mantissa.reversed,
          outputValid: true, name: 'lead_one_encoder');
      final leadOnePre = leadOneEncoder.out;
      final leadOneValid = leadOneEncoder.valid!;
      final leadOne =
          mux(leadOneValid, leadOnePre.zeroExtend(maxExpWidth), biasDiff)
              .named('leadOne');

      final seW = se.zeroExtend(maxExpWidth);
      final newSe = mux(
          leadOneValid & Const(source.explicitJBit) & source.isNormal,
          mux(seW.gte(leadOne), seW - (leadOne - Const(1, width: maxExpWidth)),
              Const(0, width: maxExpWidth)),
          seW);

      final nextShift = mux(
          biasDiff.gte(newSe),
          (source.isNormal.zeroExtend(maxExpWidth).named('srcIsNormal') +
                  (biasDiff - newSe).named('negSourceRebiased'))
              .named('shiftSubnormal'),
          Const(0, width: maxExpWidth));

      final tns = nextShift -
          (se - newSe) +
          mux(Const(source.explicitJBit), Const(-1, width: maxExpWidth),
              Const(0, width: maxExpWidth)) +
          mux(Const(destination.explicitJBit), Const(1, width: maxExpWidth),
              Const(0, width: maxExpWidth));

      final fullMantissa = [mantissa, Const(0, width: destMantissaWidth + 2)]
          .swizzle()
          .named('fullMantissa');

      final shiftMantissa =
          mux(tns[-1], fullMantissa << ~tns + 1, fullMantissa >>> tns)
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
              (newSe - biasDiff).named('sourceRebiased'))
          .named('predictExponent');

      destExponent = (predictEN + roundIncExp.zeroExtend(predictEN.width))
          .named('predictExpRounded')
          .getRange(0, destExponentWidth);

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
