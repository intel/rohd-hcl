// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point.dart
// Implementation of Floating Point stuff
//
// 2024 April 1
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:math';
import 'dart:typed_data';
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

  /// Round toward zero
  roundTowardsNegativeInfinity
}

/// A flexible representation of floating point values.
/// A[FloatingPointValue] hasa mantissa in [0,2) with
/// 0 <= exponent <= maxExponent();  A normal [isNormal] [FloatingPointValue]
/// has minExponent() <= exponent <= maxExponent() and a mantissa in the
/// range of [1,2).  Subnormal numbers are represented with a zero exponent
/// and leading zeros in the mantissa capture the negative exponent value.
@immutable
class FloatingPointValue implements Comparable<FloatingPointValue> {
  /// The full floating point value bit storage
  final LogicValue value;

  /// The sign of the value:  1 means a negative value
  final LogicValue sign;

  /// The exponent of the floating point: this is biased about a midpoint for
  /// positive and negative exponents
  final LogicValue exponent;

  /// The mantissa of the floating point
  final LogicValue mantissa;

  /// Return the exponent value representing the true zero exponent 2^0 = 1
  ///   often termed [computeBias] or the offset of the exponent
  static int computeBias(int exponentWidth) =>
      pow(2, exponentWidth - 1).toInt() - 1;

  /// Return the minimum exponent value
  static int computeMinExponent(int exponentWidth) =>
      -pow(2, exponentWidth - 1).toInt() + 2;

  /// Return the maximum exponent value
  static int computeMaxExponent(int exponentWidth) =>
      computeBias(exponentWidth);

  /// Return the bias of this [FloatingPointValue].
  int get bias => _bias;

  /// Return the maximum exponent of this [FloatingPointValue].
  int get maxExponent => _maxExp;

  /// Return the minimum exponent of this [FloatingPointValue].
  int get minExponent => _minExp;

  final int _bias;
  final int _maxExp;
  final int _minExp;

  /// Factory (static) constructor of a [FloatingPointValue] from
  /// sign, mantissa and exponent
  factory FloatingPointValue(
      {required LogicValue sign,
      required LogicValue exponent,
      required LogicValue mantissa}) {
    if (exponent.width == FloatingPoint32Value.exponentWidth &&
        mantissa.width == FloatingPoint32Value.mantissaWidth) {
      return FloatingPoint32Value(
          sign: sign, mantissa: mantissa, exponent: exponent);
    } else if (exponent.width == FloatingPoint64Value._exponentWidth &&
        mantissa.width == FloatingPoint64Value._mantissaWidth) {
      return FloatingPoint64Value(
          sign: sign, mantissa: mantissa, exponent: exponent);
    } else {
      return FloatingPointValue.withConstraints(
          sign: sign, mantissa: mantissa, exponent: exponent);
    }
  }

  /// [FloatingPointValue] constructor from a binary string representation of
  /// individual bitfields
  factory FloatingPointValue.ofBinaryStrings(
      String sign, String exponent, String mantissa) {
    if (sign.length != 1) {
      throw RohdHclException('Sign string must be of length 1');
    }

    return FloatingPointValue(
        sign: LogicValue.of(sign),
        exponent: LogicValue.of(exponent),
        mantissa: LogicValue.of(mantissa));
  }

  /// [FloatingPointValue] constructor from a single binary string representing
  /// space-separated bitfields
  factory FloatingPointValue.ofSeparatedBinaryStrings(String fp) {
    final s = fp.split(' ');
    if (s.length != 3) {
      throw RohdHclException('FloatingPointValue requires three strings '
          'to initialize');
    }
    return FloatingPointValue.ofBinaryStrings(s[0], s[1], s[2]);
  }

  /// [FloatingPointValue] constructor from a radix-encoded string
  /// representation and the size of the exponent and mantissa
  factory FloatingPointValue.ofString(
      String fp, int exponentWidth, int mantissaWidth,
      {int radix = 2}) {
    final binaryFp = LogicValue.ofBigInt(
            BigInt.parse(fp, radix: radix), exponentWidth + mantissaWidth + 1)
        .bitString;

    final (sign, exponent, mantissa) = (
      binaryFp.substring(0, 1),
      binaryFp.substring(1, 1 + exponentWidth),
      binaryFp.substring(1 + exponentWidth, 1 + exponentWidth + mantissaWidth)
    );
    return FloatingPointValue.ofBinaryStrings(sign, exponent, mantissa);
  }

  /// [FloatingPointValue] constructor from a set of [BigInt]s of the binary
  /// representation and the size of the exponent and mantissa
  factory FloatingPointValue.ofBigInts(BigInt exponent, BigInt mantissa,
      {int exponentWidth = 0, int mantissaWidth = 0, bool sign = false}) {
    final (signLv, exponentLv, mantissaLv) = (
      LogicValue.ofBigInt(sign ? BigInt.one : BigInt.zero, 1),
      LogicValue.ofBigInt(exponent, exponentWidth),
      LogicValue.ofBigInt(mantissa, mantissaWidth)
    );

    return FloatingPointValue(
        sign: signLv, exponent: exponentLv, mantissa: mantissaLv);
  }

  /// [FloatingPointValue] constructor from a set of [int]s of the binary
  /// representation and the size of the exponent and mantissa
  factory FloatingPointValue.ofInts(int exponent, int mantissa,
      {int exponentWidth = 0, int mantissaWidth = 0, bool sign = false}) {
    final (signLv, exponentLv, mantissaLv) = (
      LogicValue.ofBigInt(sign ? BigInt.one : BigInt.zero, 1),
      LogicValue.ofBigInt(BigInt.from(exponent), exponentWidth),
      LogicValue.ofBigInt(BigInt.from(mantissa), mantissaWidth)
    );

    return FloatingPointValue(
        sign: signLv, exponent: exponentLv, mantissa: mantissaLv);
  }

  /// Constructor enabling subclasses.
  FloatingPointValue.withConstraints(
      {required this.sign,
      required this.exponent,
      required this.mantissa,
      int? mantissaWidth,
      int? exponentWidth})
      : value = [sign, exponent, mantissa].swizzle(),
        _bias = computeBias(exponent.width),
        _minExp = computeMinExponent(exponent.width),
        _maxExp = computeMaxExponent(exponent.width) {
    if (sign.width != 1) {
      throw RohdHclException('FloatingPointValue: sign width must be 1');
    }
    if (mantissaWidth != null && mantissa.width != mantissaWidth) {
      throw RohdHclException(
          'FloatingPointValue: mantissa width must be $mantissaWidth');
    }
    if (exponentWidth != null && exponent.width != exponentWidth) {
      throw RohdHclException(
          'FloatingPointValue: exponent width must be $exponentWidth');
    }
  }

  /// Construct a [FloatingPointValue] from a Logic word
  factory FloatingPointValue.fromLogic(
      int exponentWidth, int mantissaWidth, LogicValue val) {
    final sign = (val[-1] == LogicValue.one);
    final exponent =
        val.slice(exponentWidth + mantissaWidth - 1, mantissaWidth).toBigInt();
    final mantissa = val.slice(mantissaWidth - 1, 0).toBigInt();
    final (signLv, exponentLv, mantissaLv) = (
      LogicValue.ofBigInt(sign ? BigInt.one : BigInt.zero, 1),
      LogicValue.ofBigInt(exponent, exponentWidth),
      LogicValue.ofBigInt(mantissa, mantissaWidth)
    );
    return FloatingPointValue(
        sign: signLv, exponent: exponentLv, mantissa: mantissaLv);
  }

  /// Return the [FloatingPointValue] representing the constant specified
  factory FloatingPointValue.getFloatingPointConstant(
      FloatingPointConstants constantFloatingPoint,
      int exponentWidth,
      int mantissaWidth) {
    switch (constantFloatingPoint) {
      /// smallest possible number
      case FloatingPointConstants.negativeInfinity:
        return FloatingPointValue.ofBinaryStrings(
            '1', '1' * exponentWidth, '0' * mantissaWidth);

      /// -0.0
      case FloatingPointConstants.negativeZero:
        return FloatingPointValue.ofBinaryStrings(
            '1', '0' * exponentWidth, '0' * mantissaWidth);

      /// 0.0
      case FloatingPointConstants.positiveZero:
        return FloatingPointValue.ofBinaryStrings(
            '0', '0' * exponentWidth, '0' * mantissaWidth);

      /// Smallest possible number, most exponent negative, LSB set in mantissa
      case FloatingPointConstants.smallestPositiveSubnormal:
        return FloatingPointValue.ofBinaryStrings(
            '0', '0' * exponentWidth, '${'0' * (mantissaWidth - 1)}1');

      /// Largest possible subnormal, most negative exponent, mantissa all 1s
      case FloatingPointConstants.largestPositiveSubnormal:
        return FloatingPointValue.ofBinaryStrings(
            '0', '0' * exponentWidth, '1' * mantissaWidth);

      /// Smallest possible positive number, most negative exponent, mantissa 0
      case FloatingPointConstants.smallestPositiveNormal:
        return FloatingPointValue.ofBinaryStrings(
            '0', '${'0' * (exponentWidth - 1)}1', '0' * mantissaWidth);

      /// Largest number smaller than one
      case FloatingPointConstants.largestLessThanOne:
        return FloatingPointValue.ofBinaryStrings(
            '0', '0${'1' * (exponentWidth - 2)}0', '1' * mantissaWidth);

      /// The number '1.0'
      case FloatingPointConstants.one:
        return FloatingPointValue.ofBinaryStrings(
            '0', '0${'1' * (exponentWidth - 1)}', '0' * mantissaWidth);

      /// Smallest number greater than one
      case FloatingPointConstants.smallestLargerThanOne:
        return FloatingPointValue.ofBinaryStrings('0',
            '0${'1' * (exponentWidth - 2)}0', '${'0' * (mantissaWidth - 1)}1');

      /// Largest positive number, most positive exponent, full mantissa
      case FloatingPointConstants.largestNormal:
        return FloatingPointValue.ofBinaryStrings(
            '0', '0' * exponentWidth, '1' * mantissaWidth);

      /// Largest possible number
      case FloatingPointConstants.infinity:
        return FloatingPointValue.ofBinaryStrings(
            '0', '1' * exponentWidth, '0' * mantissaWidth);
    }
  }

  /// Convert from double using its native binary representation
  factory FloatingPointValue.fromDouble(double inDouble,
      {required int exponentWidth,
      required int mantissaWidth,
      FloatingPointRoundingMode roundingMode =
          FloatingPointRoundingMode.roundNearestEven}) {
    if ((exponentWidth == 8) && (mantissaWidth == 23)) {
      return FloatingPoint32Value.fromDouble(inDouble);
    } else if ((exponentWidth == 11) && (mantissaWidth == 52)) {
      return FloatingPoint64Value.fromDouble(inDouble);
    }

    final fp64 = FloatingPoint64Value.fromDouble(inDouble);
    final exponent64 = fp64.exponent;

    var expVal = (exponent64.toInt() - fp64.bias) +
        FloatingPointValue.computeBias(exponentWidth);
    // Handle subnormal
    final mantissa64 = [
      if (expVal <= 0)
        ([LogicValue.one, fp64.mantissa].swizzle() >>> -expVal).slice(52, 1)
      else
        fp64.mantissa
    ].first;
    var mantissa = mantissa64.slice(51, 51 - mantissaWidth + 1);

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

    final exponent =
        LogicValue.ofBigInt(BigInt.from(max(expVal, 0)), exponentWidth);

    return FloatingPointValue(
        sign: fp64.sign, exponent: exponent, mantissa: mantissa);
  }

  /// Generate a random [FloatingPointValue], supplying random seed [rv].
  /// This generates a valid [FloatingPointValue] anywhere in the range
  /// it can represent:a general [FloatingPointValue] has
  /// a mantissa in [0,2) with 0 <= exponent <= maxExponent();
  /// If [normal] is true, This routine will only generate mantissas in the
  /// range of [1,2) and minExponent() <= exponent <= maxExponent().
  factory FloatingPointValue.random(Random rv,
      {required int exponentWidth,
      required int mantissaWidth,
      bool normal = false}) {
    final largestExponent = FloatingPointValue.computeBias(exponentWidth) +
        FloatingPointValue.computeMaxExponent(exponentWidth);
    final s = rv.nextLogicValue(width: 1).toInt();
    var e = BigInt.one;
    do {
      e = rv
          .nextLogicValue(width: exponentWidth, max: largestExponent)
          .toBigInt();
    } while ((e == BigInt.zero) & normal);
    final m = rv.nextLogicValue(width: mantissaWidth).toBigInt();
    return FloatingPointValue(
        sign: LogicValue.ofInt(s, 1),
        exponent: LogicValue.ofBigInt(e, exponentWidth),
        mantissa: LogicValue.ofBigInt(m, mantissaWidth));
  }

  /// Convert a floating point number into a [FloatingPointValue]
  /// representation. This form performs NO ROUNDING.
  factory FloatingPointValue.fromDoubleIter(double inDouble,
      {required int exponentWidth, required int mantissaWidth}) {
    if ((exponentWidth == 8) && (mantissaWidth == 23)) {
      return FloatingPoint32Value.fromDouble(inDouble);
    } else if ((exponentWidth == 11) && (mantissaWidth == 52)) {
      return FloatingPoint64Value.fromDouble(inDouble);
    }

    var doubleVal = inDouble;
    if (inDouble.isNaN) {
      return FloatingPointValue(
        exponent:
            LogicValue.ofInt(pow(2, exponentWidth).toInt() - 1, exponentWidth),
        mantissa: LogicValue.zero,
        sign: LogicValue.zero,
      );
    }
    LogicValue sign;
    if (inDouble < 0.0) {
      doubleVal = -doubleVal;
      sign = LogicValue.one;
    } else {
      sign = LogicValue.zero;
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
    // We reverse so that we fit into a shorter BigInt, we keep the MSB.
    // The conversion fills leftward.
    // We reverse again after conversion.
    final exponent = LogicValue.ofInt(
        e + FloatingPointValue.computeBias(exponentWidth), exponentWidth);
    final mantissa =
        LogicValue.ofBigInt(fullValue.reversed.toBigInt(), mantissaWidth)
            .reversed;

    return FloatingPointValue(
      exponent: exponent,
      mantissa: mantissa,
      sign: sign,
    );
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
    if (signCompare != 0) {
      return signCompare;
    } else {
      final expCompare = exponent.compareTo(other.exponent);
      if (expCompare != 0) {
        return expCompare;
      } else {
        return mantissa.compareTo(other.mantissa);
      }
    }
  }

  /// Return the bias of this FP format
  // int bias() => FloatingPointValue.computeBias(exponent.width);

  @override
  bool operator ==(Object other) {
    if (other is! FloatingPointValue) {
      return false;
    }

    if ((exponent.width != other.exponent.width) |
        (mantissa.width != other.mantissa.width)) {
      return false;
    }

    return (sign == other.sign) &
        (exponent == other.exponent) &
        (mantissa == other.mantissa);
  }

  /// Return true if the represented floating point number is considered
  ///  NaN or 'Not a Number' due to overflow
  // TODO(desmonddak): figure out the difference with Infinity
  bool isNaN() {
    if ((exponent.width == 4) & (mantissa.width == 3)) {
      // FP8 E4M3 does not support infinities
      final cond1 = (1 + exponent.toInt()) == pow(2, exponent.width).toInt();
      final cond2 = (1 + mantissa.toInt()) == pow(2, mantissa.width).toInt();
      return cond1 & cond2;
    } else {
      return exponent.toInt() ==
          computeMaxExponent(exponent.width) + computeBias(exponent.width) + 1;
    }
  }

  /// Return the value of the floating point number in a Dart [double] type.
  double toDouble() {
    var doubleVal = double.nan;
    if (value.isValid) {
      if (exponent.toInt() == 0) {
        doubleVal = (sign.toBool() ? -1.0 : 1.0) *
            pow(2.0, computeMinExponent(exponent.width)) *
            mantissa.toBigInt().toDouble() /
            pow(2.0, mantissa.width);
      } else if (!isNaN()) {
        doubleVal = (sign.toBool() ? -1.0 : 1.0) *
            (1.0 + mantissa.toBigInt().toDouble() / pow(2.0, mantissa.width)) *
            pow(
                2.0,
                exponent.toInt().toSigned(exponent.width) -
                    computeBias(exponent.width));
        doubleVal = (sign.toBool() ? -1.0 : 1.0) *
            (1.0 + mantissa.toBigInt().toDouble() / pow(2.0, mantissa.width)) *
            pow(2.0, exponent.toInt() - computeBias(exponent.width));
      }
    }
    return doubleVal;
  }

  /// Return a Logic true if this FloatingPointVa;ie contains a normal number,
  /// defined as having mantissa in the range [1,2)
  bool isNormal() => exponent != LogicValue.ofInt(0, exponent.width);

  @override
  String toString() => '${sign.toString(includeWidth: false)}'
      ' ${exponent.toString(includeWidth: false)}'
      ' ${mantissa.toString(includeWidth: false)}';

  // TODO(desmonddak): what about floating point representations >> 64 bits?
  FloatingPointValue _performOp(
      FloatingPointValue other, double Function(double a, double b) op) {
    // make sure multiplicand has the same sizes as this
    if (mantissa.width != other.mantissa.width ||
        exponent.width != other.exponent.width) {
      throw RohdHclException('FloatingPointValue: '
          'multiplicand must have the same mantissa and exponent widths');
    }

    return FloatingPointValue.fromDouble(op(toDouble(), other.toDouble()),
        mantissaWidth: mantissa.width, exponentWidth: exponent.width);
  }

  /// Multiply operation for [FloatingPointValue]
  FloatingPointValue operator *(FloatingPointValue multiplicand) =>
      _performOp(multiplicand, (a, b) => a * b);

  /// Addition operation for [FloatingPointValue]
  FloatingPointValue operator +(FloatingPointValue addend) =>
      _performOp(addend, (a, b) => a + b);

  /// Divide operation for [FloatingPointValue]
  FloatingPointValue operator /(FloatingPointValue divisor) =>
      _performOp(divisor, (a, b) => a / b);

  /// Subtract operation for [FloatingPointValue]
  FloatingPointValue operator -(FloatingPointValue subend) =>
      _performOp(subend, (a, b) => a - b);

  /// Negate operation for [FloatingPointValue]
  FloatingPointValue negate() => FloatingPointValue(
      sign: sign.isZero ? LogicValue.one : LogicValue.zero,
      exponent: exponent,
      mantissa: mantissa);

  /// Absolute value operation for [FloatingPointValue]
  FloatingPointValue abs() => FloatingPointValue(
      sign: LogicValue.zero, exponent: exponent, mantissa: mantissa);
}

/// A representation of a single precision floating point value
class FloatingPoint32Value extends FloatingPointValue {
  /// The exponent width
  static const int exponentWidth = 8;

  /// The mantissa width
  static const int mantissaWidth = 23;

  /// Constructor for a single precision floating point value
  FloatingPoint32Value(
      {required super.sign, required super.exponent, required super.mantissa})
      : super.withConstraints(
            mantissaWidth: mantissaWidth, exponentWidth: exponentWidth);

  /// Return the [FloatingPoint32Value] representing the constant specified
  factory FloatingPoint32Value.getFloatingPointConstant(
          FloatingPointConstants constantFloatingPoint) =>
      FloatingPointValue.getFloatingPointConstant(
              constantFloatingPoint, exponentWidth, mantissaWidth)
          as FloatingPoint32Value;

  /// [FloatingPoint32Value] constructor from string representation of
  /// individual bitfields
  factory FloatingPoint32Value.ofStrings(
          String sign, String exponent, String mantissa) =>
      FloatingPoint32Value(
          sign: LogicValue.of(sign),
          exponent: LogicValue.of(exponent),
          mantissa: LogicValue.of(mantissa));

  /// [FloatingPoint32Value] constructor from a single string representing
  /// space-separated bitfields
  factory FloatingPoint32Value.ofString(String fp) {
    final s = fp.split(' ');
    assert(s.length == 3, 'Wrong FloatingPointValue string length ${s.length}');
    return FloatingPoint32Value.ofStrings(s[0], s[1], s[2]);
  }

  /// [FloatingPoint32Value] constructor from a set of [BigInt]s of the binary
  /// representation
  factory FloatingPoint32Value.ofBigInts(BigInt exponent, BigInt mantissa,
      {bool sign = false}) {
    final (signLv, exponentLv, mantissaLv) = (
      LogicValue.ofBigInt(sign ? BigInt.one : BigInt.zero, 1),
      LogicValue.ofBigInt(exponent, exponentWidth),
      LogicValue.ofBigInt(mantissa, mantissaWidth)
    );

    return FloatingPoint32Value(
        sign: signLv, exponent: exponentLv, mantissa: mantissaLv);
  }

  /// [FloatingPoint32Value] constructor from a set of [int]s of the binary
  /// representation
  factory FloatingPoint32Value.ofInts(int exponent, int mantissa,
      {bool sign = false}) {
    final (signLv, exponentLv, mantissaLv) = (
      LogicValue.ofBigInt(sign ? BigInt.one : BigInt.zero, 1),
      LogicValue.ofBigInt(BigInt.from(exponent), exponentWidth),
      LogicValue.ofBigInt(BigInt.from(mantissa), mantissaWidth)
    );

    return FloatingPoint32Value(
        sign: signLv, exponent: exponentLv, mantissa: mantissaLv);
  }

  /// Numeric conversion of a [FloatingPoint32Value] from a host double
  factory FloatingPoint32Value.fromDouble(double inDouble) {
    final byteData = ByteData(4)
      ..setFloat32(0, inDouble)
      ..buffer.asUint8List();
    final bytes = byteData.buffer.asUint8List();
    final lv = bytes.map((b) => LogicValue.ofInt(b, 32));

    final accum = lv.reduce((accum, v) => (accum << 8) | v);

    final sign = accum[-1];
    final exponent =
        accum.slice(exponentWidth + mantissaWidth - 1, mantissaWidth);
    final mantissa = accum.slice(mantissaWidth - 1, 0);

    return FloatingPoint32Value(
        sign: sign, exponent: exponent, mantissa: mantissa);
  }

  /// Construct a [FloatingPoint32Value] from a Logic word
  factory FloatingPoint32Value.fromLogic(LogicValue val) {
    final sign = (val[-1] == LogicValue.one);
    final exponent =
        val.slice(exponentWidth + mantissaWidth - 1, mantissaWidth);
    final mantissa = val.slice(mantissaWidth - 1, 0);
    final (signLv, exponentLv, mantissaLv) = (
      LogicValue.ofBigInt(sign ? BigInt.one : BigInt.zero, 1),
      exponent,
      mantissa
    );
    return FloatingPoint32Value(
        sign: signLv, exponent: exponentLv, mantissa: mantissaLv);
  }
}

/// A representation of a double precision floating point value
class FloatingPoint64Value extends FloatingPointValue {
  static const int _exponentWidth = 11;
  static const int _mantissaWidth = 52;

  /// return the exponent width
  static int get exponentWidth => _exponentWidth;

  /// return the mantissa width
  static int get mantissaWidth => _mantissaWidth;

  /// Constructor for a double precision floating point value
  FloatingPoint64Value(
      {required super.sign, required super.mantissa, required super.exponent})
      : super.withConstraints(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// Return the [FloatingPoint64Value] representing the constant specified
  factory FloatingPoint64Value.getFloatingPointConstant(
          FloatingPointConstants constantFloatingPoint) =>
      FloatingPointValue.getFloatingPointConstant(
              constantFloatingPoint, _exponentWidth, _mantissaWidth)
          as FloatingPoint64Value;

  /// [FloatingPoint64Value] constructor from string representation of
  /// individual bitfields
  factory FloatingPoint64Value.ofStrings(
          String sign, String exponent, String mantissa) =>
      FloatingPoint64Value(
          sign: LogicValue.of(sign),
          exponent: LogicValue.of(exponent),
          mantissa: LogicValue.of(mantissa));

  /// [FloatingPoint64Value] constructor from a single string representing
  /// space-separated bitfields
  factory FloatingPoint64Value.ofString(String fp) {
    final s = fp.split(' ');
    assert(s.length == 3, 'Wrong FloatingPointValue string length ${s.length}');
    return FloatingPoint64Value.ofStrings(s[0], s[1], s[2]);
  }

  /// [FloatingPoint64Value] constructor from a set of [BigInt]s of the binary
  /// representation
  factory FloatingPoint64Value.ofBigInts(BigInt exponent, BigInt mantissa,
          {bool sign = false}) =>
      FloatingPointValue.ofBigInts(exponent, mantissa,
          sign: sign,
          exponentWidth: exponentWidth,
          mantissaWidth: mantissaWidth) as FloatingPoint64Value;

  /// [FloatingPoint64Value] constructor from a set of [int]s of the binary
  /// representation
  factory FloatingPoint64Value.ofInts(int exponent, int mantissa,
          {bool sign = false}) =>
      FloatingPointValue.ofInts(exponent, mantissa,
          sign: sign,
          exponentWidth: exponentWidth,
          mantissaWidth: mantissaWidth) as FloatingPoint64Value;

  /// Numeric conversion of a [FloatingPoint64Value] from a host double
  factory FloatingPoint64Value.fromDouble(double inDouble) {
    final byteData = ByteData(8)
      ..setFloat64(0, inDouble)
      ..buffer.asUint8List();
    final bytes = byteData.buffer.asUint8List();
    final lv = bytes.map((b) => LogicValue.ofInt(b, 64));

    final accum = lv.reduce((accum, v) => (accum << 8) | v);

    final sign = accum[-1];
    final exponent =
        accum.slice(_exponentWidth + _mantissaWidth - 1, _mantissaWidth);
    final mantissa = accum.slice(_mantissaWidth - 1, 0);

    return FloatingPoint64Value(
        sign: sign, mantissa: mantissa, exponent: exponent);
  }

  /// Construct a [FloatingPoint32Value] from a Logic word
  factory FloatingPoint64Value.fromLogic(LogicValue val) {
    final sign = (val[-1] == LogicValue.one);
    final exponent =
        val.slice(exponentWidth + mantissaWidth - 1, mantissaWidth).toBigInt();
    final mantissa = val.slice(mantissaWidth - 1, 0).toBigInt();
    final (signLv, exponentLv, mantissaLv) = (
      LogicValue.ofBigInt(sign ? BigInt.one : BigInt.zero, 1),
      LogicValue.ofBigInt(exponent, exponentWidth),
      LogicValue.ofBigInt(mantissa, mantissaWidth)
    );
    return FloatingPoint64Value(
        sign: signLv, exponent: exponentLv, mantissa: mantissaLv);
  }
}

/// A representation of a 8-bit floating point value as defined in
/// [FP8 Formats for Deep Learning](https://arxiv.org/abs/2209.05433).
class FloatingPoint8Value extends FloatingPointValue {
  /// The exponent width
  late final int exponentWidth;

  /// The mantissa width
  late final int mantissaWidth;

  static double get _e4m3max => 448.toDouble();
  static double get _e5m2max => 57344.toDouble();
  static double get _e4m3min => pow(2, -9).toDouble();
  static double get _e5m2min => pow(2, -16).toDouble();

  /// Return if the exponent and mantissa widths match E4M3 or E5M2
  static bool isLegal(int exponentWidth, int mantissaWidth) {
    if (((exponentWidth == 4) & (mantissaWidth == 3)) |
        ((exponentWidth == 5) & (mantissaWidth == 2))) {
      return true;
    } else {
      return false;
    }
  }

  /// Constructor for a double precision floating point value
  FloatingPoint8Value(
      {required super.sign, required super.mantissa, required super.exponent})
      : super.withConstraints() {
    exponentWidth = exponent.width;
    mantissaWidth = mantissa.width;
    if (!isLegal(exponentWidth, mantissaWidth)) {
      throw RohdHclException('FloatingPoint8 must follow E4M3 or E5M2');
    }
  }

  /// [FloatingPoint8Value] constructor from string representation of
  /// individual bitfields
  factory FloatingPoint8Value.ofStrings(
          String sign, String exponent, String mantissa) =>
      FloatingPoint8Value(
          sign: LogicValue.of(sign),
          exponent: LogicValue.of(exponent),
          mantissa: LogicValue.of(mantissa));

  /// [FloatingPoint8Value] constructor from a single string representing
  /// space-separated bitfields
  factory FloatingPoint8Value.ofString(String fp) {
    final s = fp.split(' ');
    assert(s.length == 3, 'Wrong FloatingPointValue string length ${s.length}');
    return FloatingPoint8Value.ofStrings(s[0], s[1], s[2]);
  }

  /// Construct a [FloatingPoint8Value] from a Logic word
  factory FloatingPoint8Value.fromLogic(LogicValue val, int exponentWidth) {
    if (val.width != 8) {
      throw RohdHclException('Width must be 8');
    }

    final mantissaWidth = 7 - exponentWidth;
    if (!isLegal(exponentWidth, mantissaWidth)) {
      throw RohdHclException('FloatingPoint8 must follow E4M3 or E5M2');
    }

    final sign = (val[-1] == LogicValue.one);
    final exponent =
        val.slice(exponentWidth + mantissaWidth - 1, mantissaWidth).toBigInt();
    final mantissa = val.slice(mantissaWidth - 1, 0).toBigInt();
    final (signLv, exponentLv, mantissaLv) = (
      LogicValue.ofBigInt(sign ? BigInt.one : BigInt.zero, 1),
      LogicValue.ofBigInt(exponent, exponentWidth),
      LogicValue.ofBigInt(mantissa, mantissaWidth)
    );
    return FloatingPoint8Value(
        sign: signLv, exponent: exponentLv, mantissa: mantissaLv);
  }

  /// Numeric conversion of a [FloatingPoint8Value] from a host double
  factory FloatingPoint8Value.fromDouble(double inDouble,
      {required int exponentWidth}) {
    final mantissaWidth = 7 - exponentWidth;
    if (!isLegal(exponentWidth, mantissaWidth)) {
      throw RohdHclException('FloatingPoint8 must follow E4M3 or E5M2');
    }
    if (exponentWidth == 4) {
      if ((inDouble > _e4m3max) | (inDouble < _e4m3min)) {
        throw RohdHclException('Number exceeds E4M3 range');
      }
    } else if (exponentWidth == 5) {
      if ((inDouble > _e5m2max) | (inDouble < _e5m2min)) {
        throw RohdHclException('Number exceeds E5M2 range');
      }
    }
    final fpv = FloatingPointValue.fromDouble(inDouble,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    return FloatingPoint8Value(
        sign: fpv.sign, exponent: fpv.exponent, mantissa: fpv.mantissa);
  }
}
