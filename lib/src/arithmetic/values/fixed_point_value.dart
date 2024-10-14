// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_point_value.dart
// Representation of fixed-point values.
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
  /// The fixed point value bit storage in two's complement.
  late final LogicValue value;

  /// [signed] indicates whether the representation is signed.
  final bool signed;

  /// [m] is the number of bits reserved for the integer part.
  final int m;

  /// [n] is the number of bits reserved for the fractional part.
  final int n;

  /// Returns true if the number is negative.
  bool isNegative() => signed & (value[-1] == LogicValue.one);

  /// Constructs [FixedPointValue] from sign, integer and fraction values.
  FixedPointValue(
      {required this.value,
      required this.signed,
      required this.m,
      required this.n}) {
    if (value == LogicValue.empty) {
      throw RohdHclException('Zero width is not allowed.');
    }
    final w = signed ? m + n + 1 : m + n;
    if (w != value.width) {
      throw RohdHclException('Width must be (sign) + m + n.');
    }
  }

  /// Expands the bit width of integer and fractional parts.
  LogicValue expandWidth({required bool sign, int m = 0, int n = 0}) {
    if ((m > 0) & (m < this.m)) {
      throw RohdHclException('Integer width is larger than input.');
    }
    if ((n > 0) & (n < this.n)) {
      throw RohdHclException('Fraction width is larger than input.');
    }
    var newValue = value;
    if (m > this.m) {
      if (signed) {
        newValue = newValue.signExtend(newValue.width + m - this.m);
      } else {
        newValue = newValue.zeroExtend(newValue.width + m - this.m);
        if (sign) {
          newValue = newValue.zeroExtend(newValue.width + 1);
        }
      }
    }
    if (n > this.n) {
      newValue =
          newValue.reversed.zeroExtend(newValue.width + n - this.n).reversed;
    }
    return newValue;
  }

  /// Returns a negative integer if `this` less than [other],
  /// a positive integer if `this` greater than [other],
  /// and zero if `this` and [other] are equal.
  @override
  int compareTo(Object other) {
    if (other is! FixedPointValue) {
      throw RohdHclException('Input must be of type FixedPointValue');
    }
    if (!value.isValid | !other.value.isValid) {
      throw RohdHclException('Inputs must be valid.');
    }
    final s = signed | other.signed;
    final m = max(this.m, other.m);
    final n = max(this.n, other.n);
    final val1 = expandWidth(sign: s, m: m, n: n);
    final val2 = other.expandWidth(sign: s, m: m, n: n);
    final comp = val1.compareTo(val2);
    if (comp == 0) {
      return comp;
    } else if (!isNegative() & !other.isNegative()) {
      return comp;
    } else if (!isNegative() & other.isNegative()) {
      return 1;
    } else if (isNegative() & !other.isNegative()) {
      return -1;
    } else {
      return -comp;
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

  @override
  int get hashCode => _hashCode;

  int get _hashCode =>
      value.hashCode ^ signed.hashCode ^ m.hashCode ^ n.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is! FixedPointValue) {
      return false;
    }
    return compareTo(other) == 0;
  }

  /// Constructs [FixedPointValue] of a Dart [double] rounding away from zero.
  factory FixedPointValue.ofDouble(double val,
      {required bool signed, required int m, required int n}) {
    if (!signed & (val < 0)) {
      throw RohdHclException('Negative input not allowed with unsigned');
    }
    final integerValue = (val * pow(2, n)).toInt();
    final w = signed ? 1 + m + n : m + n;
    final v = LogicValue.ofInt(integerValue, w);
    return FixedPointValue(value: v, signed: signed, m: m, n: n);
  }

  /// Converts a fixed-point value to a Dart [double].
  double toDouble() {
    if (m + n > 52) {
      throw RohdHclException('Fixed-point value is too wide to convert.');
    }
    if (!this.value.isValid) {
      throw RohdHclException('Inputs must be valid.');
    }
    BigInt number;
    if (isNegative()) {
      number = (~(this.value - 1)).toBigInt();
    } else {
      number = this.value.toBigInt();
    }
    final value = number.toDouble() / pow(2, n).toDouble();
    return isNegative() ? -value : value;
  }

  /// Addition operation that returns a FixedPointValue.
  /// The result is signed if one of the operands is signed.
  /// The result integer has the max integer width of the operands plus one.
  /// The result fraction has the max fractional width of the operands.
  FixedPointValue operator +(FixedPointValue other) {
    if (!value.isValid | !other.value.isValid) {
      throw RohdHclException('Inputs must be valid.');
    }
    final s = signed | other.signed;
    final nr = max(n, other.n);
    final mr = s ? max(m, other.m) + 2 : max(m, other.m) + 1;
    final val1 = expandWidth(sign: s, m: mr, n: nr);
    final val2 = other.expandWidth(sign: s, m: mr, n: nr);
    return FixedPointValue(value: val1 + val2, signed: s, m: mr, n: nr);
  }

  /// Subtraction operation that returns a FixedPointValue.
  /// The result is always signed.
  /// The result integer has the max integer width of the operands plus one.
  /// The result fraction has the max fractional width of the operands.
  FixedPointValue operator -(FixedPointValue other) {
    if (!value.isValid | !other.value.isValid) {
      throw RohdHclException('Inputs must be valid.');
    }
    const s = true;
    final nr = max(n, other.n);
    final mr = max(m, other.m) + 2;
    final val1 = expandWidth(sign: s, m: mr, n: nr);
    final val2 = other.expandWidth(sign: s, m: mr, n: nr);
    return FixedPointValue(value: val1 - val2, signed: s, m: mr, n: nr);
  }

  /// Multiplication operation that returns a FixedPointValue.
  /// The result is signed if one of the operands is signed.
  /// The result fraction width is the sum of fraction widths of operands.
  FixedPointValue operator *(FixedPointValue other) {
    if (!value.isValid | !other.value.isValid) {
      throw RohdHclException('Inputs must be valid.');
    }
    final s = signed | other.signed;
    final ms = s ? m + other.m + 1 : m + other.m;
    final ns = n + other.n;
    final val1 = expandWidth(sign: s, m: ms + ns - n);
    final val2 = other.expandWidth(sign: s, m: ms + ns - other.n);
    return FixedPointValue(value: val1 * val2, signed: s, m: ms, n: ns);
  }

  /// Division operation that returns a FixedPointValue.
  /// The result is signed if one of the operands is signed.
  /// The result integer width is the sum of dividend integer width and divisor
  /// fraction width. The result fraction width is the sum of dividend fraction
  /// width and divisor integer width.
  FixedPointValue operator /(FixedPointValue other) {
    if (!value.isValid | !other.value.isValid) {
      throw RohdHclException('Inputs must be valid.');
    }
    final s = signed | other.signed;
    // extend integer width for max negative number
    final m1 = s ? m + 1 : m;
    final m2 = s ? other.m + 1 : other.m;
    final mr = m1 + other.n;
    final nr = n + m2;
    final tr = mr + nr;
    var val1 = expandWidth(sign: s, m: m1, n: tr - m1);
    var val2 = other.expandWidth(sign: s, m: tr - other.n);
    // Convert to positive as needed
    if (s) {
      if (val1[-1] == LogicValue.one) {
        val1 = ~(val1 - 1);
      }
      if (val2[-1] == LogicValue.one) {
        val2 = ~(val2 - 1);
      }
    }
    var val = val1 / val2;
    // Convert to negative as needed
    if (s & (value[-1] != other.value[-1])) {
      val = (~val) + 1;
    }
    return FixedPointValue(value: val, signed: s, m: mr, n: nr);
  }
}
