// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_value.dart
// Implementation of Floating-Point value representations.
//
// 2024 April 1
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:math';
import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Critical threshold constants
enum FloatingPointConstants {
  /// smallest possible number
  negativeInfinity,

  /// The number zero, negative form
  negativeZero,

  /// The number zero, positive form
  positiveZero,

  /// Smallest possible number, most exponent negative, LSB set in mantissa
  smallestPositiveSubnormal,

  /// Largest possible subnormal, most negative exponent, mantissa all 1s
  largestPositiveSubnormal,

  /// Smallest possible positive number, most negative exponent, mantissa is 0
  smallestPositiveNormal,

  /// Largest number smaller than one
  largestLessThanOne,

  /// The number one
  one,

  /// Smallest number greater than one
  smallestLargerThanOne,

  /// Largest positive number, most positive exponent, full mantissa
  largestNormal,

  /// Largest possible number
  infinity,

  /// Not a Number, demarked by all 1s in exponent and any 1 in mantissa
  nan,
}

/// IEEE Floating Point Rounding Modes
enum FloatingPointRoundingMode {
  /// Truncate the result, no rounding
  truncate,

  /// Round to nearest, ties to even
  roundNearestEven,

  /// Round to nearest, tieas away from zero
  roundNearestTiesAway,

  /// Round toward zero
  roundTowardsZero,

  /// Round toward +infinity
  roundTowardsInfinity,

  /// Round toward -infinity
  roundTowardsNegativeInfinity
}

/// A flexible representation of floating point values.
/// A [FloatingPointValue] hasa mantissa in [0,2) with
/// 0 <= exponent <= maxExponent();  A normal [isNormal] [FloatingPointValue]
/// has minExponent() <= exponent <= maxExponent() and a mantissa in the
/// range of [1,2).  Subnormal numbers are represented with a zero exponent
/// and leading zeros in the mantissa capture the negative exponent value.
@immutable
class FloatingPointValue implements Comparable<FloatingPointValue> {
  /// The full floating point value bit storage
  late final LogicValue value = [sign, exponent, mantissa].swizzle();

  /// The sign of the value:  1 means a negative value
  late final LogicValue sign;

  /// The exponent of the floating point: this is biased about a midpoint for
  /// positive and negative exponents
  late final LogicValue exponent;

  /// The [exponent] width.
  int get exponentWidth => exponent.width;

  /// The mantissa of the floating point
  late final LogicValue mantissa;

  /// The [mantissa] width.
  int get mantissaWidth => mantissa.width;

  /// Return the bias of this [FloatingPointValue].
  ///
  /// Representing the true zero exponent `2^0 = 1`, often termed the offset of
  /// the exponent.
  int get bias => pow(2, exponentWidth - 1).toInt() - 1;

  /// Return the maximum exponent of this [FloatingPointValue].
  int get maxExponent => bias;

  /// Return the minimum exponent of this [FloatingPointValue].
  int get minExponent => -pow(2, exponentWidth - 1).toInt() + 2;

  /// Constructor for a [FloatingPointValue] with a sign, exponent, and
  /// mantissa.
  @protected
  FloatingPointValue(
      {required this.sign, required this.exponent, required this.mantissa}) {
    validate();
  }

  /// Validate the [FloatingPointValue] to ensure widths and other
  /// characteristics are legal.
  @protected
  void validate() {
    if (sign.width != 1) {
      throw RohdHclException('FloatingPointValue: sign width must be 1');
    }
    if (mantissa.width != mantissaWidth) {
      throw RohdHclException('FloatingPointValue: mantissa width must be '
          '$mantissaWidth');
    }
    if (exponent.width != exponentWidth) {
      throw RohdHclException('FloatingPointValue: exponent width must be '
          '$exponentWidth');
    }
  }

  /// [FloatingPointValue] constructor from a binary string representation of
  /// individual bitfields
  FloatingPointValue.ofBinaryStrings(
      String sign, String exponent, String mantissa)
      : this(
            sign: LogicValue.of(sign),
            exponent: LogicValue.of(exponent),
            mantissa: LogicValue.of(mantissa));

  /// [FloatingPointValue] constructor from a single binary string representing
  /// space-separated bitfields
  FloatingPointValue.ofSpacedBinaryString(String fp)
      : this.ofBinaryStrings(
            fp.split(' ')[0], fp.split(' ')[1], fp.split(' ')[2]);

  /// [FloatingPointValue] constructor from a radix-encoded string
  /// representation and the size of the exponent and mantissa
  FloatingPointValue.ofString(String fp, int exponentWidth, int mantissaWidth,
      {int radix = 2})
      : this.ofBinaryStrings(
            _extractBinaryStrings(fp, exponentWidth, mantissaWidth, radix).sign,
            _extractBinaryStrings(fp, exponentWidth, mantissaWidth, radix)
                .exponent,
            _extractBinaryStrings(fp, exponentWidth, mantissaWidth, radix)
                .mantissa);

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

  // TODO(desmonddak): toRadixString() would be useful, not limited to binary

  /// [FloatingPointValue] constructor from a set of [BigInt]s of the binary
  /// representation and the size of the exponent and mantissa
  FloatingPointValue.ofBigInts(BigInt exponent, BigInt mantissa,
      {int exponentWidth = 0, int mantissaWidth = 0, bool sign = false})
      : this(
            sign: LogicValue.ofBigInt(sign ? BigInt.one : BigInt.zero, 1),
            exponent: LogicValue.ofBigInt(exponent, exponentWidth),
            mantissa: LogicValue.ofBigInt(mantissa, mantissaWidth));

  /// [FloatingPointValue] constructor from a set of [int]s of the binary
  /// representation and the size of the exponent and mantissa
  FloatingPointValue.ofInts(int exponent, int mantissa,
      {int exponentWidth = 0, int mantissaWidth = 0, bool sign = false})
      : this(
            sign: LogicValue.ofBigInt(sign ? BigInt.one : BigInt.zero, 1),
            exponent: LogicValue.ofBigInt(BigInt.from(exponent), exponentWidth),
            mantissa:
                LogicValue.ofBigInt(BigInt.from(mantissa), mantissaWidth));

  /// Construct a [FloatingPointValue] from a [LogicValue]
  FloatingPointValue.ofLogicValue(
      int exponentWidth, int mantissaWidth, LogicValue val)
      : this(
          sign: val[-1],
          exponent: val.getRange(mantissaWidth, mantissaWidth + exponentWidth),
          mantissa: val.getRange(0, mantissaWidth),
        );

  // Abbreviation Functions for common constants

  /// Creates a new [FloatingPointValue] representing
  /// [FloatingPointConstants.infinity].
  FloatingPointValue get infinity =>
      getFloatingPointConstant(FloatingPointConstants.infinity);

  /// Creates a new [FloatingPointValue] representing
  /// [FloatingPointConstants.negativeInfinity].
  FloatingPointValue get negativeInfinity =>
      getFloatingPointConstant(FloatingPointConstants.negativeInfinity);

  /// Creates a new [FloatingPointValue] representing
  /// [FloatingPointConstants.nan].
  FloatingPointValue get nan =>
      getFloatingPointConstant(FloatingPointConstants.nan);

  /// Creates a new [FloatingPointValue] representing
  /// [FloatingPointConstants.one].
  FloatingPointValue get one =>
      getFloatingPointConstant(FloatingPointConstants.one);

  /// Creates a new [FloatingPointValue] representing
  /// [FloatingPointConstants.positiveZero].
  FloatingPointValue get zero =>
      getFloatingPointConstant(FloatingPointConstants.positiveZero);

  /// Creates a new [FloatingPointValue] represented by the given
  /// [FloatingPointConstants].
  FloatingPointValue getFloatingPointConstant(
      FloatingPointConstants constantFloatingPoint) {
    final components = getConstantComponents(
        constantFloatingPoint, exponentWidth, mantissaWidth);

    return copyWith(
        sign: components.sign,
        exponent: components.exponent,
        mantissa: components.mantissa)
      ..validate();
  }

  /// Creates a copy of this [FloatingPointValue] with the given new values for
  /// [sign], [exponent], and [mantissa].
  ///
  /// This should be overridden by subclasses to return the correct type.
  @mustBeOverridden
  FloatingPointValue copyWith(
          {LogicValue? sign, LogicValue? exponent, LogicValue? mantissa}) =>
      FloatingPointValue(
        sign: sign ?? this.sign,
        exponent: exponent ?? this.exponent,
        mantissa: mantissa ?? this.mantissa,
      );

  /// Return the set of binary strings for a given [FloatingPointConstants] at a
  /// given [exponentWidth] and [mantissaWidth].
  ///
  /// This is a good function to override if constants behave specially in
  /// subclases.
  ({LogicValue sign, LogicValue exponent, LogicValue mantissa})
      getConstantComponents(FloatingPointConstants constantFloatingPoint,
          int exponentWidth, int mantissaWidth) {
    final (
      String signStr,
      String exponentStr,
      String mantissaStr
    ) stringComponents;

    switch (constantFloatingPoint) {
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
      case FloatingPointConstants.infinity:
        stringComponents = ('0', '1' * exponentWidth, '0' * mantissaWidth);

      // Not a Number (NaN)
      case FloatingPointConstants.nan:
        stringComponents =
            ('0', '1' * exponentWidth, '${'0' * (mantissaWidth - 1)}1');
    }

    return (
      sign: LogicValue.of(stringComponents.$1),
      exponent: LogicValue.of(stringComponents.$2),
      mantissa: LogicValue.of(stringComponents.$3)
    );
  }

// TODO(desmonddak): we may have a bug in ofDouble() when
// the FPV is close to the width of the native double:  for LGRS to work
// we need three bits of space to handle the LSB|Guard|Round|Sticky.
// If the FPV is only 2 bits shorter than native, then we know we can round
// with LSB+Guard, but can't fit the round and sticky bits.
// The algorithm needs to extend with zeros and handle.

  /// Convert from double using its native binary representation
  FloatingPointValue.ofDouble(double inDouble,
      {required int exponentWidth,
      required int mantissaWidth,
      FloatingPointRoundingMode roundingMode =
          FloatingPointRoundingMode.roundNearestEven}) {
    if (inDouble.isNaN) {
      final nan = this.nan;
      mantissa = nan.mantissa;
      exponent = nan.exponent;
      sign = nan.sign;
      return;
    }

    if (inDouble.isInfinite) {
      final inf = getFloatingPointConstant(
        inDouble < 0.0
            ? FloatingPointConstants.negativeInfinity
            : FloatingPointConstants.infinity,
      );
      mantissa = inf.mantissa;
      exponent = inf.exponent;
      sign = inf.sign;
      return;
    }

    if (roundingMode != FloatingPointRoundingMode.roundNearestEven &&
        roundingMode != FloatingPointRoundingMode.truncate) {
      throw UnimplementedError(
          'Only roundNearestEven or truncate is supported for this width');
    }

    final fp64 = FloatingPoint64Value.ofDouble(inDouble);
    final exponent64 = fp64.exponent;

    var expVal = (exponent64.toInt() - fp64.bias) + bias;
    // Handle subnormal
    final mantissa64 = [
      if (expVal <= 0)
        ([LogicValue.one, fp64.mantissa].swizzle() >>> -expVal).slice(52, 1)
      else
        fp64.mantissa
    ].first;
    mantissa = mantissa64.slice(51, 51 - mantissaWidth + 1);

    // TODO(desmonddak): this should be in a separate function to use
    // with a FloatingPointValue converter we need.
    if (roundingMode == FloatingPointRoundingMode.roundNearestEven) {
      final sticky = mantissa64.slice(51 - (mantissaWidth + 2), 0).or();

      final roundPos = 51 - (mantissaWidth + 2) + 1;
      final round = mantissa64[roundPos];
      final guard = mantissa64[roundPos + 1];

      // RNE Rounding
      if (guard == LogicValue.one) {
        if ((round == LogicValue.one) |
            (sticky == LogicValue.one) |
            (mantissa[0] == LogicValue.one)) {
          mantissa += 1;
          if (mantissa == LogicValue.zero.zeroExtend(mantissa.width)) {
            expVal += 1;
          }
        }
      }
    }
    if (expVal >
        FloatingPointValue.computeMaxExponent(exponentWidth) +
            FloatingPointValue.computeBias(exponentWidth)) {
      return FloatingPointValue.getFloatingPointConstant(
          fp64.sign.toBool()
              ? FloatingPointConstants.negativeInfinity
              : FloatingPointConstants.infinity,
          exponentWidth,
          mantissaWidth);
    }

    // TODO(desmonddak): how to convert to infinity and check that it is
    // supported by the format.
    if ((exponentWidth == 4) && (mantissaWidth == 3)) {
      // TODO(desmonddak): need a better way to detect subclass limitations
      // Here we avoid returning infinity for FP8E4M3
    } else {
      if (expVal >
          FloatingPointValue.computeBias(exponentWidth) +
              FloatingPointValue.computeMaxExponent(exponentWidth)) {
        return (fp64.sign == LogicValue.one)
            ? FloatingPointValue.getFloatingPointConstant(
                FloatingPointConstants.negativeInfinity,
                exponentWidth,
                mantissaWidth)
            : FloatingPointValue.getFloatingPointConstant(
                FloatingPointConstants.infinity, exponentWidth, mantissaWidth);
      }
    }
    final exponent =
        LogicValue.ofBigInt(BigInt.from(max(expVal, 0)), exponentWidth);

    sign = fp64.sign;
  }

  /// Generate a random [FloatingPointValue], supplying random seed [rv].
  ///
  /// This generates a valid [FloatingPointValue] anywhere in the range it can
  /// represent:a general [FloatingPointValue] has a mantissa in `[0,2)` with `0
  /// <= exponent <= maxExponent()`.
  ///
  /// If [normal] is true, This routine will only generate mantissas in the
  /// range of `[1,2)` and `minExponent() <= exponent <= maxExponent().`
  FloatingPointValue.random(Random rv, {bool normal = false}) {
    sign = rv.nextLogicValue(width: 1);

    mantissa = rv.nextLogicValue(width: mantissaWidth);

    final largestExponent = bias + maxExponent;
    if (normal) {
      exponent =
          rv.nextLogicValue(width: exponentWidth, max: largestExponent - 1) +
              LogicValue.one;
    } else {
      exponent = rv.nextLogicValue(width: exponentWidth, max: largestExponent);
    }

    validate();
  }

  /// Convert a floating point number into a [FloatingPointValue]
  /// representation. This form performs NO ROUNDING.
  @internal
  factory FloatingPointValue.ofDoubleUnrounded(double inDouble,
      {required int exponentWidth, required int mantissaWidth}) {
    if (inDouble.isNaN) {
      return FloatingPointValue.getFloatingPointConstant(
          FloatingPointConstants.nan, exponentWidth, mantissaWidth);
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
      return FloatingPointValue.getFloatingPointConstant(
          sign.toBool()
              ? FloatingPointConstants.negativeInfinity
              : FloatingPointConstants.infinity,
          exponentWidth,
          mantissaWidth);
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
        : FloatingPointValue.computeMinExponent(exponentWidth);

    if (e <= -FloatingPointValue.computeBias(exponentWidth)) {
      fullValue = fullValue >>>
          (scaleToWhole - FloatingPointValue.computeBias(exponentWidth));
      e = -FloatingPointValue.computeBias(exponentWidth);
    } else {
      // Could be just one away from subnormal
      e -= 1;
      if (e > -FloatingPointValue.computeBias(exponentWidth)) {
        fullValue = fullValue << 1; // Chop the first '1'
      }
    }

    if (e > FloatingPointValue.computeMaxExponent(exponentWidth)) {
      return FloatingPointValue.getFloatingPointConstant(
          sign.toBool()
              ? FloatingPointConstants.negativeInfinity
              : FloatingPointConstants.infinity,
          exponentWidth,
          mantissaWidth);
    }
    // We reverse so that we fit into a shorter BigInt, we keep the MSB.
    // The conversion fills leftward.
    // We reverse again after conversion.
    final exponent = LogicValue.ofInt(
        e + FloatingPointValue.computeBias(exponentWidth), exponentWidth);
    final mantissa =
        LogicValue.ofBigInt(fullValue.reversed.toBigInt(), mantissaWidth)
            .reversed;

    return FloatingPointValue(
        exponent: exponent, mantissa: mantissa, sign: sign);
  }

  @override
  int get hashCode => sign.hashCode ^ exponent.hashCode ^ mantissa.hashCode;

  /// Floating point comparison to implement Comparable<>
  @override
  int compareTo(Object other) {
    if (other is! FloatingPointValue) {
      throw Exception('Input must be of type FloatingPointValue ');
    }
    if ((exponent.width != other.exponent.width) |
        (mantissa.width != other.mantissa.width)) {
      throw Exception('FloatingPointValue widths must match for comparison');
    }
    final signCompare = sign.compareTo(other.sign);
    final expCompare = exponent.compareTo(other.exponent);
    final mantCompare = mantissa.compareTo(other.mantissa);
    if ((signCompare != 0) && !(exponent.isZero && mantissa.isZero)) {
      return signCompare;
    }
    if (expCompare != 0) {
      return sign.isZero ? expCompare : -expCompare;
    } else if (mantCompare != 0) {
      return sign.isZero ? mantCompare : -mantCompare;
    }
    return 0;
  }

  @override
  bool operator ==(Object other) {
    if (other is! FloatingPointValue) {
      return false;
    }
    if ((exponent.width != other.exponent.width) |
        (mantissa.width != other.mantissa.width)) {
      return false;
    }
    if (isNaN != other.isNaN) {
      return false;
    }
    if (isAnInfinity != other.isAnInfinity) {
      return false;
    }
    if (isAnInfinity) {
      return sign == other.sign;
    }
    // IEEE 754: -0 an +0 are considered equal
    if ((exponent.isZero && mantissa.isZero) &&
        (other.exponent.isZero && other.mantissa.isZero)) {
      return true;
    }
    return (sign == other.sign) &
        (exponent == other.exponent) &
        (mantissa == other.mantissa);
  }

  /// Test if exponent is all '1's.
  bool get isExponentAllOnes => exponent.and() == LogicValue.one;

  /// Test if exponent is all '0's.
  bool get isExponentAllZeros => exponent.or() == LogicValue.zero;

  /// Test if mantissa is all '0's.
  bool get isMantissaAllZeroes => mantissa.or() == LogicValue.zero;

  /// Return true if the represented floating point number is considered
  ///  NaN or 'Not a Number'
  bool get isNaN => isExponentAllOnes && !isMantissaAllZeroes;

  /// Return true if the represented floating point number is considered
  ///  'subnormal', including [isZero].
  bool isSubnormal() => isExponentAllZeros;

  /// Return true if the represented floating point number is considered
  ///  infinity or negative infinity
  bool get isAnInfinity => isExponentAllOnes && isMantissaAllZeroes;

  /// Return true if the represented floating point number is zero. Note
  /// that the equality operator will treat
  /// [FloatingPointConstants.positiveZero]
  /// and [FloatingPointConstants.negativeZero] as equal.
  bool get isZero =>
      this ==
      FloatingPointValue.getFloatingPointConstant(
          FloatingPointConstants.positiveZero, exponent.width, mantissa.width);

  /// Return the value of the floating point number in a Dart [double] type.
  double toDouble() {
    if (isNaN) {
      return double.nan;
    }
    if (isAnInfinity) {
      return sign.isZero ? double.infinity : double.negativeInfinity;
    }
    var doubleVal = double.nan;
    if (value.isValid) {
      if (exponent.toInt() == 0) {
        doubleVal = (sign.toBool() ? -1.0 : 1.0) *
            pow(2.0, minExponent) *
            mantissa.toBigInt().toDouble() /
            pow(2.0, mantissa.width);
      } else if (!isNaN) {
        doubleVal = (sign.toBool() ? -1.0 : 1.0) *
            (1.0 + mantissa.toBigInt().toDouble() / pow(2.0, mantissa.width)) *
            pow(2.0, exponent.toInt().toSigned(exponent.width) - bias);
        doubleVal = (sign.toBool() ? -1.0 : 1.0) *
            (1.0 + mantissa.toBigInt().toDouble() / pow(2.0, mantissa.width)) *
            pow(2.0, exponent.toInt() - bias);
      }
    }
    return doubleVal;
  }

  /// Return a Logic true if this FloatingPointVa;ie contains a normal number,
  /// defined as having mantissa in the range [1,2)
  bool isNormal() => exponent != LogicValue.ofInt(0, exponent.width);

  /// Return a string representation of FloatingPointValue.
  /// if [integer] is true, return sign, exponent, mantissa as integers.
  /// if [integer] is false, return sign, exponent, mantissa as ibinary strings.
  @override
  String toString({bool integer = false}) {
    if (integer) {
      return '(${sign.toInt()}'
          ' ${exponent.toInt()}'
          ' ${mantissa.toInt()})';
    } else {
      return '${sign.toString(includeWidth: false)}'
          ' ${exponent.toString(includeWidth: false)}'
          ' ${mantissa.toString(includeWidth: false)}';
    }
  }

  // TODO(desmonddak): what about floating point representations >> 64 bits?
  FloatingPointValue _performOp(
      FloatingPointValue other, double Function(double a, double b) op) {
    // make sure multiplicand has the same sizes as this
    if (mantissa.width != other.mantissa.width ||
        exponent.width != other.exponent.width) {
      throw RohdHclException('FloatingPointValue: '
          'multiplicand must have the same mantissa and exponent widths');
    }
    if (isNaN | other.isNaN) {
      return FloatingPointValue.getFloatingPointConstant(
          FloatingPointConstants.nan, exponent.width, mantissa.width);
    }

    return FloatingPointValue.ofDouble(op(toDouble(), other.toDouble()),
        mantissaWidth: mantissa.width, exponentWidth: exponent.width);
  }

  /// Multiply operation for [FloatingPointValue]
  FloatingPointValue operator *(FloatingPointValue multiplicand) {
    if (isAnInfinity) {
      if (multiplicand.isAnInfinity) {
        return sign != multiplicand.sign ? negativeInfinity : infinity;
      } else if (multiplicand.isZero) {
        return nan;
      } else {
        return this;
      }
    } else if (multiplicand.isAnInfinity) {
      if (isZero) {
        return nan;
      } else {
        return multiplicand;
      }
    }
    return _performOp(multiplicand, (a, b) => a * b);
  }

  /// Addition operation for [FloatingPointValue]
  FloatingPointValue operator +(FloatingPointValue addend) {
    if (isAnInfinity) {
      if (addend.isAnInfinity) {
        if (sign != addend.sign) {
          return nan;
        } else {
          return sign.toBool() ? negativeInfinity : infinity;
        }
      } else {
        return this;
      }
    } else if (addend.isAnInfinity) {
      return addend;
    }
    return _performOp(addend, (a, b) => a + b);
  }

  /// Divide operation for [FloatingPointValue]
  FloatingPointValue operator /(FloatingPointValue divisor) {
    if (isAnInfinity) {
      if (divisor.isAnInfinity | divisor.isZero) {
        return nan;
      } else {
        return this;
      }
    } else {
      if (divisor.isZero) {
        return sign != divisor.sign ? negativeInfinity : infinity;
      }
    }
    return _performOp(divisor, (a, b) => a / b);
  }

  /// Subtract operation for [FloatingPointValue]
  FloatingPointValue operator -(FloatingPointValue subend) {
    if (isAnInfinity & subend.isAnInfinity) {
      if (sign == subend.sign) {
        return nan;
      } else {
        return this;
      }
    } else if (subend.isAnInfinity) {
      return subend.negate();
    } else if (isAnInfinity) {
      return this;
    }
    return _performOp(subend, (a, b) => a - b);
  }

  /// Negate operation for [FloatingPointValue]
  FloatingPointValue negate() => FloatingPointValue(
      sign: sign.isZero ? LogicValue.one : LogicValue.zero,
      exponent: exponent,
      mantissa: mantissa);

  /// Absolute value operation for [FloatingPointValue]
  FloatingPointValue abs() => FloatingPointValue(
      sign: LogicValue.zero, exponent: exponent, mantissa: mantissa);

  /// Return true if the other [FloatingPointValue] is within a rounding
  /// error of this value.
  bool withinRounding(FloatingPointValue other) {
    if (this != other) {
      final diff = (abs() - other.abs()).abs();
      if (diff.compareTo(ulp()) == 1) {
        return false;
      }
    }
    return true;
  }

  /// Compute the unit in the last place for the given [FloatingPointValue]
  FloatingPointValue ulp() {
    if (exponent.toInt() > mantissa.width) {
      final newExponent =
          LogicValue.ofInt(exponent.toInt() - mantissa.width, exponent.width);
      return FloatingPointValue.ofBinaryStrings(
          sign.bitString, newExponent.bitString, '0' * (mantissa.width));
    } else {
      return FloatingPointValue.ofBinaryStrings(
          sign.bitString, exponent.bitString, '${'0' * (mantissa.width - 1)}1');
    }
  }
}
