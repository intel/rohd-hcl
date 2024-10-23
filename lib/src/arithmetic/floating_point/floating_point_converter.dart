// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_converter.dart
// A Floating-point format converter component.
//
// 2024 August 30
// Author: Xue Zheng Saw <xue.zheng.saw@intel.com> (Alan)

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

    Logic normalizedExponent =
        Logic(name: 'normalizedExponent', width: destExponentWidth);
    Logic normalizedMantissa =
        Logic(name: 'normalizedMantissa', width: destMantissaWidth);

    normalizedExponent < _normalizeSubnormalExponent();
    normalizedMantissa < _normalizeSubnormalMantissa();

    final normalizedFP = FloatingPoint(
        exponentWidth: destExponentWidth, mantissaWidth: destMantissaWidth);

    normalizedFP.sign <= source.sign;
    normalizedFP.exponent <= normalizedExponent;
    normalizedFP.mantissa <= normalizedMantissa;

    Combinational([
      If.block([
        Iff(source.isNaN(), [
          _result < _handleNaN(source, destExponentWidth, destMantissaWidth),
        ]),
        Iff(source.isInfinity(), [
          _result <
              _handleInfinity(source, destExponentWidth, destMantissaWidth),
        ]),
        Iff(source.isZero(), [
          _result < _handleZero(source, destExponentWidth, destMantissaWidth),
        ]),
        Iff(source.isSubnormal() | source.isNormal(), [
          _result <
              mux(
                  source.isNormal(),
                  convertNormalNumber(
                      source: source,
                      destExponentWidth: destExponentWidth,
                      destMantissaWidth: destMantissaWidth),
                  normalizedFP),
        ]),
      ]),
      _result.sign < source.sign
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
      packZero(
          source: sourceFP,
          destExponentWidth: destExponentWidth,
          destMantissaWidth: destMantissaWidth);

  /// Convert a normal [FloatingPoint] number to a new format.
  ///
  /// The output [FloatingPoint] has the given [destExponentWidth] and
  /// [destMantissaWidth].
  ///
  /// The [source] is a normal [FloatingPoint] number.
  ///
  /// The output [FloatingPoint] is computed as follows:
  ///
  /// 1. The exponent is adjusted according to the given [destExponentWidth].
  /// 2. The mantissa is adjusted according to the given [destMantissaWidth] and
  ///    the rounding mode [FloatingPointRoundingMode.roundNearestEven].
  /// 3. If the exponent is all ones, the output [FloatingPoint] is an infinity
  ///    with the same sign as the [source].
  /// 4. If the exponent is all zeros, the output [FloatingPoint] is a zero with
  ///    the same sign as the [source].
  /// 5. Otherwise, the output [FloatingPoint] is the result of the adjusted
  ///    exponent and the adjusted mantissa.
  static FloatingPoint convertNormalNumber(
      {required FloatingPoint source,
      required int destExponentWidth,
      required int destMantissaWidth}) {
    final adjustedExponent = adjustExponent(source.exponent, destExponentWidth);

    final adjustedMantissa =
        Logic(name: 'adjustedMantissa', width: destMantissaWidth);

    adjustedMantissa <=
        adjustMantissaPrecision(source.mantissa, destMantissaWidth,
            Const(FloatingPointRoundingMode.roundNearestEven.index));

    final isOverflow = adjustedExponent
        .gte(FloatingPointValue.computeMaxExponent(destExponentWidth));
    final isUnderflow = adjustedExponent.lte(0);

    final packNormal = FloatingPoint(
        exponentWidth: destExponentWidth, mantissaWidth: destMantissaWidth);

    Combinational([
      If.block([
        Iff(isOverflow, [
          packNormal <
              handleOverflow(
                  source: source,
                  destExponentWidth: destExponentWidth,
                  destMantissaWidth: destMantissaWidth),
        ]),
        ElseIf(isUnderflow, [
          packNormal <
              handleUnderflow(
                  source: source,
                  destExponentWidth: destExponentWidth,
                  destMantissaWidth: destMantissaWidth),
        ]),
        Else([
          packNormal.sign < source.sign.value,
          packNormal.exponent < adjustedExponent.value,
          packNormal.mantissa < adjustedMantissa.value
        ])
      ]),
    ]);

    return packNormal;
  }

  Logic _normalizeSubnormalExponent() =>
      Const(0, width: destExponentWidth, fill: true);
  Logic _normalizeSubnormalMantissa() =>
      Const(0, width: destMantissaWidth, fill: true);

  static FloatingPoint handleOverflow(
          {required FloatingPoint source,
          required int destExponentWidth,
          required int destMantissaWidth}) =>
      packInfinity(
          source: source,
          destExponentWidth: destExponentWidth,
          destMantissaWidth: destMantissaWidth,
          isNaN: false);

  static FloatingPoint handleUnderflow(
          {required FloatingPoint source,
          required int destExponentWidth,
          required int destMantissaWidth}) =>
      packZero(
          source: source,
          destExponentWidth: destExponentWidth,
          destMantissaWidth: destMantissaWidth);

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
  static FloatingPoint packSpecial(
      {required FloatingPoint source,
      required int destExponentWidth,
      required int destMantissaWidth,
      required bool isNaN}) {
    final pack = FloatingPoint(
        exponentWidth: destExponentWidth, mantissaWidth: destMantissaWidth);

    pack.exponent <= Const(1, width: destExponentWidth, fill: true);

    if (isNaN) {
      pack.mantissa <=
          Const(1, width: destMantissaWidth, fill: true) <<
              (destMantissaWidth - 1);
    } else {
      pack.mantissa <= Const(0, width: destMantissaWidth, fill: true);
    }

    return pack;
  }

  static FloatingPoint packZero(
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

  static FloatingPoint packInfinity(
          {required FloatingPoint source,
          required int destExponentWidth,
          required int destMantissaWidth,
          required bool isNaN}) =>
      packSpecial(
          source: source,
          destExponentWidth: destExponentWidth,
          destMantissaWidth: destMantissaWidth,
          isNaN: false);

  /// Adjust the exponent of a floating-point number to fit the new exponent width.
  ///
  /// The exponent is biased according to the source and destination exponent widths.
  /// If the exponent widths are the same, the exponent is returned unchanged.
  static Logic adjustExponent(Logic sourceExponent, int destExponentWidth) {
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

  /// Adjust the mantissa of a floating-point number to fit the new mantissa width.
  ///
  /// If the mantissa width is increased, the mantissa is zero-extended.
  /// If the mantissa width is decreased, the mantissa is rounded according to the
  /// given rounding mode.
  /// If the mantissa widths are the same, the mantissa is returned unchanged.
  static Logic adjustMantissaPrecision(
      Logic sourceMantissa, int destMantissaWidth, Logic roundingMode) {
    final adjustedMantissa =
        Logic(name: 'adjustedMantissa', width: destMantissaWidth);

    // In the case where precision is increased, we just need to zero pad or shift the source mantissa bits
    if (destMantissaWidth > sourceMantissa.width) {
      adjustedMantissa <=
          sourceMantissa.zeroExtend(destMantissaWidth) <<
              (destMantissaWidth - sourceMantissa.width);
    } else if (destMantissaWidth < sourceMantissa.width) {
      adjustedMantissa <=
          roundMantissa(sourceMantissa, destMantissaWidth, roundingMode);
    } else {
      adjustedMantissa <= sourceMantissa;
    }

    return adjustedMantissa;
  }

  /// Rounds a mantissa to a target width.
  ///
  /// The mantissa is rounded according to the given [roundingMode].
  /// If the mantissa width is increased, the mantissa is zero-extended.
  /// If the mantissa width is decreased, the mantissa is rounded according to the
  /// given [roundingMode].
  /// If the mantissa widths are the same, the mantissa is returned unchanged.
  ///
  /// [roundingMode] is a [Logic] value that represents the rounding mode to use.
  /// The value should be one of the following:
  ///   - [FloatingPointRoundingMode.truncate.index] to truncate the mantissa.
  ///   - [FloatingPointRoundingMode.roundNearestEven.index] to round the mantissa
  ///     to the nearest even value.
  ///   - [FloatingPointRoundingMode.roundTowardsZero.index] to round the mantissa
  ///     towards zero.
  ///   - [FloatingPointRoundingMode.roundTowardsInfinity.index] to round the
  ///     mantissa towards positive infinity.
  ///   - [FloatingPointRoundingMode.roundTowardsNegativeInfinity.index] to round
  ///     the mantissa towards negative infinity.
  ///   - [FloatingPointRoundingMode.roundNearestTiesAway.index] to round the
  ///     mantissa to the nearest value, rounding away from zero in case of a tie.
  static Logic roundMantissa(
      Logic sourceMantissa, int destMantissaWidth, Logic roundingMode) {
    if (sourceMantissa.width <= destMantissaWidth) {
      throw StateError(
          'Cannot round a mantissa to a width that is not smaller.');
    }
    // First figure out what is the significant number to round to
    // Note that we are assuming that sourceMantissa.width > destMantissaWidth here

    // Significant number = desMantissaWidth
    // The number of bits to throw away or round = sourceMantissa.width - destMantissaWidth

    final significantNumber = destMantissaWidth;
    final numberOfBitsToThrowAway = sourceMantissa.width - destMantissaWidth;

    final throwAwayBits = sourceMantissa.slice(numberOfBitsToThrowAway - 1, 0);
    final significantBits =
        sourceMantissa.slice(sourceMantissa.width - 1, numberOfBitsToThrowAway);

    // Use the throw away bits to calculate whether to round up or down
    // if the most significant bit of the guardbits is 0, just truncate
    // if the most significant bit of the guardbits is 1, and there is at least one bit in the rest, then round up
    // if the most significant bit of the guardbits is 1, and there is not at least one bit in the rest, check the least significant bit in the mantissa, if it is 1 round up, else truncate

    // Truncate if MSB Guard bit is 0
    // or when MSB Guard bit is 1 and LSB of mantissa is 0
    final atLeastOneBitInGuardBits =
        throwAwayBits.slice(throwAwayBits.width - 2, 0).or();
    final truncateCondition = throwAwayBits[-1].eq(0) |
        (throwAwayBits[-1].eq(1) &
            ~atLeastOneBitInGuardBits &
            significantBits[0].eq(0));
    final roundCondition = throwAwayBits[-1].eq(1) &
        (atLeastOneBitInGuardBits |
            (~atLeastOneBitInGuardBits & significantBits[0].eq(1)));

    final result = Logic(name: 'roundedMantissa', width: destMantissaWidth);

    final truncatedResult = significantBits;
    final roundedResult = significantBits + 1;

    Combinational([
      If.block([
        Iff(roundingMode.eq(FloatingPointRoundingMode.roundNearestEven.index), [
          result < mux(roundCondition, roundedResult, truncatedResult),
        ]),
        ElseIf(roundingMode.eq(FloatingPointRoundingMode.truncate.index), [
          result < truncatedResult,
        ]),
        ElseIf(
            roundingMode.eq(FloatingPointRoundingMode.roundTowardsZero.index), [
          result < truncatedResult, // TODO: Implement round towards zero
        ]),
        ElseIf(
            roundingMode
                .eq(FloatingPointRoundingMode.roundTowardsInfinity.index),
            [
              result < truncatedResult, // TODO: Implement
            ]),
        ElseIf(
            roundingMode.eq(
                FloatingPointRoundingMode.roundTowardsNegativeInfinity.index),
            [
              result < truncatedResult, // TODO: Implement
            ]),
        ElseIf(
            roundingMode
                .eq(FloatingPointRoundingMode.roundNearestTiesAway.index),
            [
              result < truncatedResult, // TODO: Implement
            ]),
        Else([result < truncatedResult])
      ])
    ]);

    return result;
  }
}
