// Copyright (C) 2024-2026 Intel Corporation
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

/// A flexible representation of floating point values. A [FloatingPointValue]
/// has a mantissa in `[0,2)` with `0 <= exponent <= maxExponent();`  A value
/// which [FloatingPointValue.isNormal] has `minExponent() <= exponent <=
/// maxExponent()` and a mantissa in the range of `[1,2)`.  Subnormal numbers
/// are represented with a zero exponent and leading zeros in the mantissa
/// capture the negative exponent value.
@immutable
class FloatingPointValue implements Comparable<FloatingPointValue> {
  /// The full floating point value concatenated as a [LogicValue].
  late final LogicValue value = [sign, exponent, mantissa].swizzle();

  /// The sign of the [FloatingPointValue]: 1 means a negative value.
  late final LogicValue sign;

  /// The exponent of the [FloatingPointValue]: this is biased about a midpoint
  /// for positive and negative exponents.
  late final LogicValue exponent;

  /// The [exponent] width.
  int get exponentWidth => _exponentWidth;

  /// The stored exponent width.
  late final int _exponentWidth;

  /// The mantissa of the floating point.
  late final LogicValue mantissa;

  /// The [mantissa] width.
  int get mantissaWidth => _mantissaWidth;

  /// The stored mantissa width.
  late final int _mantissaWidth;

  /// The stored explicit JBit flag.
  late final bool _explicitJBit;

  /// Return `true` if the JBit is explicitly represented in the mantissa.
  bool get explicitJBit => _explicitJBit;

  /// Treat subnormal numbers as zero.
  late final bool _subNormalAsZero;

  /// Return `true` if subnormal numbers are treated as zero.
  bool get subNormalAsZero => _subNormalAsZero;

  /// Return the bias of this [FloatingPointValue], the offset of the
  /// exponent, also representing the zero exponent `2^0 = 1`.
  int get bias => pow(2, exponentWidth - 1).toInt() - 1;

  /// Return the maximum exponent of this [FloatingPointValue].
  int get maxExponent => bias;

  /// Return the minimum exponent of this [FloatingPointValue].
  int get minExponent => -pow(2, exponentWidth - 1).toInt() + 2;

  /// Indicates whether [FloatingPointConstants.positiveInfinity] and
  /// [FloatingPointConstants.negativeInfinity] representations are supported.
  bool get supportsInfinities => true;

  /// Indicates whether signaling and quiet NaNs have distinct encodings.
  bool get supportsSignalingNaNs => true;

  /// Constructor for a [FloatingPointValue] with the provided [sign],
  /// [exponent], and [mantissa].
  factory FloatingPointValue(
          {required LogicValue sign,
          required LogicValue exponent,
          required LogicValue mantissa,
          bool explicitjBit = false,
          bool subNormalAsZero = false}) =>
      populator(
              exponentWidth: exponent.width,
              mantissaWidth: mantissa.width,
              explicitJBit: explicitjBit,
              subNormalAsZero: subNormalAsZero)
          .populate(sign: sign, exponent: exponent, mantissa: mantissa);

  /// Creates an unpopulated version of a [FloatingPointValue], intended to be
  /// called with the [populator].
  @protected
  FloatingPointValue.uninitialized(
      {bool explicitJBit = false, bool subNormalAsZero = false})
      : _explicitJBit = explicitJBit,
        _subNormalAsZero = subNormalAsZero;

  /// Creates a [FloatingPointValuePopulator] with the provided [exponentWidth]
  /// and [mantissaWidth], which can then be used to complete construction of
  /// a [FloatingPointValue] using population functions.
  static FloatingPointValuePopulator populator(
          {required int exponentWidth,
          required int mantissaWidth,
          bool explicitJBit = false,
          bool subNormalAsZero = false}) =>
      FloatingPointValuePopulator(FloatingPointValue.uninitialized(
          explicitJBit: explicitJBit, subNormalAsZero: subNormalAsZero)
        .._exponentWidth = exponentWidth
        .._mantissaWidth = mantissaWidth);

  /// Creates a [FloatingPointValuePopulator] for the same type as `this` and
  /// with the same widths.
  ///
  /// This must be overridden in subclasses so that the correct type of
  /// [FloatingPointValuePopulator] is returned for generating equivalent types
  /// of [FloatingPointValue]s.
  @mustBeOverridden
  FloatingPointValuePopulator clonePopulator() =>
      FloatingPointValuePopulator(FloatingPointValue.uninitialized(
          explicitJBit: explicitJBit, subNormalAsZero: subNormalAsZero)
        .._exponentWidth = exponentWidth
        .._mantissaWidth = mantissaWidth);

  /// Validate the [FloatingPointValue] to ensure widths and other
  /// characteristics are legal.
  @protected
  @visibleForOverriding
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

  /// Returns a tuple of [LogicValue]s for the [sign], [exponent], and
  /// [mantissa] components of a special constant, or `null` if the constant
  /// does not have special components.This is useful for constants like NaN,
  /// infinity, etc., in certain types of floating point representations.
  @protected
  @visibleForOverriding
  ({LogicValue sign, LogicValue exponent, LogicValue mantissa})?
      getSpecialConstantComponents(
              FloatingPointConstants constantFloatingPoint) =>
          null;

  @override
  int get hashCode {
    if (isExponentAllZeros && isMantissaAllZeroes) {
      return 0;
    }
    if (isNaN) {
      return Object.hash(sign, exponent, mantissa, explicitJBit);
    }
    final canonical = canonicalize();
    final canonicalMantissa = canonical.explicitJBit
        ? canonical.mantissa.getRange(0, -1)
        : canonical.mantissa;
    return Object.hash(canonical.sign, canonical.exponent, canonicalMantissa);
  }

  FloatingPointValue _validateComparable(Object other) {
    if (other is! FloatingPointValue) {
      throw RohdHclException('Input must be of type FloatingPointValue.');
    }
    if ((exponent.width != other.exponent.width) |
        (mantissa.width - (explicitJBit ? 1 : 0) !=
            other.mantissa.width - (other.explicitJBit ? 1 : 0))) {
      throw RohdHclException(
          'FloatingPointValue widths must match for comparison.');
    }
    return other;
  }

  /// Compares two ordered values to implement [Comparable].
  ///
  /// Throws if either operand is NaN because IEEE 754 ordinary comparisons
  /// define NaNs as unordered.
  @override
  int compareTo(Object other) {
    final comparable = _validateComparable(other);
    if (isNaN || comparable.isNaN) {
      throw RohdHclException('NaN values are unordered.');
    }

    // IEEE 754: -0 an +0 are considered equal
    if ((exponent.isZero && mantissa.isZero) &&
        (comparable.exponent.isZero && comparable.mantissa.isZero)) {
      return 0;
    }
    final signCompare = -sign.compareTo(comparable.sign);

    final canonical = canonicalize();
    final otherCanonical = comparable.canonicalize();

    final canonicalMantissa = canonical.explicitJBit
        ? canonical.mantissa.getRange(0, -1)
        : canonical.mantissa;

    final otherCanonicalMantissa = otherCanonical.explicitJBit
        ? otherCanonical.mantissa.getRange(0, -1)
        : otherCanonical.mantissa;

    final expCompare = canonical.exponent.compareTo(otherCanonical.exponent);
    final mantCompare = canonicalMantissa.compareTo(otherCanonicalMantissa);
    if ((signCompare != 0) &&
        !(exponent.isZero &&
            mantissa.isZero &&
            comparable.exponent.isZero &&
            comparable.mantissa.isZero)) {
      return signCompare; // IEEE 754: -0 and +0 are considered equal.
    }
    if (expCompare != 0) {
      return sign.isZero ? expCompare : -expCompare;
    } else if (mantCompare != 0) {
      return sign.isZero ? mantCompare : -mantCompare;
    }
    return 0;
  }

  /// Equality operator for [FloatingPointValue].
  @override
  bool operator ==(Object other) {
    if (other is! FloatingPointValue) {
      return false;
    }
    if (isNaN | other.isNaN) {
      return false;
    }
    return compareTo(other) == 0;
  }

  /// Whether this and [other] have identical formats and bit encodings.
  ///
  /// Unlike numerical equality, this can be used to compare NaN payloads,
  /// signaling bits, and signed zeros in tests.
  bool hasSameEncoding(FloatingPointValue other) =>
      exponentWidth == other.exponentWidth &&
      mantissaWidth == other.mantissaWidth &&
      explicitJBit == other.explicitJBit &&
      subNormalAsZero == other.subNormalAsZero &&
      sign == other.sign &&
      exponent == other.exponent &&
      mantissa == other.mantissa;

  /// Whether an IEEE quiet comparison with [other] signals invalid.
  bool comparisonInvalid(FloatingPointValue other) {
    _validateComparable(other);
    return isSignalingNaN || other.isSignalingNaN;
  }

  /// Less-than operator for [FloatingPointValue].
  bool operator <(FloatingPointValue other) {
    _validateComparable(other);
    return !(isNaN || other.isNaN) && compareTo(other) < 0;
  }

  /// Less-than-or-equal operator for [FloatingPointValue].
  bool operator <=(FloatingPointValue other) {
    _validateComparable(other);
    return !(isNaN || other.isNaN) && compareTo(other) <= 0;
  }

  /// Greater-than operator for [FloatingPointValue].
  bool operator >(FloatingPointValue other) {
    _validateComparable(other);
    return !(isNaN || other.isNaN) && compareTo(other) > 0;
  }

  /// Greater-than-or-equal operator for [FloatingPointValue].
  bool operator >=(FloatingPointValue other) {
    _validateComparable(other);
    return !(isNaN || other.isNaN) && compareTo(other) >= 0;
  }

  /// Test if exponent is all '1's.
  bool get isExponentAllOnes => exponent.and() == LogicValue.one;

  /// Test if exponent is all '0's.
  bool get isExponentAllZeros => exponent.or() == LogicValue.zero;

  /// Test if mantissa is all '0's.
  bool get isMantissaAllZeroes => mantissa.or() == LogicValue.zero;

  /// Test if the fractional portion of [mantissa] is all zeroes.
  bool get isFractionAllZeroes {
    final fractionWidth = mantissaWidth - (explicitJBit ? 1 : 0);
    return fractionWidth == 0 ||
        mantissa.slice(fractionWidth - 1, 0).or() == LogicValue.zero;
  }

  /// Return `true` if the represented floating point number is considered
  /// NaN or "Not a Number".
  bool get isNaN => isExponentAllOnes && !isFractionAllZeroes;

  /// Return `true` if this is a signaling NaN.
  bool get isSignalingNaN =>
      supportsSignalingNaNs &&
      isNaN &&
      mantissaWidth > (explicitJBit ? 1 : 0) &&
      !mantissa[explicitJBit ? -2 : -1].toBool();

  /// Return `true` if this is a quiet NaN.
  bool get isQuietNaN => isNaN && !isSignalingNaN;

  /// Return `true` if the represented floating point number is considered
  /// "subnormal", including [isAZero].
  bool isSubnormal() => isExponentAllZeros;

  /// Return `true` if the represented floating point number is considered
  ///  infinity or negative infinity.
  bool get isAnInfinity =>
      supportsInfinities && isExponentAllOnes && isFractionAllZeroes;

  /// Return `true` if the represented floating point number is zero. Note
  /// that the equality operator will treat
  /// [FloatingPointConstants.positiveZero]
  /// and [FloatingPointConstants.negativeZero] as equal.
  bool get isAZero =>
      this == clonePopulator().positiveZero ||
      this == clonePopulator().negativeZero ||
      (subNormalAsZero && isSubnormal());

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
        if (subNormalAsZero) {
          doubleVal = 0.0;
        } else {
          doubleVal = (sign.toBool() ? -1.0 : 1.0) *
              pow(2.0, minExponent) *
              mantissa.toBigInt().toDouble() /
              pow(2.0, mantissa.width - (explicitJBit ? 1 : 0));
        }
      } else if (!isNaN) {
        doubleVal = (sign.toBool() ? -1.0 : 1.0) *
            ((explicitJBit ? 0.0 : 1.0) +
                mantissa.toBigInt().toDouble() /
                    pow(2.0, mantissa.width - (explicitJBit ? 1 : 0))) *
            pow(2.0, exponent.toInt() - bias);
      }
    }
    return doubleVal;
  }

  /// Returns this exact finite value as `significand * 2^exponent`.
  ///
  /// Throws for NaN and infinity, which have no finite dyadic representation.
  ({BigInt significand, int exponent}) toScaledBigInt() {
    if (isNaN || isAnInfinity) {
      throw RohdHclException(
          'NaN and infinity have no finite scaled-integer representation.');
    }
    if (subNormalAsZero && isSubnormal()) {
      return (significand: BigInt.zero, exponent: 0);
    }

    final fractionWidth = mantissaWidth - (explicitJBit ? 1 : 0);
    final normal = !exponent.isZero;
    var significand = mantissa.toBigInt() |
        (normal && !explicitJBit ? BigInt.one << fractionWidth : BigInt.zero);
    if (sign.toBool()) {
      significand = -significand;
    }
    final unbiasedExponent = normal ? exponent.toInt() - bias : minExponent;
    return (
      significand: significand,
      exponent: unbiasedExponent - fractionWidth
    );
  }

  /// Losslessly converts this finite value to a [FixedPointValue].
  FixedPointValue toFixedPointValue() {
    final exact = toScaledBigInt();
    var significand = exact.significand;
    var exponent = exact.exponent;
    if (significand == BigInt.zero) {
      return FixedPointValue.populator(integerWidth: 0, fractionWidth: 0)
          .ofScaledBigInt(BigInt.zero, 0);
    }
    while (significand.isEven) {
      significand >>= 1;
      exponent++;
    }

    final fractionWidth = max(0, -exponent);
    final scaled = exponent > 0 ? significand << exponent : significand;
    final requiredSignedWidth = scaled.isNegative
        ? (scaled.abs() - BigInt.one).bitLength + 1
        : scaled.bitLength + 1;
    final totalWidth = max(fractionWidth + 1, requiredSignedWidth);
    return FixedPointValue.populator(
            integerWidth: totalWidth - fractionWidth - 1,
            fractionWidth: fractionWidth)
        .ofScaledBigInt(significand, exponent);
  }

  /// Converts this value to a constant [FloatingPoint] signal.
  FloatingPoint toLogic({String? name}) =>
      FloatingPoint.constant(this, name: name);

  /// Return `true` if this [FloatingPointValue] contains a normal
  /// number, defined as having mantissa in the range `[1,2)`.
  bool isNormal() {
    if (explicitJBit) {
      final e = exponent.toInt();
      final m = mantissa.toInt();
      final int normMantissa;
      if (e < mantissa.width) {
        normMantissa = 1 << (mantissa.width - e - 1);
      } else {
        normMantissa = 1;
      }
      return (e > 0) && (m >= normMantissa);
    } else {
      return exponent != LogicValue.ofInt(0, exponent.width);
    }
  }

  /// Check if the mantissa and exponent stored are compatible.
  bool isLegalValue() {
    if (explicitJBit) {
      final e = exponent.toInt();
      final m = mantissa.toInt();
      // For a subnormal/zero exponent (e == 0), the explicit j-bit (the
      // mantissa's MSB) must be 0. For a normal exponent (e > 0), the
      // explicit j-bit must be 1: this is the entire purpose of storing the
      // j-bit explicitly, so any other bit pattern is not a legal encoding.
      final normMantissa = 1 << (mantissa.width - 1);

      return ((e == 0) && (m < normMantissa)) ||
          ((e > 0) && (m >= normMantissa));
    }
    return true;
  }

  /// Return the cananocalized form of [FloatingPointValue] which
  /// has the leading 1 at the front of the mantissa, or further right if
  /// subnormal.
  FloatingPointValue canonicalize() =>
      clonePopulator().ofFloatingPointValue(this, canonicalizeExplicit: true);

  /// Return a string representation of [FloatingPointValue].
  ///
  /// If [integer] is `true`, returns sign, exponent, mantissa as integers. If
  /// [integer] is `false`, returns sign, exponent, mantissa as binary strings.
  @override
  String toString({bool integer = false}) {
    if (integer) {
      // Use toBigInt() rather than toInt(): exponent/mantissa can exceed 64
      // bits, and LogicValue.toInt() throws in that case.
      return '(${sign.toBigInt()}'
          ' ${exponent.toBigInt()}'
          ' ${mantissa.toBigInt()})';
    } else {
      return '${sign.toString(includeWidth: false)}'
          ' ${exponent.toString(includeWidth: false)}'
          ' ${mantissa.toString(includeWidth: false)}';
    }
  }

  void _validateArithmeticFormat(FloatingPointValue other) {
    if (mantissa.width != other.mantissa.width ||
        exponent.width != other.exponent.width ||
        explicitJBit != other.explicitJBit) {
      throw RohdHclException('FloatingPointValue: operands must have the same '
          'mantissa and exponent widths and J-bit representation');
    }
  }

  /// Multiply operation for [FloatingPointValue].
  FloatingPointValue operator *(FloatingPointValue multiplicand) {
    _validateArithmeticFormat(multiplicand);
    return clonePopulator().multiply(this, multiplicand);
  }

  /// Addition operation for [FloatingPointValue].
  FloatingPointValue operator +(FloatingPointValue addend) {
    _validateArithmeticFormat(addend);
    return clonePopulator().add(this, addend);
  }

  /// Divide operation for [FloatingPointValue].
  FloatingPointValue operator /(FloatingPointValue divisor) {
    _validateArithmeticFormat(divisor);
    if (isAnInfinity) {
      if (divisor.isAnInfinity | divisor.isAZero) {
        return clonePopulator().nan;
      } else {
        return this;
      }
    } else {
      if (divisor.isAZero) {
        return sign != divisor.sign
            ? clonePopulator().negativeInfinity
            : clonePopulator().positiveInfinity;
      }
    }
    return clonePopulator().divide(this, divisor);
  }

  /// Subtract operation for [FloatingPointValue].
  FloatingPointValue operator -(FloatingPointValue subend) {
    _validateArithmeticFormat(subend);
    return clonePopulator().add(this, subend.negate());
  }

  /// Negate operation for [FloatingPointValue].
  FloatingPointValue negate() => clonePopulator().populate(
      sign: sign.isZero ? LogicValue.one : LogicValue.zero,
      exponent: exponent,
      mantissa: mantissa);

  /// Negate the [FloatingPointValue].
  FloatingPointValue operator -() => negate();

  /// Absolute value operation for [FloatingPointValue].
  FloatingPointValue abs() => clonePopulator()
      .populate(sign: LogicValue.zero, exponent: exponent, mantissa: mantissa);

  /// Return `true` if the other [FloatingPointValue] is within a rounding error
  /// of this value.
  bool withinRounding(FloatingPointValue other) {
    if (isNaN || other.isNaN) {
      return false;
    }
    if (isAnInfinity || other.isAnInfinity) {
      return this == other;
    }
    if (this != other) {
      final diff = (abs() - other.abs()).abs();
      if (diff.compareTo(ulp()) == 1) {
        return false;
      }
    }
    return true;
  }

  /// Compute the unit in the last place for the given [FloatingPointValue].
  FloatingPointValue ulp() {
    if (isNaN || isAnInfinity) {
      return abs();
    }

    final populator = clonePopulator();
    if (exponent.isZero) {
      return populator.ofConstant(subNormalAsZero
          ? FloatingPointConstants.smallestPositiveNormal
          : FloatingPointConstants.smallestPositiveSubnormal);
    }

    final fractionWidth = mantissaWidth - (explicitJBit ? 1 : 0);
    final encodedExponent = exponent.toInt();
    if (encodedExponent <= fractionWidth) {
      if (subNormalAsZero) {
        return populator
            .ofConstant(FloatingPointConstants.smallestPositiveNormal);
      }
      return populator.ofBigInts(
          BigInt.zero, BigInt.one << (encodedExponent - 1));
    }

    return populator.ofBigInts(BigInt.from(encodedExponent - fractionWidth),
        explicitJBit ? BigInt.one << fractionWidth : BigInt.zero);
  }
}
