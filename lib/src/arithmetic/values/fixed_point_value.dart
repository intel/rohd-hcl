// Copyright (C) 2024-2025 Intel Corporation
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
export 'fixed_point_populator.dart';

/// An immutable representation of (un)signed fixed-point values following
/// Q notation (Qm.n format) as introduced by
/// (Texas Instruments)[https://www.ti.com/lit/ug/spru565b/spru565b.pdf].
@immutable
class FixedPointValue implements Comparable<FixedPointValue> {
  /// The fixed point value bit storage in two's complement.
  late final LogicValue value = [integer, fraction].swizzle();

  /// The integer valuue portion.
  late final LogicValue integer;

  /// The fractional value portion.
  late final LogicValue fraction;

  /// [mWidth] is the number of bits reserved for the integer part.
  late final int mWidth;

  /// [nWidth] is the number of bits reserved for the fractional part.
  late final int nWidth;

  /// [signed] indicates whether the representation is signed.
  bool get signed => _signed;

  late final bool _signed;

  /// Returns true if the number is negative.
  bool isNegative() => signed & (value[-1] == LogicValue.one);

  /// Constructs [FixedPointValue] from sign, integer and fraction values.
  factory FixedPointValue(
          {required LogicValue integer,
          required LogicValue fraction,
          bool signed = false}) =>
      populator(
              mWidth: integer.width - (signed ? 1 : 0), nWidth: fraction.width)
          .populate(integer: integer, fraction: fraction);

  /// Creates an unpopulated version of a [FixedPointValue], intended to be
  /// called with the [populator].
  @protected
  FixedPointValue.uninitialized({bool signed = false}) : _signed = signed;

  /// Creates a [FixedPointValuePopulator] with the provided [mWidth]
  /// and [nWidth], which can then be used to complete construction of
  /// a [FixedPointValue] using population functions.
  static FixedPointValuePopulator populator(
          {required int mWidth, required int nWidth, bool signed = false}) =>
      FixedPointValuePopulator(FixedPointValue.uninitialized(signed: signed)
        ..mWidth = mWidth
        ..nWidth = nWidth);

  /// Creates a [FixedPointValuePopulator] for the same type as `this` and
  /// with the same widths.
  ///
  /// This must be overridden in subclasses so that the correct type of
  /// [FixedPointValuePopulator] is returned for generating equivalent types
  /// of [FixedPointValue]s.
  @mustBeOverridden
  FixedPointValuePopulator clonePopulator() =>
      FixedPointValuePopulator(FixedPointValue.uninitialized(signed: signed)
        ..mWidth = mWidth
        ..nWidth = nWidth);

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
    final m = max(mWidth, other.mWidth);
    final n = max(nWidth, other.nWidth);
    final val1 = FixedPointValue.populator(mWidth: m, nWidth: n, signed: s)
        .widen(this)
        .value;
    final val2 = FixedPointValue.populator(mWidth: m, nWidth: n, signed: s)
        .widen(other)
        .value;
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
  int get hashCode =>
      value.hashCode ^ signed.hashCode ^ mWidth.hashCode ^ nWidth.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is! FixedPointValue) {
      return false;
    }
    return compareTo(other) == 0;
  }

  /// Return a string representation of [FixedPointValue].
  ///  return sign, integer, fraction as binary strings.
  @override
  String toString() => "(${signed ? '${value[-1].bitString} ' : ''}"
      "${(mWidth > 0) ? '${value.getRange(nWidth).bitString} ' : ''}"
      '${value.slice(nWidth - 1, 0).bitString})';

  /// Converts a fixed-point value to a Dart [double].
  double toDouble() {
    if (mWidth + nWidth > 52) {
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
    final value = number.toDouble() / pow(2, nWidth).toDouble();
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
    final nr = max(nWidth, other.nWidth);
    final mr = max(mWidth, other.mWidth) + 1;
    final val1 = FixedPointValue.populator(mWidth: mr, nWidth: nr, signed: s)
        .widen(this)
        .value;
    final val2 = FixedPointValue.populator(mWidth: mr, nWidth: nr, signed: s)
        .widen(other)
        .value;
    return FixedPointValue.populator(mWidth: mr, nWidth: nr, signed: s)
        .ofLogicValue(val1 + val2);
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
    final nr = max(nWidth, other.nWidth);
    final mr = max(mWidth, other.mWidth) + 1;
    final val1 = FixedPointValue.populator(mWidth: mr, nWidth: nr, signed: s)
        .widen(this)
        .value;
    final val2 = FixedPointValue.populator(mWidth: mr, nWidth: nr, signed: s)
        .widen(other)
        .value;
    return FixedPointValue.populator(mWidth: mr, nWidth: nr, signed: s)
        .ofLogicValue(val1 - val2);
  }

  /// Multiplication operation that returns a FixedPointValue.
  /// The result is signed if one of the operands is signed.
  /// The result fraction width is the sum of fraction widths of operands.
  FixedPointValue operator *(FixedPointValue other) {
    if (!value.isValid | !other.value.isValid) {
      throw RohdHclException('Inputs must be valid.');
    }
    final s = signed | other.signed;
    final mr = s ? mWidth + other.mWidth + 1 : mWidth + other.mWidth;
    final nr = nWidth + other.nWidth;
    final tr = mr + nr;
    final val1 = FixedPointValue.populator(
            mWidth: tr - nWidth, nWidth: nWidth, signed: s)
        .widen(this)
        .value;
    final val2 = FixedPointValue.populator(
            mWidth: tr - other.nWidth, nWidth: other.nWidth, signed: s)
        .widen(other)
        .value;
    return FixedPointValue.populator(mWidth: mr, nWidth: nr, signed: s)
        .ofLogicValue(val1 * val2);
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
    final m1 = s ? mWidth + 1 : mWidth;
    final m2 = s ? other.mWidth + 1 : other.mWidth;
    final mr = m1 + other.nWidth;
    final nr = nWidth + m2;
    final tr = mr + nr;
    var val1 = FixedPointValue.populator(mWidth: m1, nWidth: tr - m1, signed: s)
        .widen(this)
        .value;
    var val2 = FixedPointValue.populator(
            mWidth: tr - other.nWidth, nWidth: other.nWidth, signed: s)
        .widen(other)
        .value;
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
    if (isNegative() != other.isNegative()) {
      val = (~val) + 1;
    }
    return FixedPointValue.populator(mWidth: mr, nWidth: nr, signed: s)
        .ofLogicValue(val);
  }
}
