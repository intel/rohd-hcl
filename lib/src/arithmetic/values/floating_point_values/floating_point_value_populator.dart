// Copyright (C) 2024-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_value_populator.dart
// Populator for Floating Point Values
//
// 2024 October 15
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

typedef _ExactDyadic = ({BigInt significand, int exponent});

/// A populator for [FloatingPointValue]s, a utility that can populate various
/// forms of [FloatingPointValue]s.
class FloatingPointValuePopulator<FpvType extends FloatingPointValue> {
  /// An unpopulated [FloatingPointValue] that this populator will populate.
  ///
  /// The `late final` variables will not yet be initialized until after this
  /// populator is used to [populate] it.
  final FpvType _unpopulated;

  /// The width of the exponent field.
  int get exponentWidth => _unpopulated.exponentWidth;

  /// The width of the mantissa field.
  int get mantissaWidth => _unpopulated.mantissaWidth;

  /// The bias of floating point value.
  int get bias => _unpopulated.bias;

  /// The minimum exponent value.
  int get minExponent => _unpopulated.minExponent;

  /// The maximum exponent value.
  int get maxExponent => _unpopulated.maxExponent;

  /// `true` if the format stores the Jbit explicitly.
  bool get explicitJBit => _unpopulated.explicitJBit;

  /// `true` if subnormal numbers are treated as zero.
  bool get subNormalAsZero => _unpopulated.subNormalAsZero;

  /// Whether or not this populator has already populated values.
  bool _hasPopulated = false;

  /// Creates a [FloatingPointValuePopulator] for the given [_unpopulated]
  /// [FloatingPointValue].
  FloatingPointValuePopulator(this._unpopulated);

  @override
  String toString() =>
      'FloatingPointValuePopulator<${_unpopulated.runtimeType}>';

  /// Populates the [FloatingPointValue] with the given [sign], [exponent], and
  /// [mantissa], then performs additional validation.
  FpvType populate(
      {required LogicValue sign,
      required LogicValue exponent,
      required LogicValue mantissa}) {
    if (_hasPopulated) {
      throw RohdHclException('FloatingPointPopulator: already populated');
    }
    _hasPopulated = true;

    return _unpopulated
      ..sign = sign
      ..exponent = exponent
      ..mantissa = mantissa
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_overriding_member
      ..validate();
  }

  /// This is a helper function to canonicalize the sign, exponent, and mantissa
  /// values for the [FloatingPointValue]. In the case of explicit j-bit, a
  /// normal number would have a leading one in the mantissa whereas for implict
  /// j-bit, no change would be needed.
  static ({
    LogicValue sign,
    LogicValue exponent,
    LogicValue mantissa
  }) _components(FloatingPointValue fpv, {required bool canonicalizeExplicit}) {
    var exponent = fpv.exponent;
    var mantissa = fpv.mantissa;
    var sign = fpv.sign;
    if (canonicalizeExplicit & (fpv.explicitJBit)) {
      var expVal = fpv.exponent.toInt();
      if (!fpv.isAnInfinity) {
        if (!fpv.isNaN) {
          if (mantissa.or() == LogicValue.one) {
            while ((mantissa[-1] == LogicValue.zero) & (expVal > 1)) {
              expVal--;
              mantissa = mantissa << 1;
            }
            if ((mantissa[-1] == LogicValue.zero) & (expVal == 1)) {
              // Make canonical: if it cannot be made normal, it is subnormal
              expVal = 0;
            } else if ((mantissa[-1] == LogicValue.one) & (expVal == 0)) {
              expVal = 1;
            }
          }
          exponent = LogicValue.ofInt(expVal, fpv.exponentWidth);
        } else {
          sign = LogicValue.zero;
          mantissa = LogicValue.ofInt(1, fpv.mantissa.width);
        }
      }
    }
    return (sign: sign, exponent: exponent, mantissa: mantissa);
  }

  /// Convert to from one [FloatingPointValue] to another, canonicalizing
  /// the mantissa as requested if the output [FloatingPointValue] has
  /// an explicit J bit.
  FloatingPointValue ofFloatingPointValue(FloatingPointValue fpv,
      {bool canonicalizeExplicit = false}) {
    final components = _components(fpv,
        canonicalizeExplicit:
            fpv.explicitJBit & (canonicalizeExplicit | !explicitJBit));
    if (exponentWidth != fpv.exponentWidth) {
      throw RohdHclException(
          'Cannot convert FloatingPointValue with exponent width '
          '${fpv.exponentWidth} to one with width $exponentWidth');
    }
    if (mantissaWidth - (explicitJBit ? 1 : 0) !=
        fpv.mantissaWidth - (fpv.explicitJBit ? 1 : 0)) {
      throw RohdHclException(
          'Cannot convert FloatingPointValue with mantissa width '
          '${fpv.mantissaWidth} to one with width $mantissaWidth');
    }

    final extendedMantissa = [
      if (fpv.isNormal() & !(fpv.isAnInfinity | fpv.isNaN))
        LogicValue.one
      else
        LogicValue.zero,
      components.mantissa
    ].swizzle();
    return FloatingPointValue(
        sign: components.sign,
        exponent: components.exponent,
        mantissa: (explicitJBit != fpv.explicitJBit)
            ? extendedMantissa.getRange(
                0,
                components.mantissa.width +
                    (explicitJBit ? 1 : 0) -
                    (fpv.explicitJBit ? 1 : 0))
            : components.mantissa,
        explicitjBit: explicitJBit);
  }

  /// Converts [fpv] directly to this format with one exact rounding step.
  ///
  /// Unlike [ofDouble], this method does not pass through the host
  /// floating-point format and therefore cannot introduce double rounding.
  FpvType ofFloatingPointValueRounded(FloatingPointValue fpv,
      {FloatingPointRoundingMode roundingMode =
          FloatingPointRoundingMode.roundNearestEven}) {
    if (fpv.isNaN) {
      return _quietNaNFrom(fpv);
    }
    if (fpv.isAnInfinity) {
      return _infinityOrLargestFinite(
          negative: fpv.sign.toBool(), roundingMode: roundingMode);
    }
    return _quantize(_decodeFinite(fpv),
        negative: fpv.sign.toBool(), roundingMode: roundingMode);
  }

  /// Constructs a value equal to [significand] times two to [exponent].
  ///
  /// The exact dyadic value is rounded once into this floating-point format.
  FpvType ofScaledBigInt(BigInt significand, int exponent,
          {FloatingPointRoundingMode roundingMode =
              FloatingPointRoundingMode.roundNearestEven}) =>
      _quantize((significand: significand.abs(), exponent: exponent),
          negative: significand.isNegative, roundingMode: roundingMode);

  /// Converts [fxv] directly into this floating-point format.
  ///
  /// The exact fixed-point value is rounded once according to [roundingMode].
  FpvType ofFixedPointValue(FixedPointValue fxv,
      {FloatingPointRoundingMode roundingMode =
          FloatingPointRoundingMode.roundNearestEven}) {
    final exact = fxv.toScaledBigInt();
    return ofScaledBigInt(exact.significand, exact.exponent,
        roundingMode: roundingMode);
  }

  /// Adds [a] and [b] exactly and rounds once into this format.
  FpvType add(FloatingPointValue a, FloatingPointValue b,
      {FloatingPointRoundingMode roundingMode =
          FloatingPointRoundingMode.roundNearestEven}) {
    if (a.isNaN | b.isNaN) {
      return _propagateNaN(a, b);
    }
    if (a.isAnInfinity | b.isAnInfinity) {
      if (a.isAnInfinity && b.isAnInfinity && a.sign != b.sign) {
        return nan;
      }
      final infinity = a.isAnInfinity ? a : b;
      return _infinityOrLargestFinite(
          negative: infinity.sign.toBool(), roundingMode: roundingMode);
    }

    final aExact = _decodeFinite(a);
    final bExact = _decodeFinite(b);
    final commonExponent = min(aExact.exponent, bExact.exponent);
    final aSigned =
        (a.sign.toBool() ? -aExact.significand : aExact.significand) <<
            (aExact.exponent - commonExponent);
    final bSigned =
        (b.sign.toBool() ? -bExact.significand : bExact.significand) <<
            (bExact.exponent - commonExponent);
    final sum = aSigned + bSigned;
    final sameSignZeros =
        a.isAZero && b.isAZero && a.sign.toBool() == b.sign.toBool();
    final negative = sum.isNegative ||
        (sum == BigInt.zero &&
            (sameSignZeros
                ? a.sign.toBool()
                : roundingMode ==
                    FloatingPointRoundingMode.roundTowardsNegativeInfinity));

    return _quantize((significand: sum.abs(), exponent: commonExponent),
        negative: negative, roundingMode: roundingMode);
  }

  /// Multiplies [a] and [b] exactly and rounds once into this format.
  FpvType multiply(FloatingPointValue a, FloatingPointValue b,
      {FloatingPointRoundingMode roundingMode =
          FloatingPointRoundingMode.roundNearestEven}) {
    if (a.isNaN | b.isNaN) {
      return _propagateNaN(a, b);
    }
    final negative = a.sign.toBool() != b.sign.toBool();
    if ((a.isAnInfinity && b.isAZero) || (b.isAnInfinity && a.isAZero)) {
      return nan;
    }
    if (a.isAnInfinity | b.isAnInfinity) {
      return _infinityOrLargestFinite(
          negative: negative, roundingMode: roundingMode);
    }

    final aExact = _decodeFinite(a);
    final bExact = _decodeFinite(b);
    return _quantize((
      significand: aExact.significand * bExact.significand,
      exponent: aExact.exponent + bExact.exponent
    ), negative: negative, roundingMode: roundingMode);
  }

  /// Divides [a] by [b] exactly (to sufficient precision) and rounds once
  /// into this format.
  ///
  /// [b] must be nonzero: callers are expected to handle infinity and
  /// zero-divisor special cases before calling this (as
  /// [FloatingPointValue.operator /] does). NaN operands are propagated
  /// correctly.
  FpvType divide(FloatingPointValue a, FloatingPointValue b,
      {FloatingPointRoundingMode roundingMode =
          FloatingPointRoundingMode.roundNearestEven}) {
    if (a.isNaN | b.isNaN) {
      return _propagateNaN(a, b);
    }
    final negative = a.sign.toBool() != b.sign.toBool();

    final aExact = _decodeFinite(a);
    final bExact = _decodeFinite(b);
    if (aExact.significand == BigInt.zero) {
      return _zero(negative);
    }

    // Compute the quotient's significand to at least `guardBits` bits more
    // precision than the target format needs, by left-shifting the
    // dividend before doing exact BigInt integer division. Shifting left
    // (never right) means no dividend precision is ever silently
    // discarded. Any nonzero remainder from the integer division is folded
    // into the quotient's LSB as a sticky bit -- a standard technique so
    // that information about further (unrepresented) nonzero low-order
    // bits isn't lost for tie-breaking during later rounding.
    final fractionWidth = mantissaWidth - (explicitJBit ? 1 : 0);
    final guardBits = fractionWidth + 4;
    final shiftAmount = max(
        0,
        bExact.significand.bitLength +
            guardBits -
            aExact.significand.bitLength);
    final shiftedDividend = aExact.significand << shiftAmount;
    var quotient = shiftedDividend ~/ bExact.significand;
    final remainder = shiftedDividend.remainder(bExact.significand);
    if (remainder != BigInt.zero) {
      quotient |= BigInt.one;
    }

    return _quantize((
      significand: quotient,
      exponent: aExact.exponent - bExact.exponent - shiftAmount,
    ), negative: negative, roundingMode: roundingMode);
  }

  /// Computes square root exactly and rounds once into this format.
  FpvType squareRoot(FloatingPointValue value,
      {FloatingPointRoundingMode roundingMode =
          FloatingPointRoundingMode.roundNearestEven}) {
    if (value.isNaN) {
      return _quietNaNFrom(value);
    }
    if (value.isAZero) {
      return _zero(value.sign.toBool());
    }
    if (value.sign.toBool()) {
      return nan;
    }
    if (value.isAnInfinity) {
      return _infinityOrLargestFinite(
          negative: false, roundingMode: roundingMode);
    }

    final exact = _decodeFinite(value);
    final floorLog2 = exact.significand.bitLength - 1 + exact.exponent;
    var resultExponent =
        floorLog2 >= 0 ? floorLog2 ~/ 2 : -((-floorLog2 + 1) ~/ 2);
    final isSubnormal = resultExponent < minExponent;
    if (isSubnormal) {
      resultExponent = minExponent;
    }

    final fractionWidth = mantissaWidth - (explicitJBit ? 1 : 0);
    final scaleExponent = exact.exponent + 2 * (fractionWidth - resultExponent);
    final BigInt truncated;
    final bool exactResult;
    final int midpointComparison;
    if (scaleExponent >= 0) {
      final scaledRadicand = exact.significand << scaleExponent;
      truncated = _integerSquareRoot(scaledRadicand);
      exactResult = truncated * truncated == scaledRadicand;
      final midpoint = (truncated << 1) + BigInt.one;
      midpointComparison = (scaledRadicand << 2).compareTo(midpoint * midpoint);
    } else {
      final denominatorShift = -scaleExponent;
      truncated = _integerSquareRoot(exact.significand >> denominatorShift);
      exactResult =
          (truncated * truncated) << denominatorShift == exact.significand;
      final midpoint = (truncated << 1) + BigInt.one;
      midpointComparison = (exact.significand << 2)
          .compareTo((midpoint * midpoint) << denominatorShift);
    }

    final increment = !exactResult &&
        switch (roundingMode) {
          FloatingPointRoundingMode.truncate ||
          FloatingPointRoundingMode.roundTowardsZero ||
          FloatingPointRoundingMode.roundTowardsNegativeInfinity =>
            false,
          FloatingPointRoundingMode.roundTowardsInfinity => true,
          FloatingPointRoundingMode.roundNearestTiesAway =>
            midpointComparison >= 0,
          FloatingPointRoundingMode.roundNearestEven =>
            midpointComparison > 0 ||
                (midpointComparison == 0 && truncated.isOdd),
        };
    final significand = increment ? truncated + BigInt.one : truncated;

    return _packRounded(significand, resultExponent,
        negative: false, wasSubnormal: isSubnormal, roundingMode: roundingMode);
  }

  static BigInt _integerSquareRoot(BigInt value) {
    if (value < BigInt.two) {
      return value;
    }
    var estimate = BigInt.one << ((value.bitLength + 1) ~/ 2);
    while (true) {
      final next = (estimate + value ~/ estimate) >> 1;
      if (next >= estimate) {
        return estimate;
      }
      estimate = next;
    }
  }

  FpvType _propagateNaN(FloatingPointValue a, FloatingPointValue b) {
    final source = a.isSignalingNaN
        ? a
        : b.isSignalingNaN
            ? b
            : a.isNaN
                ? a
                : b;
    return _quietNaNFrom(source);
  }

  FpvType _quietNaNFrom(FloatingPointValue source) {
    if (!_unpopulated.supportsSignalingNaNs) {
      final canonical = _unpopulated.clonePopulator().nan;
      return ofBigInts(
          canonical.exponent.toBigInt(), canonical.mantissa.toBigInt(),
          sign: source.sign.toBool());
    }
    final targetFractionWidth = mantissaWidth - (explicitJBit ? 1 : 0);
    final sourceFractionWidth =
        source.mantissaWidth - (source.explicitJBit ? 1 : 0);
    final targetPayloadWidth = max(0, targetFractionWidth - 1);
    final sourcePayloadWidth = max(0, sourceFractionWidth - 1);
    final sourcePayloadMask = sourcePayloadWidth == 0
        ? BigInt.zero
        : (BigInt.one << sourcePayloadWidth) - BigInt.one;
    final targetPayloadMask = targetPayloadWidth == 0
        ? BigInt.zero
        : (BigInt.one << targetPayloadWidth) - BigInt.one;
    final payload =
        source.mantissa.toBigInt() & sourcePayloadMask & targetPayloadMask;
    final quietMantissa =
        (explicitJBit ? BigInt.one << (mantissaWidth - 1) : BigInt.zero) |
            (BigInt.one << targetPayloadWidth) |
            payload;
    return ofBigInts((BigInt.one << exponentWidth) - BigInt.one, quietMantissa,
        sign: source.sign.toBool());
  }

  static _ExactDyadic _decodeFinite(FloatingPointValue value) {
    final exact = value.toScaledBigInt();
    return (significand: exact.significand.abs(), exponent: exact.exponent);
  }

  FpvType _quantize(_ExactDyadic exact,
      {required bool negative,
      required FloatingPointRoundingMode roundingMode}) {
    if (exact.significand == BigInt.zero) {
      return _zero(negative);
    }

    final fractionWidth = mantissaWidth - (explicitJBit ? 1 : 0);
    var resultExponent = exact.significand.bitLength - 1 + exact.exponent;

    final isSubnormal = resultExponent < minExponent;
    if (isSubnormal) {
      resultExponent = minExponent;
    }

    final rounded = _roundSignificand(exact,
        quantumExponent: resultExponent - fractionWidth,
        negative: negative,
        roundingMode: roundingMode);
    final significand = rounded;

    return _packRounded(significand, resultExponent,
        negative: negative,
        wasSubnormal: isSubnormal,
        roundingMode: roundingMode);
  }

  FpvType _packRounded(BigInt significand, int resultExponent,
      {required bool negative,
      required bool wasSubnormal,
      required FloatingPointRoundingMode roundingMode}) {
    final fractionWidth = mantissaWidth - (explicitJBit ? 1 : 0);
    if (wasSubnormal) {
      final smallestNormal = BigInt.one << fractionWidth;
      if (significand < smallestNormal) {
        if (subNormalAsZero) {
          return _zero(negative);
        }
        return populate(
            sign: LogicValue.ofBool(negative),
            exponent: LogicValue.zero.zeroExtend(exponentWidth),
            mantissa: LogicValue.ofBigInt(significand, mantissaWidth));
      }
    }

    final carryLimit = BigInt.one << (fractionWidth + 1);
    if (significand >= carryLimit) {
      significand >>= 1;
      resultExponent++;
    }
    if (resultExponent > maxExponent) {
      return _overflow(negative: negative, roundingMode: roundingMode);
    }

    final storedMantissa = explicitJBit
        ? significand
        : significand & ((BigInt.one << fractionWidth) - BigInt.one);
    final storedExponent = resultExponent + bias;
    final largest = _constantComponents(FloatingPointConstants.largestNormal);
    if (storedExponent > largest.exponent.toInt() ||
        (storedExponent == largest.exponent.toInt() &&
            storedMantissa > largest.mantissa.toBigInt())) {
      return _overflow(negative: negative, roundingMode: roundingMode);
    }

    return populate(
        sign: LogicValue.ofBool(negative),
        exponent: LogicValue.ofInt(storedExponent, exponentWidth),
        mantissa: LogicValue.ofBigInt(storedMantissa, mantissaWidth));
  }

  static BigInt _roundSignificand(_ExactDyadic exact,
      {required int quantumExponent,
      required bool negative,
      required FloatingPointRoundingMode roundingMode}) {
    final shift = exact.exponent - quantumExponent;
    if (shift >= 0) {
      return exact.significand << shift;
    }

    final signedSignificand = negative ? -exact.significand : exact.significand;
    return roundBigIntByPowerOfTwo(signedSignificand, -shift,
            roundingMode: roundingMode)
        .abs();
  }

  FpvType _overflow(
      {required bool negative,
      required FloatingPointRoundingMode roundingMode}) {
    final roundsToInfinity = switch (roundingMode) {
      FloatingPointRoundingMode.roundNearestEven ||
      FloatingPointRoundingMode.roundNearestTiesAway =>
        true,
      FloatingPointRoundingMode.roundTowardsInfinity => !negative,
      FloatingPointRoundingMode.roundTowardsNegativeInfinity => negative,
      FloatingPointRoundingMode.truncate ||
      FloatingPointRoundingMode.roundTowardsZero =>
        false,
    };
    return roundsToInfinity
        ? _infinityOrLargestFinite(
            negative: negative, roundingMode: roundingMode)
        : _largestFinite(negative);
  }

  FpvType _infinityOrLargestFinite(
      {required bool negative,
      required FloatingPointRoundingMode roundingMode}) {
    if (_unpopulated.supportsInfinities) {
      return ofConstant(negative
          ? FloatingPointConstants.negativeInfinity
          : FloatingPointConstants.positiveInfinity);
    }
    return _largestFinite(negative);
  }

  FpvType _largestFinite(bool negative) {
    final largest = ofConstant(FloatingPointConstants.largestNormal);
    return negative ? largest.negate() as FpvType : largest;
  }

  FpvType _zero(bool negative) => ofConstant(negative
      ? FloatingPointConstants.negativeZero
      : FloatingPointConstants.positiveZero);

  /// Extracts a [FloatingPointValue] from a [FloatingPoint]'s current `value`.
  FpvType ofFloatingPoint(FloatingPoint fp) => populate(
        sign: fp.sign.value,
        exponent: fp.exponent.value,
        mantissa: fp.mantissa.value,
      );

  /// Extracts a [FloatingPointValue] from a [FloatingPoint]'s `previousValue`.
  FpvType? ofFloatingPointPrevious(FloatingPoint fp) {
    final prevVal = fp.previousValue;
    if (prevVal == null) {
      return null;
    }

    return ofLogicValue(prevVal);
  }

  /// [FloatingPointValue] constructor from a binary string representation of
  /// individual bitfields
  FpvType ofBinaryStrings(String sign, String exponent, String mantissa) =>
      populate(
          sign: LogicValue.of(sign),
          exponent: LogicValue.of(exponent),
          mantissa: LogicValue.of(mantissa));

  /// [FloatingPointValue] constructor from a single binary string representing
  /// space-separated bitfields in the order of sign, exponent, mantissa.
  ///
  /// For example:
  /// ```dart
  /// //                    s e        m
  /// ofSpacedBinaryString('0 00000000 00000000000000000000000')
  /// ```
  FpvType ofSpacedBinaryString(String fp) {
    final split = fp.split(' ');
    return ofBinaryStrings(split[0], split[1], split[2]);
  }

  /// Helper function for extracting binary strings from a longer
  /// binary string and the known exponent and mantissa widths.
  static ({String sign, String exponent, String mantissa})
      _extractBinaryStrings(
          String fp, int exponentWidth, int mantissaWidth, int radix) {
    final binaryFp = LogicValue.ofBigInt(
            BigInt.parse(fp, radix: radix), exponentWidth + mantissaWidth + 1)
        .bitString;

    return (
      sign: binaryFp.substring(0, 1),
      exponent: binaryFp.substring(1, 1 + exponentWidth),
      mantissa: binaryFp.substring(
          1 + exponentWidth, 1 + exponentWidth + mantissaWidth)
    );
  }

  /// [FloatingPointValue] constructor from a radix-encoded string
  /// representation and the size of the exponent and mantissa
  FpvType ofString(String fp, {int radix = 2}) {
    final extracted =
        _extractBinaryStrings(fp, exponentWidth, mantissaWidth, radix);
    return ofBinaryStrings(
        extracted.sign, extracted.exponent, extracted.mantissa);
  }

  /// [FloatingPointValue] constructor from a set of [BigInt]s of the binary
  /// representation and the size of the exponent and mantissa
  FpvType ofBigInts(BigInt exponent, BigInt mantissa, {bool sign = false}) =>
      populate(
          sign: LogicValue.ofBigInt(sign ? BigInt.one : BigInt.zero, 1),
          exponent: LogicValue.ofBigInt(exponent, exponentWidth),
          mantissa: LogicValue.ofBigInt(mantissa, mantissaWidth));

  /// [FloatingPointValue] constructor from a set of [int]s of the binary
  /// representation and the size of the exponent and mantissa
  FpvType ofInts(int exponent, int mantissa, {bool sign = false}) => populate(
      sign: LogicValue.ofBigInt(sign ? BigInt.one : BigInt.zero, 1),
      exponent: LogicValue.ofBigInt(BigInt.from(exponent), exponentWidth),
      mantissa: LogicValue.ofBigInt(BigInt.from(mantissa), mantissaWidth));

  /// Construct a [FloatingPointValue] from a [LogicValue]
  FpvType ofLogicValue(LogicValue val) => populate(
        sign: val[-1],
        exponent: val.getRange(mantissaWidth, mantissaWidth + exponentWidth),
        mantissa: val.getRange(0, mantissaWidth),
      );

  /// Return the set of [LogicValue]s for a given [FloatingPointConstants] at a
  /// given [exponentWidth] and [mantissaWidth].
  ///
  /// This is a good function to override if constants behave specially in
  /// subclases.
  @protected
  ({LogicValue sign, LogicValue exponent, LogicValue mantissa})
      getConstantComponents(FloatingPointConstants constant) {
    final (
      String signStr,
      String exponentStr,
      String mantissaStr
    ) stringComponents;

    switch (constant) {
      // smallest possible number
      case FloatingPointConstants.negativeInfinity:
        stringComponents = ('1', '1' * exponentWidth, '0' * mantissaWidth);

      // -0.0
      case FloatingPointConstants.negativeZero:
        stringComponents = ('1', '0' * exponentWidth, '0' * mantissaWidth);

      // 0.0
      case FloatingPointConstants.positiveZero:
        stringComponents = ('0', '0' * exponentWidth, '0' * mantissaWidth);

      // Smallest possible number, most exponent negative, LSB set in mantissa
      case FloatingPointConstants.smallestPositiveSubnormal:
        stringComponents =
            ('0', '0' * exponentWidth, '${'0' * (mantissaWidth - 1)}1');

      // Largest possible subnormal, most negative exponent, mantissa all 1s
      case FloatingPointConstants.largestPositiveSubnormal:
        stringComponents = ('0', '0' * exponentWidth, '1' * mantissaWidth);

      // Smallest possible positive number, most negative exponent, mantissa 0
      case FloatingPointConstants.smallestPositiveNormal:
        stringComponents =
            ('0', '${'0' * (exponentWidth - 1)}1', '0' * mantissaWidth);

      // Largest number smaller than one
      case FloatingPointConstants.largestLessThanOne:
        stringComponents =
            ('0', '0${'1' * (exponentWidth - 2)}0', '1' * mantissaWidth);

      // The number '1.0'
      case FloatingPointConstants.one:
        stringComponents =
            ('0', '0${'1' * (exponentWidth - 1)}', '0' * mantissaWidth);

      // Smallest number greater than one
      case FloatingPointConstants.smallestLargerThanOne:
        stringComponents = (
          '0',
          '0${'1' * (exponentWidth - 2)}0',
          '${'0' * (mantissaWidth - 1)}1'
        );

      // Largest positive number, most positive exponent, full mantissa
      case FloatingPointConstants.largestNormal:
        stringComponents =
            ('0', '${'1' * (exponentWidth - 1)}0', '1' * mantissaWidth);

      // Largest possible number
      case FloatingPointConstants.positiveInfinity:
        stringComponents = ('0', '1' * exponentWidth, '0' * mantissaWidth);

      // Not a Number (NaN)
      case FloatingPointConstants.nan:
        stringComponents =
            ('0', '1' * exponentWidth, '1${'0' * (mantissaWidth - 1)}');
    }

    return (
      sign: LogicValue.of(stringComponents.$1),
      exponent: LogicValue.of(stringComponents.$2),
      mantissa: LogicValue.of(stringComponents.$3)
    );
  }

  ({
    LogicValue sign,
    LogicValue exponent,
    LogicValue mantissa
  }) _constantComponents(FloatingPointConstants constant) =>
      // ignore: invalid_use_of_visible_for_overriding_member, invalid_use_of_protected_member
      _unpopulated.getSpecialConstantComponents(constant) ??
      getConstantComponents(constant);

  /// Creates a new [FloatingPointValue] represented by the given
  /// [constantFloatingPoint].
  FpvType ofConstant(FloatingPointConstants constantFloatingPoint) {
    if (explicitJBit) {
      final implicit = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth - 1)
          .ofConstant(constantFloatingPoint);
      final explicitJBitValue =
          implicit.isNormal() || implicit.isAnInfinity || implicit.isNaN;
      return populate(
          sign: implicit.sign,
          exponent: implicit.exponent,
          mantissa: [LogicValue.ofBool(explicitJBitValue), implicit.mantissa]
              .swizzle());
    }
    final components = _constantComponents(constantFloatingPoint);

    return populate(
        sign: components.sign,
        exponent: components.exponent,
        mantissa: components.mantissa);
  }

  /// Creates a new [FloatingPointValue] representing
  /// [FloatingPointConstants.positiveInfinity].
  FpvType get positiveInfinity =>
      ofConstant(FloatingPointConstants.positiveInfinity);

  /// Creates a new [FloatingPointValue] representing
  /// [FloatingPointConstants.negativeInfinity].
  FpvType get negativeInfinity =>
      ofConstant(FloatingPointConstants.negativeInfinity);

  /// Creates a new [FloatingPointValue] representing
  /// [FloatingPointConstants.nan].
  FpvType get nan => ofConstant(FloatingPointConstants.nan);

  /// Creates a new [FloatingPointValue] representing
  /// [FloatingPointConstants.one].
  FpvType get one => ofConstant(FloatingPointConstants.one);

  /// Creates a new [FloatingPointValue] representing
  /// [FloatingPointConstants.positiveZero].
  FpvType get positiveZero => ofConstant(FloatingPointConstants.positiveZero);

  /// Creates a new [FloatingPointValue] representing
  /// [FloatingPointConstants.negativeZero].
  FpvType get negativeZero => ofConstant(FloatingPointConstants.negativeZero);

  /// Convert from double using its native binary representation.
  ///
  /// The input [inDouble] is decoded bit-exactly (no precision is lost in
  /// that step, since a Dart [double] is itself an IEEE 754 binary64 value)
  /// and then rounded exactly once into this format using [roundingMode],
  /// via the same exact rounding engine used by [add], [multiply],
  /// [squareRoot], and [ofFloatingPointValueRounded]. All
  /// [FloatingPointRoundingMode]s are supported.
  FpvType ofDouble(double inDouble,
      {FloatingPointRoundingMode roundingMode =
          FloatingPointRoundingMode.roundNearestEven}) {
    if (inDouble.isNaN) {
      return nan;
    }
    if (inDouble.isInfinite) {
      return _infinityOrLargestFinite(
          negative: inDouble < 0.0, roundingMode: roundingMode);
    }

    final fp64 = FloatingPoint64Value.populator().ofDouble(inDouble);
    return _quantize(_decodeFinite(fp64),
        negative: fp64.sign.toBool(), roundingMode: roundingMode);
  }

  /// Convert from double using its native binary representation.
  ///
  /// This is the original hand-rolled guard/round/sticky implementation of
  /// [ofDouble], retained temporarily for reference and back-compatibility
  /// comparisons. It only supports [FloatingPointRoundingMode.roundNearestEven]
  /// and [FloatingPointRoundingMode.truncate], and has a known bug for
  /// formats close to the width of the native double (not enough bits of
  /// space to hold the guard, round, and sticky bits).
  @Deprecated('Use ofDouble instead, which supports all rounding modes '
      'and fixes a rounding bug for formats close to double width.')
  FpvType ofDoubleLegacy(double inDouble,
      {FloatingPointRoundingMode roundingMode =
          FloatingPointRoundingMode.roundNearestEven}) {
    if (explicitJBit) {
      return ofFloatingPointValue(FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth - 1)
          .ofDoubleLegacy(inDouble, roundingMode: roundingMode)) as FpvType;
    }
    if (inDouble.isNaN) {
      return nan;
    }

    if (inDouble.isInfinite) {
      return ofConstant(
        inDouble < 0.0
            ? FloatingPointConstants.negativeInfinity
            : FloatingPointConstants.positiveInfinity,
      );
    }

    if (roundingMode != FloatingPointRoundingMode.roundNearestEven &&
        roundingMode != FloatingPointRoundingMode.truncate) {
      throw UnimplementedError(
          'Only roundNearestEven or truncate is supported for this width');
    }

    final fp64 = FloatingPoint64Value.populator().ofDouble(inDouble);
    final fp64Mw = fp64.mantissa.width;
    final exponent64 = fp64.exponent;

    var expVal = (exponent64.toInt() - fp64.bias) + bias;
    final mantissa64n = ((expVal <= 0)
        ? [LogicValue.one, fp64.mantissa].swizzle() >>>
            (-expVal +
                (!explicitJBit & (fp64.exponent.toInt() > 0)
                    ? 1
                    : explicitJBit
                        ? 1
                        : 0))
        : [LogicValue.one, fp64.mantissa].swizzle());

    var mantissa = mantissa64n.slice(fp64Mw - (explicitJBit ? 0 : 1),
        fp64Mw - mantissaWidth + (explicitJBit ? 1 : 0));

    if (roundingMode == FloatingPointRoundingMode.roundNearestEven) {
      final stickyPos = fp64Mw - (mantissaWidth + 3);
      final sticky =
          (stickyPos >= 0) ? mantissa64n.slice(stickyPos, 0).or() : 0;
      final roundPos = stickyPos + 1;
      final round = ((roundPos >= 0) & (roundPos > stickyPos))
          ? mantissa64n[roundPos]
          : 0;
      final guardPos = roundPos + 1;
      final guard = (guardPos >= 1) ? mantissa64n[roundPos + 1] : 0;

      // RNE Rounding
      if (guard == LogicValue.one) {
        if ((round == LogicValue.one) |
            (sticky == LogicValue.one) |
            (mantissa[0] == LogicValue.one)) {
          mantissa += 1;
          if (mantissa == LogicValue.zero.zeroExtend(mantissa.width)) {
            expVal += 1;
            if (explicitJBit) {
              mantissa = [
                LogicValue.one,
                LogicValue.zero.zeroExtend(mantissa.width - 1)
              ].swizzle();
            }
          }
        }
      }
    }

    if (_unpopulated.supportsInfinities && expVal > maxExponent + bias) {
      return ofConstant(
        fp64.sign.toBool()
            ? FloatingPointConstants.negativeInfinity
            : FloatingPointConstants.positiveInfinity,
      );
    }

    final exponent =
        LogicValue.ofBigInt(BigInt.from(max(expVal, 0)), exponentWidth);

    if (subNormalAsZero && expVal <= 0) {
      // If we are subnormal, we return zero
      mantissa = LogicValue.zero.zeroExtend(mantissaWidth);
    }

    final sign = fp64.sign;

    return populate(
      sign: sign,
      exponent: exponent,
      mantissa: mantissa,
    );
  }

  /// Convert a floating point number into a [FloatingPointValue]
  /// representation. This form performs NO ROUNDING.
  @internal
  FpvType ofDoubleUnrounded(double inDouble) {
    if (explicitJBit) {
      return ofFloatingPointValue(FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth - 1)
          .ofDoubleUnrounded(inDouble)) as FpvType;
    }
    if (inDouble.isNaN) {
      return ofConstant(FloatingPointConstants.nan);
    }

    var doubleVal = inDouble;
    LogicValue sign;
    if (inDouble < 0.0) {
      doubleVal = -doubleVal;
      sign = LogicValue.one;
    } else {
      sign = LogicValue.zero;
    }
    if (inDouble.isInfinite) {
      return ofConstant(
        sign.toBool()
            ? FloatingPointConstants.negativeInfinity
            : FloatingPointConstants.positiveInfinity,
      );
    }

    // If we are dealing with a really small number we need to scale it up
    var scaleToWhole = (doubleVal != 0) ? (-log(doubleVal) / log(2)).ceil() : 0;

    if (doubleVal < 1.0) {
      var myCnt = 0;
      var myVal = doubleVal;
      while (myVal % 1 != 0.0) {
        myVal = myVal * 2.0;
        myCnt++;
      }
      if (myCnt < scaleToWhole) {
        scaleToWhole = myCnt;
      }
    }

    // Scale it up to go beyond the mantissa and include the GRS bits
    final scale = mantissaWidth + scaleToWhole;
    var s = scale;

    var sVal = doubleVal;
    if (s > 0) {
      while (s > 0) {
        sVal *= 2.0;
        s = s - 1;
      }
    } else {
      sVal = doubleVal * pow(2.0, scale);
    }

    final scaledValue = BigInt.from(sVal);
    final fullLength = scaledValue.bitLength;

    var fullValue = LogicValue.ofBigInt(scaledValue, fullLength);
    var e = (fullLength > 0)
        ? fullLength - mantissaWidth - scaleToWhole
        : minExponent;

    if (e <= -bias) {
      fullValue = fullValue >>> (scaleToWhole - bias);
      e = -bias;
    } else {
      // Could be just one away from subnormal
      e -= 1;
      if (e > -bias) {
        fullValue = fullValue << 1; // Chop the first '1'
      }
    }

    if (e > maxExponent) {
      return ofConstant(sign.toBool()
          ? FloatingPointConstants.negativeInfinity
          : FloatingPointConstants.positiveInfinity);
    }
    // We reverse so that we fit into a shorter BigInt, we keep the MSB.
    // The conversion fills leftward.
    // We reverse again after conversion.
    final exponent = LogicValue.ofInt(e + bias, exponentWidth);
    final mantissa = (subNormalAsZero && e + bias <= 0)
        ? LogicValue.zero.zeroExtend(mantissaWidth)
        : LogicValue.ofBigInt(fullValue.reversed.toBigInt(), mantissaWidth)
            .reversed;

    return populate(
      exponent: exponent,
      mantissa: mantissa,
      sign: sign,
    );
  }

  /// Helper routine to ensure FP constraint numbers match the type of FP we are
  /// trying to generate in random().
  void _checkMatching(String name, FpvType? fpv) {
    if (fpv != null) {
      if ((fpv.exponentWidth != exponentWidth) |
          (fpv.mantissaWidth != mantissaWidth) |
          (fpv.explicitJBit != explicitJBit)) {
        throw RohdHclException('$name: cannot match FloatingPointValue of type '
            '${fpv.runtimeType} with different parameters');
      }
      if (fpv.explicitJBit != explicitJBit) {
        throw RohdHclException('$name: cannot match FloatingPointValue of type '
            '${fpv.runtimeType} with different explicitJBit');
      }
    }
  }

  /// Generate a random [FloatingPointValue], using random seed [rv] in a given
  /// range, if provided. The distribution of values is uniform across the
  /// combined bitfield of exponent and mantissa.
  ///
  /// This generates a valid [FloatingPointValue] anywhere in the range it can
  /// represent:a general [FloatingPointValue] has a mantissa in `[0,2)` with `0
  /// <= exponent <= maxExponent()`.
  ///
  /// If [normal] is `true`, this method will only generate mantissas in the
  /// range of `[1,2)` and `minExponent() <= exponent <= maxExponent()`,
  /// otherwise if [subNormal] is `true`, it will only generate mantissas in the
  /// range of `[0,1)` and `exponent == 0`. If both are `false`, it will
  /// generate mantissas in the range of `[0,2)` and `minExponent() <= exponent
  /// <= maxExponent()`.
  ///
  /// The [normal] and [subNormal] parameters are deprecated, please use
  /// [genNormal] and [genSubNormal] instead.
  ///
  /// If [genNormal] is `true`, this method will generate normal numbers, and if
  /// [genSubNormal] is `true`, it will generate subnormal numbers. If both
  /// are `false`, an exception will be thrown. Note that the range of numbers
  /// to be generated is respected by these flags, so a range which does not
  /// contain the requested type of number will result in a throw.
  ///
  /// You can constrain the range of random numbers generated by using a lower
  /// bound specified by [gt] or [gte] and an upper bound specified by [lt] or
  /// [lte]. If either both lower or both upper bounds are specified, the
  /// tightest bounds are used.
  ///
  /// If [excludeInfinity] is `true`, then infinity values will not be
  /// generated. NaN values are never generated.
  ///
  /// The range is interpreted as follows:
  /// - [gt], [lt]: generate a value in the range `([gt], [lt])`
  /// - [gte], [lt]: generate a value in the range `[[gte], [lt])`
  /// - [gt], [lte]: generate a value in the range `([gt], [lte]]`
  /// - [gte], [lte]: generate a value in the range `[[gte], [lte]]`
  /// - [gt]: generate a value in the range `([gt], ∞)`
  /// - [gte]: generate a value in the range `[[gte], ∞)`
  /// - [lt]: generate a value in the range `(-∞, [lt])`
  /// - [lte]: generate a value in the range `(-∞, [lte]]`
  /// - none: generate a value in the range `(-∞, ∞)`
  FpvType random(Random rv,
      {@Deprecated('use genNormal/genSubNormal instead')
      bool normal = false, // if true, generate only normal numbers
      @Deprecated('use genNormal/genSubNormal instead')
      bool subNormal = false, // if true generate only subnormal numbers
      // These are the new parameters to replace normal/subNormal.
      bool genNormal = true,
      bool genSubNormal = true,
      bool excludeInfinity = false,
      FpvType? gt,
      FpvType? lt,
      FpvType? gte,
      FpvType? lte}) {
    FpvType cloneConstant(FloatingPointConstants c) =>
        _unpopulated.clonePopulator().ofConstant(c) as FpvType;
    // DEPRECATION: these checks are for the deprecated parameters.
    if (normal & subNormal) {
      throw RohdHclException(
          'FloatingPointValuePopulator.random: cannot have both normal and '
          'subNormal be true');
    }
    if (normal & !genNormal) {
      throw RohdHclException(
          'FloatingPointValuePopulator.random: cannot have both normal and '
          'genNormal be false -- normal will be deprecated, use genNormal');
    }
    if (subNormal & !genSubNormal) {
      throw RohdHclException(
          'FloatingPointValuePopulator.random: cannot have both subNormal and '
          'genSubNormal be false -- subNormal will be deprecated, use '
          'genSubNormal');
    }
    if (subNormal & subNormalAsZero) {
      throw RohdHclException(
          'FloatingPointValuePopulator.random: cannot have both subNormal and '
          'subNormalAsZero be true');
    }
    // End DEPRECATION region.
    _checkMatching('gt', gt);
    _checkMatching('lt', lt);
    _checkMatching('gte', gte);
    _checkMatching('lte', lte);

    if (gt != null) {
      if (lt != null) {
        if (gt.compareTo(lt) >= 0) {
          throw RohdHclException(
              'FloatingPointValuePopulator.random: cannot have $gt >= '
              '$lt');
        }
      } else if (lte != null) {
        if (gt.compareTo(lte) > 0) {
          throw RohdHclException(
              'FloatingPointValuePopulator.random: cannot have $gt > '
              '$lte');
        }
      }
    } else if (gte != null) {
      if (lt != null) {
        if (gte.compareTo(lt) >= 0) {
          throw RohdHclException(
              'FloatingPointValuePopulator.random: cannot have $gte >= '
              '$lt');
        }
      } else if (lte != null) {
        if (gte.compareTo(lte) > 0) {
          throw RohdHclException(
              'FloatingPointValuePopulator.random: cannot have $gte > '
              '$lte');
        }
      }
    }

    // Manage the old parameters-- this will not be necessary after deprecation.
    final bool doGenNormal;
    final bool doGenSubNormal;
    if (normal) {
      doGenNormal = true;
      doGenSubNormal = false;
    } else if (subNormal) {
      doGenNormal = false;
      doGenSubNormal = true;
    } else {
      doGenNormal = genNormal;
      doGenSubNormal = genSubNormal;
    }
    // End Manage the old parameters.
    if (!doGenNormal & !doGenSubNormal) {
      throw RohdHclException(
          'FloatingPointValuePopulator.random: cannot have both genNormal and '
          'genSubNormal be false');
    }

    if (doGenSubNormal & subNormalAsZero) {
      throw RohdHclException(
          'FloatingPointValuePopulator.random: cannot have doGenSubNormal be '
          'true and subNormalAsZero be true');
    }

    if (explicitJBit) {
      FloatingPointValuePopulator populator() => FloatingPointValue.populator(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth - 1);
      return ofFloatingPointValue(populator().random(rv,
          genNormal: genNormal,
          genSubNormal: genSubNormal,
          gt: (gt != null)
              ? populator().ofFloatingPointValue(gt, canonicalizeExplicit: true)
              : null,
          lt: (lt != null)
              ? populator().ofFloatingPointValue(lt, canonicalizeExplicit: true)
              : null,
          gte: (gte != null)
              ? populator()
                  .ofFloatingPointValue(gte, canonicalizeExplicit: true)
              : null,
          lte: (lte != null)
              ? populator()
                  .ofFloatingPointValue(lte, canonicalizeExplicit: true)
              : null)) as FpvType;
    }
    if ((lt == null) & (lte == null)) {
      lte = doGenSubNormal & !doGenNormal
          ? cloneConstant(FloatingPointConstants.largestPositiveSubnormal)
          : excludeInfinity
              // Use an inclusive bound at the largest finite value instead of
              // an exclusive bound at +infinity: this produces the same set
              // of generatable values but also works for formats (like
              // e4m3) that cannot represent infinity at all.
              ? cloneConstant(FloatingPointConstants.largestNormal)
              : cloneConstant(FloatingPointConstants.positiveInfinity);
    }
    if ((gt == null) & (gte == null)) {
      gte = doGenSubNormal & !doGenNormal
          ? cloneConstant(FloatingPointConstants.largestPositiveSubnormal)
              .negate() as FpvType
          : excludeInfinity
              ? cloneConstant(FloatingPointConstants.largestNormal).negate()
                  as FpvType
              : cloneConstant(FloatingPointConstants.negativeInfinity);
    }

    // Take the tightest constraints and assign as local variables.
    final FpvType? lgte;
    final FpvType? lgt;
    final FpvType? llte;
    final FpvType? llt;

    if ((gt != null) && (gte != null)) {
      final gtTighter = (gt.compareTo(gte) != -1);
      lgte = gtTighter ? null : gte;
      lgt = gtTighter ? gt : null;
    } else {
      lgte = gte;
      lgt = gt;
    }
    if ((lt != null) && (lte != null)) {
      final ltTighter = (lt.compareTo(lte) != 1);
      llte = ltTighter ? null : lte;
      llt = ltTighter ? lt : null;
    } else {
      llte = lte;
      llt = lt;
    }
    // Trim the limits to skip either normal or subnormal ranges as needed.
    // - normal | - subnormal | 0 | + subnormal | + normal
    final trimGt = (lgt == null)
        ? null
        : ((lgt.isNormal() & (lgt.sign == LogicValue.one) & !doGenNormal)
            ? cloneConstant(FloatingPointConstants.smallestPositiveNormal)
                .negate() as FpvType
            : ((!lgt.isNormal() &
                    (lgt.sign == LogicValue.one) &
                    !doGenSubNormal)
                ? cloneConstant(
                        FloatingPointConstants.smallestPositiveSubnormal)
                    .negate() as FpvType
                : (!lgt.isNormal() &
                        (lgt.sign == LogicValue.zero) &
                        !doGenSubNormal)
                    ? cloneConstant(
                        FloatingPointConstants.largestPositiveSubnormal)
                    : lgt));

    final trimGte = (lgte == null)
        ? null
        : ((lgte.isNormal() & (lgte.sign == LogicValue.one) & !doGenNormal)
            ? cloneConstant(FloatingPointConstants.largestPositiveSubnormal)
                .negate() as FpvType
            : ((!lgte.isNormal() &
                    (lgte.sign == LogicValue.one) &
                    !doGenSubNormal)
                ? cloneConstant(FloatingPointConstants.positiveZero)
                : (!lgte.isNormal() &
                        (lgte.sign == LogicValue.zero) &
                        !doGenSubNormal)
                    ? cloneConstant(
                        FloatingPointConstants.smallestPositiveNormal)
                    : lgte));
    final trimLt = (llt == null)
        ? null
        : ((llt.isNormal() & (llt.sign == LogicValue.zero) & !doGenNormal)
            ? cloneConstant(FloatingPointConstants.smallestPositiveNormal)
            : ((!llt.isNormal() & !doGenSubNormal)
                ? cloneConstant(FloatingPointConstants.largestPositiveSubnormal)
                    .negate() as FpvType
                : llt));
    final trimLte = (llte == null)
        ? null
        : ((llte.isNormal() & (llte.sign == LogicValue.zero) & !doGenNormal)
            ? cloneConstant(FloatingPointConstants.largestPositiveSubnormal)
            : ((!llte.isNormal() & !doGenSubNormal)
                ? cloneConstant(FloatingPointConstants.smallestPositiveNormal)
                    .negate()
                : llte));

    final negNormals = doGenNormal &
        ((trimGt ?? trimGte)!.sign == LogicValue.one) &
        ((trimGt ?? trimGte)!.isNormal()) &
        (trimGt !=
            cloneConstant(FloatingPointConstants.smallestPositiveNormal)
                .negate());

    final posNormals = doGenNormal &
        ((trimLt ?? trimLte)!.sign == LogicValue.zero) &
        ((trimLt ?? trimLte)?.isNormal() ?? true) &
        (trimLt !=
            cloneConstant(FloatingPointConstants.smallestPositiveNormal));

    final negSubNormals = doGenSubNormal &
        ((trimGt ?? trimGte)!.sign == LogicValue.one) &
        !(trimGt?.isAZero ?? false) &
        !(trimGte?.isAZero ?? false) &
        (trimGt !=
            cloneConstant(FloatingPointConstants.smallestPositiveSubnormal)
                .negate());
    final posSubNormals = doGenSubNormal &
        ((trimLt ?? trimLte)!.sign == LogicValue.zero) &
        !(trimLt?.isAZero ?? false) &
        !(trimLte?.isAZero ?? false) &
        (trimLt !=
            cloneConstant(FloatingPointConstants.smallestPositiveSubnormal));

    if ((!doGenSubNormal & !negNormals & !posNormals) ||
        (!doGenNormal & !negSubNormals & !posSubNormals)) {
      throw RohdHclException(
          'FloatingPointValuePopulator.random: cannot generate value, '
          'range excludes all normal and subnormal values');
    }
    // Note that we never have both gt/gte or lt/lte null because of Infinity.
    var gtSign = (trimGt ?? trimGte)?.sign;
    var gtMagnitude =
        (trimGt != null) ? [trimGt.exponent, trimGt.mantissa].swizzle() : null;
    var gteMagnitude = (trimGte != null)
        ? [trimGte.exponent, trimGte.mantissa].swizzle()
        : null;

    var ltSign = (trimLt ?? trimLte)?.sign;
    var ltMagnitude =
        (trimLt != null) ? [trimLt.exponent, trimLt.mantissa].swizzle() : null;
    var lteMagnitude = (trimLte != null)
        ? [trimLte.exponent, trimLte.mantissa].swizzle()
        : null;
    if ((!doGenSubNormal) & negNormals & posNormals) {
      // We need to pick a side to generate from.
      final genSign = rv.nextLogicValue(width: 1);
      if (genSign == LogicValue.zero) {
        // Generate positive normals.
        gtSign = LogicValue.zero;
        gtMagnitude = null;
        final rhGte =
            cloneConstant(FloatingPointConstants.smallestPositiveNormal);
        gteMagnitude = [rhGte.exponent, rhGte.mantissa].swizzle();
      } else {
        // Generate negative normals.
        ltSign = LogicValue.one;
        ltMagnitude = null;
        final lhLte =
            cloneConstant(FloatingPointConstants.smallestPositiveNormal)
                .negate() as FpvType;
        lteMagnitude = [lhLte.exponent, lhLte.mantissa].swizzle();
      }
      if ((!doGenNormal) & !negSubNormals & !posSubNormals) {
        throw RohdHclException(
            'FloatingPointValuePopulator.random: cannot generate value, '
            'range excludes all normal and subnormal values');
      }
    } else if ((!doGenNormal) & negSubNormals & posSubNormals) {
      // We need to pick a side to generate from.
      final genSign = rv.nextLogicValue(width: 1);
      if (genSign == LogicValue.zero) {
        // Generate positive subnormals.
        gtSign = LogicValue.zero;
        gtMagnitude = null;
        final rhGte = cloneConstant(FloatingPointConstants.positiveZero);
        gteMagnitude = [rhGte.exponent, rhGte.mantissa].swizzle();
      } else {
        // Generate negative subnormals.
        ltSign = LogicValue.one;
        ltMagnitude = null;
        final lhLte = cloneConstant(FloatingPointConstants.negativeZero);
        lteMagnitude = [lhLte.exponent, lhLte.mantissa].swizzle();
      }
    }
    final tgt = (gtMagnitude != null)
        ? SignMagnitudeValue(sign: gtSign!, magnitude: gtMagnitude)
        : null;
    final tgte = (gteMagnitude != null)
        ? SignMagnitudeValue(sign: gtSign!, magnitude: gteMagnitude)
        : null;
    final tlt = (ltMagnitude != null)
        ? SignMagnitudeValue(sign: ltSign!, magnitude: ltMagnitude)
        : null;
    final tlte = (lteMagnitude != null)
        ? SignMagnitudeValue(sign: ltSign!, magnitude: lteMagnitude)
        : null;

    final smv =
        SignMagnitudeValue.populator(width: exponentWidth + mantissaWidth)
            .random(rv, gt: tgt, gte: tgte, lt: tlt, lte: tlte);
    return populate(
        sign: smv.sign,
        exponent: smv.magnitude
            .slice(exponentWidth + mantissaWidth - 1, mantissaWidth),
        mantissa: smv.magnitude.slice(mantissaWidth - 1, 0));
  }
}
