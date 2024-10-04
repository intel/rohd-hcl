// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_point_value.dart
//
// 2024 September 24
// Authors:
//  Soner Yaldiz <soner.yaldiz@intel.com>

import 'dart:math';
import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An immutable representation of (un)signed fixed-point values following
/// Q notation (Qm.n format) as introduced by
/// (Texas Instruments)[https://www.ti.com/lit/ug/spru565b/spru565b.pdf].
@immutable
class FixedPointValue implements Comparable<FixedPointValue> {
  /// The full fixed point value bit storage in two's complement.
  late final LogicValue value;

  /// The sign of the fixed point number.
  final LogicValue sign;

  /// The integer part of the fixed-point number.
  final LogicValue integer;

  /// The fractional part of the fixed-point number.
  final LogicValue fraction;

  /// Constructs [FixedPointValue] from sign, integer and fraction values.
  FixedPointValue(
      {this.sign = LogicValue.empty,
      this.integer = LogicValue.empty,
      this.fraction = LogicValue.empty}) {
    if ((integer == LogicValue.empty) & (fraction == LogicValue.empty)) {
      throw RohdHclException('integer or fraction must be non-empty');
    }
    if ((sign == LogicValue.empty) | (sign.isZero)) {
      value = [sign, integer, fraction].swizzle();
    } else {
      value = ~[LogicValue.zero, integer, fraction].swizzle() + 1;
    }
  }

  /// Constructs [FixedPointValue] of a Dart [double] rounding away from zero.
  factory FixedPointValue.ofDouble(double value,
      {required bool signed, required int m, required int n}) {
    if (value.abs().floor() > pow(2, m) - 1) {
      throw RohdHclException('value exceed integer part');
    }
    if ((!signed) & (value < 0)) {
      throw RohdHclException('Negative value must be signed.');
    }
    final sign = value >= 0 ? LogicValue.zero : LogicValue.one;
    final integerPart = value.abs().floor();
    final fractionalPart = ((value.abs() - integerPart) * pow(2, n)).round();

    return FixedPointValue(
        sign: signed ? sign : LogicValue.empty,
        integer: LogicValue.ofInt(integerPart, m),
        fraction: LogicValue.ofInt(fractionalPart, n));
  }

  /// Returns the value of the fixed-point number in a Dart [double] type.
  double toDouble() {
    final value = integer.toInt().toDouble() +
        (fraction.toInt().toDouble() / pow(2, fraction.width));
    return (sign == LogicValue.empty) | (sign == LogicValue.zero)
        ? value
        : -value;
  }

  /// Returns a negative integer if `this` less than [other],
  /// a positive integer if `this` greater than [other],
  /// and zero if `this` and [other] are equal.
  @override
  int compareTo(Object other) {
    if (other is! FixedPointValue) {
      throw RohdHclException('Input must be of type FixedPointValue');
    }
    final thisValue = toDouble();
    final otherValue = other.toDouble();
    if (thisValue == otherValue) {
      return 0;
    } else if (thisValue < otherValue) {
      return -1;
    } else {
      return 1;
    }
  }

  /// Equal-to operation that returns a LogicValue.
  LogicValue eq(FixedPointValue other) =>
      compareTo(other) == 0 ? LogicValue.one : LogicValue.zero;

  /// Not equal-to operation that returns a LogicValue.
  LogicValue neq(FixedPointValue other) =>
      compareTo(other) != 0 ? LogicValue.one : LogicValue.zero;

  /// Less-than operation that returns a LogicValue.
  LogicValue operator <(FixedPointValue other) =>
      compareTo(other) < 0 ? LogicValue.one : LogicValue.zero;

  /// Less-than operation that returns a LogicValue.
  LogicValue operator <=(FixedPointValue other) =>
      compareTo(other) <= 0 ? LogicValue.one : LogicValue.zero;

  /// Less-than operation that returns a LogicValue.
  LogicValue operator >(FixedPointValue other) =>
      compareTo(other) > 0 ? LogicValue.one : LogicValue.zero;

  /// Less-than operation that returns a LogicValue.
  LogicValue operator >=(FixedPointValue other) =>
      compareTo(other) >= 0 ? LogicValue.one : LogicValue.zero;

  /// Addition operation that returns a FixedPointValue.
  /// The result is signed if one of the operands is signed.
  /// The result integer has the max integer width of the operands plus one.
  /// The result fraction has the max fractional width of the operands.
  FixedPointValue operator +(FixedPointValue other) {
    final res = toDouble() + other.toDouble();
    final signed =
        (sign != LogicValue.empty) | (other.sign != LogicValue.empty);
    final m = max(integer.width, other.integer.width) + 1;
    final n = max(fraction.width, other.fraction.width);
    return FixedPointValue.ofDouble(res, signed: signed, m: m, n: n);
  }

  /// Subtraction operation that returns a FixedPointValue.
  /// The result is always signed.
  /// The result integer has the max integer width of the operands plus one.
  /// The result fraction has the max fractional width of the operands.
  FixedPointValue operator -(FixedPointValue other) {
    final res = toDouble() - other.toDouble();
    final m = max(integer.width, other.integer.width) + 1;
    final n = max(fraction.width, other.fraction.width);
    return FixedPointValue.ofDouble(res, signed: true, m: m, n: n);
  }

  /// Multiplication operation that returns a FixedPointValue.
  /// The result is signed if one of the operands is signed.
  /// The result integer width is the sum of integer widths of operands.
  /// The result fraction width is the sum of fraction widths of operands.
  FixedPointValue operator *(FixedPointValue other) {
    final signed =
        (sign != LogicValue.empty) | (other.sign != LogicValue.empty);
    final res = toDouble() * other.toDouble();
    final m = integer.width + other.integer.width;
    final n = fraction.width + other.fraction.width;
    return FixedPointValue.ofDouble(res, signed: signed, m: m, n: n);
  }

  /// Division operation that returns a FixedPointValue.
  /// The result is signed if one of the operands is signed.
  /// The result integer width is the sum of integer widths of operands.
  /// The result fraction width is the sum of fraction widths of operands.
  FixedPointValue operator /(FixedPointValue other) {
    final signed =
        (sign != LogicValue.empty) | (other.sign != LogicValue.empty);
    final res = toDouble() / other.toDouble();
    final m = integer.width + other.integer.width;
    final n = fraction.width + other.fraction.width;
    return FixedPointValue.ofDouble(res, signed: signed, m: m, n: n);
  }
}
