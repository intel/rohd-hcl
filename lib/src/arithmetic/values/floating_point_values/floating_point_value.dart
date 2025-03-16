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

  /// The sign of the value: 1 means a negative value.
  late final LogicValue sign;

  /// The exponent of the floating point: this is biased about a midpoint for
  /// positive and negative exponents.
  late final LogicValue exponent;

  /// The [exponent] width.
  int get exponentWidth => storedExponentWidth;

  /// The stored exponent width.
  @protected
  late final int storedExponentWidth;

  /// The mantissa of the floating point.
  late final LogicValue mantissa;

  /// The [mantissa] width.
  int get mantissaWidth => storedMantissaWidth;

  /// The stored mantissa width.
  @protected
  late final int storedMantissaWidth;

  /// Return true if the JBit is implicitly represented.
  bool get implicitJBit => true;

  /// Return true if the JBit is explicitly representedin the mantissa.
  bool get explicitJBit => false;

  /// Return the bias of this [FloatingPointValue].
  ///
  /// Representing the true zero exponent `2^0 = 1`, often termed the offset of
  /// the exponent.
  int get bias => pow(2, exponentWidth - 1).toInt() - 1;

  /// Return the maximum exponent of this [FloatingPointValue].
  int get maxExponent => bias;

  /// Return the minimum exponent of this [FloatingPointValue].
  int get minExponent => -pow(2, exponentWidth - 1).toInt() + 2;

  /// Indicates whether [FloatingPointConstants.positiveInfinity] and
  /// [FloatingPointConstants.negativeInfinity] representations are supported.
  bool get supportsInfinities => true;

  /// Constructor for a [FloatingPointValue] with the provided [sign],
  /// [exponent], and [mantissa].
  factory FloatingPointValue(
          {required LogicValue sign,
          required LogicValue exponent,
          required LogicValue mantissa}) =>
      populator(exponentWidth: exponent.width, mantissaWidth: mantissa.width)
          .populate(sign: sign, exponent: exponent, mantissa: mantissa);

  /// Creates an unpopulated version of a [FloatingPointValue], intended to be
  /// called with the [populator].
  @protected
  FloatingPointValue.uninitialized();

  /// Creates a [FloatingPointValuePopulator] with the provided [exponentWidth]
  /// and [mantissaWidth], which can then be used to complete construction of
  /// a [FloatingPointValue] using population functions.
  static FloatingPointValuePopulator populator(
          {required int exponentWidth, required int mantissaWidth}) =>
      FloatingPointValuePopulator(FloatingPointValue.uninitialized()
        ..storedExponentWidth = exponentWidth
        ..storedMantissaWidth = mantissaWidth);

  /// Creates a [FloatingPointValuePopulator] for the same type as `this` and
  /// with the same widths.
  ///
  /// This must be overridden in subclasses so that the correct type of
  /// [FloatingPointValuePopulator] is returned for generating equivalent types
  /// of [FloatingPointValue]s.
  @mustBeOverridden
  FloatingPointValuePopulator clonePopulator() =>
      FloatingPointValuePopulator(FloatingPointValue.uninitialized()
        ..storedExponentWidth = exponentWidth
        ..storedMantissaWidth = mantissaWidth);

  /// A wrapper around [FloatingPointValuePopulator.ofString] that computes the
  /// widths of the exponent and mantissa from the input string.
  factory FloatingPointValue.ofBinaryStrings(
          String sign, String exponent, String mantissa) =>
      populator(exponentWidth: exponent.length, mantissaWidth: mantissa.length)
          .ofBinaryStrings(sign, exponent, mantissa);

  /// A wrapper around [FloatingPointValuePopulator.ofSpacedBinaryString] that
  /// computes the widths of the exponent and mantissa from the input string.
  factory FloatingPointValue.ofSpacedBinaryString(String fp) {
    final split = fp.split(' ');
    return populator(
            exponentWidth: split[1].length, mantissaWidth: split[2].length)
        .ofSpacedBinaryString(fp);
  }

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

  // TODO(desmonddak): toRadixString() would be useful, not limited to binary

  /// Return the set of [LogicValue]s for a given [FloatingPointConstants] at a
  /// given [exponentWidth] and [mantissaWidth].
  ///
  /// This is a good function to override if constants behave specially in
  /// subclases.
  @protected
  ({LogicValue sign, LogicValue exponent, LogicValue mantissa})
      getConstantComponents(FloatingPointConstants constantFloatingPoint) {
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
      case FloatingPointConstants.positiveInfinity:
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
  /// NaN or "Not a Number".
  bool get isNaN => isExponentAllOnes && !isMantissaAllZeroes;

  /// Return true if the represented floating point number is considered
  /// "subnormal", including [isAZero].
  bool isSubnormal() => isExponentAllZeros;

  /// Return true if the represented floating point number is considered
  ///  infinity or negative infinity
  bool get isAnInfinity =>
      supportsInfinities && isExponentAllOnes && isMantissaAllZeroes;

  /// Return true if the represented floating point number is zero. Note
  /// that the equality operator will treat
  /// [FloatingPointConstants.positiveZero]
  /// and [FloatingPointConstants.negativeZero] as equal.
  bool get isAZero =>
      this == clonePopulator().positiveZero ||
      this == clonePopulator().negativeZero;

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
            pow(2.0, mantissa.width - (explicitJBit ? 1 : 0));
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

  /// Return a Logic true if this FloatingPointVa;ie contains a normal number,
  /// defined as having mantissa in the range `[1,2)`.
  bool isNormal() => exponent != LogicValue.ofInt(0, exponent.width);

  /// Return a string representation of FloatingPointValue.
  ///
  /// If [integer] is `true`, returns sign, exponent, mantissa as integers. If
  /// [integer] is `false`, returns sign, exponent, mantissa as binary strings.
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

  /// Performs an operation [op] between this [FloatingPointValue] and another
  /// [FloatingPointValue] [other].
  FloatingPointValue _performOp(
      FloatingPointValue other, double Function(double a, double b) op) {
    // make sure multiplicand has the same sizes as this
    if (mantissa.width != other.mantissa.width ||
        exponent.width != other.exponent.width) {
      throw RohdHclException('FloatingPointValue: '
          'multiplicand must have the same mantissa and exponent widths');
    }
    if (isNaN | other.isNaN) {
      return clonePopulator().nan;
    }

    return clonePopulator().ofDouble(op(toDouble(), other.toDouble()));
  }

  /// Multiply operation for [FloatingPointValue].
  FloatingPointValue operator *(FloatingPointValue multiplicand) {
    if (isAnInfinity) {
      if (multiplicand.isAnInfinity) {
        return sign != multiplicand.sign
            ? clonePopulator().negativeInfinity
            : clonePopulator().positiveInfinity;
      } else if (multiplicand.isAZero) {
        return clonePopulator().nan;
      } else {
        return this;
      }
    } else if (multiplicand.isAnInfinity) {
      if (isAZero) {
        return clonePopulator().nan;
      } else {
        return multiplicand;
      }
    }
    return _performOp(multiplicand, (a, b) => a * b);
  }

  /// Addition operation for [FloatingPointValue].
  FloatingPointValue operator +(FloatingPointValue addend) {
    if (isAnInfinity) {
      if (addend.isAnInfinity) {
        if (sign != addend.sign) {
          return clonePopulator().nan;
        } else {
          return sign.toBool()
              ? clonePopulator().negativeInfinity
              : clonePopulator().positiveInfinity;
        }
      } else {
        return this;
      }
    } else if (addend.isAnInfinity) {
      return addend;
    }
    return _performOp(addend, (a, b) => a + b);
  }

  /// Divide operation for [FloatingPointValue].
  FloatingPointValue operator /(FloatingPointValue divisor) {
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
    return _performOp(divisor, (a, b) => a / b);
  }

  /// Subtract operation for [FloatingPointValue].
  FloatingPointValue operator -(FloatingPointValue subend) {
    if (isAnInfinity & subend.isAnInfinity) {
      if (sign == subend.sign) {
        return clonePopulator().nan;
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

  /// Negate operation for [FloatingPointValue].
  FloatingPointValue negate() => clonePopulator().populate(
      sign: sign.isZero ? LogicValue.one : LogicValue.zero,
      exponent: exponent,
      mantissa: mantissa);

  /// Absolute value operation for [FloatingPointValue].
  FloatingPointValue abs() => clonePopulator()
      .populate(sign: LogicValue.zero, exponent: exponent, mantissa: mantissa);

  /// Return true if the other [FloatingPointValue] is within a rounding error
  /// of this value.
  bool withinRounding(FloatingPointValue other) {
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
    if (exponent.toInt() > mantissa.width) {
      final newExponent =
          LogicValue.ofInt(exponent.toInt() - mantissa.width, exponent.width);
      return clonePopulator().ofBinaryStrings(
          sign.bitString, newExponent.bitString, '0' * (mantissa.width));
    } else {
      return clonePopulator().ofBinaryStrings(
          sign.bitString, exponent.bitString, '${'0' * (mantissa.width - 1)}1');
    }
  }
}
