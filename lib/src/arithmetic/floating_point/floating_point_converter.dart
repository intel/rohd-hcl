// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_converter.dart
// A Floating-point format converter component.
//
// 2024 August 30
// Author: AI Assistant

import 'dart:ffi';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A converter module for FloatingPoint values
class FloatingPointConverter extends Module {
  /// Source exponent width
  final int sourceExponentWidth;

  /// Source mantissa width
  final int sourceMantissaWidth;

  /// Destination exponent width
  final int destExponentWidth;

  /// Destination mantissa width
  final int destMantissaWidth;

  /// Output [FloatingPoint] computed
  late final FloatingPoint result = FloatingPoint(
      exponentWidth: destExponentWidth, mantissaWidth: destMantissaWidth)
    ..gets(output('result'));

  /// The result of [FloatingPoint] conversion
  @protected
  late final FloatingPoint _result = FloatingPoint(
      exponentWidth: destExponentWidth, mantissaWidth: destMantissaWidth);

  /// Convert a floating point number from one format to another
  FloatingPointConverter(FloatingPoint source,
      {required this.destExponentWidth,
      required this.destMantissaWidth,
      super.name})
      : sourceExponentWidth = source.exponent.width,
        sourceMantissaWidth = source.mantissa.width {
    source = source.clone()
      ..gets(addInput('source', source, width: source.width));
    addOutput('result', width: _result.width) <= _result;

    // Handle sign
    _result.sign <= source.sign;

    Logic normalizedExponent =
        Logic(name: 'normalizedExponent', width: destExponentWidth);
    Logic normalizedMantissa =
        Logic(name: 'normalizedMantissa', width: destMantissaWidth);

    normalizedExponent < _normalizeSubnormalExponent();
    normalizedMantissa < _normalizeSubnormalMantissa();

    final normalizedFP = FloatingPoint(exponentWidth: destExponentWidth, mantissaWidth: destMantissaWidth);
    
    normalizedFP.sign <= source.sign;
    normalizedFP.exponent <= normalizedExponent;
    normalizedFP.mantissa <= normalizedMantissa;

    If.block([
      Iff(source.isNaN(), [
        _result < _handleNaN(source, destExponentWidth, destMantissaWidth),
      ]),
      Iff(source.isInfinity(), [
        _result < _handleInfinity(source, destExponentWidth, destMantissaWidth),
      ]),
      Iff(source.isZero(), [
        _result < _handleZero(source, destExponentWidth, destMantissaWidth),
      ]),
      Iff(source.isSubnormal() | source.isNormal(), [
        _result <
            mux(
                source.isNormal(),
                _convertNormalNumber(
                    source: source,
                    destExponentWidth: destExponentWidth,
                    destMantissaWidth: destMantissaWidth),
                normalizedFP),
      ]),
    ]);
  }

  /// Handle the case where the [sourceFP] is a NaN.
  ///
  /// The resulting [FloatingPoint] is a NaN with the same sign as the [sourceFP].
  ///
  /// [destExponentWidth] and [destMantissaWidth] are the widths of the exponent and
  /// mantissa of the destination [FloatingPoint] respectively.
  FloatingPoint _handleNaN(FloatingPoint sourceFP, int destExponentWidth,
          int destMantissaWidth) =>
      packSpecial(
          source: sourceFP,
          destExponentWidth: destExponentWidth,
          destMantissaWidth: destMantissaWidth,
          isNaN: true);

  FloatingPoint _handleInfinity(FloatingPoint sourceFP, int destExponentWidth,
          int destMantissaWidth) =>
      packSpecial(
          source: sourceFP,
          destExponentWidth: destExponentWidth,
          destMantissaWidth: destMantissaWidth,
          isNaN: false);

  FloatingPoint _handleZero(FloatingPoint sourceFP, int destExponentWidth,
          int destMantissaWidth) =>
      _packZero(
          source: sourceFP,
          destExponentWidth: destExponentWidth,
          destMantissaWidth: destMantissaWidth);

  FloatingPoint _convertNormalNumber(
      {required FloatingPoint source,
      required int destExponentWidth,
      required int destMantissaWidth}) {
    final adjustedExponent =
        _adjustExponent(source.exponent, destExponentWidth);

    final adjustedMantissa =
        Logic(name: 'adjustedMantissa', width: destMantissaWidth);

    adjustedMantissa <
        _adjustMantissaPrecision(source.mantissa, destMantissaWidth,
            FloatingPointRoundingMode.roundNearestEven);

    final isOverflow = adjustedExponent
        .gte(FloatingPointValue.computeMaxExponent(destExponentWidth));
    final isUnderflow = adjustedExponent.lte(0);

    final packNormal = FloatingPoint(
        exponentWidth: destExponentWidth, mantissaWidth: destMantissaWidth);

    If.block([
      Iff(isOverflow, [
        packNormal <
            _handleOverflow(
                source: source,
                destExponentWidth: destExponentWidth,
                destMantissaWidth: destMantissaWidth),
      ]),
      ElseIf(isUnderflow, [
        packNormal < _handleUnderflow(),
      ]),
      Else([
        packNormal <
            FloatingPointValue(
              sign: source.sign.value,
              exponent: adjustedExponent.value,
              mantissa: adjustedMantissa.value,
            )
      ]),
    ]);

    return packNormal;
  }

  Logic _normalizeSubnormalExponent() =>
      Const(0, width: destExponentWidth, fill: true);
  Logic _normalizeSubnormalMantissa() =>
      Const(0, width: destMantissaWidth, fill: true);

  FloatingPoint _handleOverflow(
          {required FloatingPoint source,
          required int destExponentWidth,
          required int destMantissaWidth}) =>
      _packInfinity(
          source: source,
          destExponentWidth: destExponentWidth,
          destMantissaWidth: destMantissaWidth,
          isNaN: false);

  FloatingPoint _handleUnderflow() =>
      FloatingPoint(exponentWidth: 0, mantissaWidth: 0);

  /// Pack a special floating point number into a target.
  ///
  /// The target [FloatingPoint] is modified to represent the given special
  /// number. The exponent is set to all ones, the sign is set to the given [sign]
  /// value, and the mantissa is set to all zeros for an infinity or all ones for
  /// a NaN.
  ///
  /// [sign] is the sign bit of the special number.
  ///
  /// [isNaN] is true if the special number is a NaN, false if it is an infinity.
  @visibleForTesting
  FloatingPoint packSpecial(
      {required FloatingPoint source,
      required int destExponentWidth,
      required int destMantissaWidth,
      required bool isNaN}) {
    final pack = FloatingPoint(
        exponentWidth: destExponentWidth, mantissaWidth: destMantissaWidth);

    pack.exponent <= Const(1, width: destExponentWidth, fill: true);

    if (isNaN) {
      pack.mantissa <= Const(1, width: destMantissaWidth, fill: true) << (destMantissaWidth - 1);
    } else {
      pack.mantissa <= Const(0, width: destMantissaWidth, fill: true);
    }

    return pack;
  }

  FloatingPoint _packZero(
      {required FloatingPoint source,
      required int destExponentWidth,
      required int destMantissaWidth}) {
    final pack = FloatingPoint(
        exponentWidth: destExponentWidth, mantissaWidth: destMantissaWidth);

    pack.exponent <= Const(0, width: destExponentWidth, fill: true);
    pack.mantissa <= Const(0, width: destMantissaWidth, fill: true);
    pack.sign <= source.sign;
    return pack;
  }

  FloatingPoint _packInfinity(
          {required FloatingPoint source,
          required int destExponentWidth,
          required int destMantissaWidth,
          required bool isNaN}) =>
      packSpecial(
          source: source,
          destExponentWidth: destExponentWidth,
          destMantissaWidth: destMantissaWidth,
          isNaN: false);

  Logic _adjustExponent(Logic sourceExponent, int destExponentWidth) {
    if (sourceExponent.width == destExponentWidth) {
      return sourceExponent;
    } else {
      final sourceBias = FloatingPointValue.computeBias(sourceExponent.width);
      final destBias = FloatingPointValue.computeBias(destExponentWidth);

      final biasedExponent =
          Logic(name: 'biasedExponent', width: destExponentWidth);
      biasedExponent <= sourceExponent - (sourceBias + destBias);
      return biasedExponent;
    }
  }

  Logic _adjustMantissaPrecision(Logic sourceMantissa, int destMantissaWidth,
      FloatingPointRoundingMode roundingMode) {
    final adjustedMantissa =
        Logic(name: 'adjustedMantissa', width: destMantissaWidth);

    // In the case where precision is increased, we just need to zero pad or shift the source mantissa bits
    if (destMantissaWidth > sourceMantissa.width) {
      adjustedMantissa <=
          sourceMantissa << (destMantissaWidth - sourceMantissa.width);
    } else if (destMantissaWidth < sourceMantissa.width) {
      adjustedMantissa <=
          _roundMantissa(sourceMantissa, destMantissaWidth, roundingMode);
    } else {
      adjustedMantissa <= sourceMantissa;
    }

    return adjustedMantissa;
  }

  Logic _roundMantissa(Logic sourceMantissa, int destMantissaWidth,
      FloatingPointRoundingMode roundingMode) {
    final shift = sourceMantissa.width - destMantissaWidth;
    final roundBit = Const(1, width: sourceMantissa.width) << (shift - 1);
    final mask = roundBit - 1;
    final roundCondition = (sourceMantissa & roundBit) &
        ((sourceMantissa & mask) | (roundBit << 1));

    final roundedMantissa = (sourceMantissa + roundBit) & ~(roundBit - 1);
    final shiftedMantissa = roundedMantissa >> shift;

    final result = Logic(name: 'roundedMantissa', width: destMantissaWidth);
    result <= mux(roundCondition, roundedMantissa, shiftedMantissa);

    // TODO : Add If block for rounding modes

    return result;
  }
}
