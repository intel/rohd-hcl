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
/// Texas Instruments: (https://www.ti.com/lit/ug/spru565b/spru565b.pdf).
@immutable
class FixedPointValue implements Comparable<FixedPointValue> {
  /// The fixed point value bit storage in two's complement.
  late final LogicValue value = [integer, fraction].swizzle();

  /// The integer valuue portion.
  late final LogicValue integer;

  /// The fractional value portion.
  late final LogicValue fraction;

  /// [integerWidth] is the number of bits reserved for the integer part.
  late final int integerWidth;

  /// [fractionWidth] is the number of bits reserved for the fractional part.
  late final int fractionWidth;

  /// [signed] indicates whether the representation is signed.
  late final bool signed;

  /// Returns `true` if the number is negative.
  bool isNegative() => signed & (value[-1] == LogicValue.one);

  /// Constructs [FixedPointValue] from [integer] and [fraction] values with a
  /// [signed] option to interpret MSB of [integer] as sign bit with the
  /// [integer] represented in twos-complement.
  factory FixedPointValue(
          {required LogicValue integer,
          required LogicValue fraction,
          bool signed = false}) =>
      populator(
              integerWidth: integer.width - (signed ? 1 : 0),
              fractionWidth: fraction.width)
          .populate(integer: integer, fraction: fraction);

  /// Creates an unpopulated version of a [FixedPointValue], intended to be
  /// called with the [populator].
  @protected
  FixedPointValue.uninitialized({this.signed = false});

  /// Creates a [FixedPointValuePopulator] with the provided [integerWidth]
  /// and [fractionWidth], which can then be used to complete construction of
  /// a [FixedPointValue] using population functions.
  static FixedPointValuePopulator populator(
          {required int integerWidth,
          required int fractionWidth,
          bool signed = false}) =>
      FixedPointValuePopulator(FixedPointValue.uninitialized(signed: signed)
        ..integerWidth = integerWidth
        ..fractionWidth = fractionWidth);

  /// Creates a [FixedPointValuePopulator] for the same type as `this` and
  /// with the same widths.
  ///
  /// This must be overridden in subclasses so that the correct type of
  /// [FixedPointValuePopulator] is returned for generating equivalent types
  /// of [FixedPointValue]s.
  @mustBeOverridden
  FixedPointValuePopulator clonePopulator() =>
      FixedPointValuePopulator(FixedPointValue.uninitialized(signed: signed)
        ..integerWidth = integerWidth
        ..fractionWidth = fractionWidth);

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
    final m = max(integerWidth, other.integerWidth);
    final n = max(fractionWidth, other.fractionWidth);
    final val1 =
        FixedPointValue.populator(integerWidth: m, fractionWidth: n, signed: s)
            .widen(this)
            .value;
    final val2 =
        FixedPointValue.populator(integerWidth: m, fractionWidth: n, signed: s)
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

  /// Equal-to operation that returns a [LogicValue].
  @Deprecated('This operator will be removed, please use == instead.')
  LogicValue eq(FixedPointValue other) =>
      compareTo(other) == 0 ? LogicValue.one : LogicValue.zero;

  /// Not equal-to operation that returns a [LogicValue].
  @Deprecated('This operator will be removed, please use != instead.')
  LogicValue neq(FixedPointValue other) =>
      compareTo(other) != 0 ? LogicValue.one : LogicValue.zero;

  /// Less-than operation that returns a [LogicValue].
  @Deprecated(
      'This operator will be replaced with a boolean return in the future.'
      ' Use .ltBool(other) for the time being.')
  LogicValue operator <(FixedPointValue other) =>
      compareTo(other) < 0 ? LogicValue.one : LogicValue.zero;

  /// Less-than operation that returns a [LogicValue].
  @Deprecated(
      'This operator will be replaced with a boolean return in the future. '
      'Use .lteBool(other) for the time being.')
  LogicValue operator <=(FixedPointValue other) =>
      compareTo(other) <= 0 ? LogicValue.one : LogicValue.zero;

  /// Less-than operation that returns a [LogicValue].
  @Deprecated(
      'This operator will be replaced with a boolean return in the future.'
      ' Use .gtBool(other) for the time being.')
  LogicValue operator >(FixedPointValue other) =>
      compareTo(other) > 0 ? LogicValue.one : LogicValue.zero;

  /// Less-than operation that returns a [LogicValue].
  @Deprecated(
      'This operator will be replaced with a boolean return in the future. '
      'Use .gteBool(other) for the time being.')
  LogicValue operator >=(FixedPointValue other) =>
      compareTo(other) >= 0 ? LogicValue.one : LogicValue.zero;

  /// Less-than operation that returns a [bool].
  bool ltBool(FixedPointValue other) => compareTo(other) < 0;

  /// Less-than-or-equal operation that returns a [bool].
  bool lteBool(FixedPointValue other) => compareTo(other) <= 0;

  /// Greater-than operation that returns a [bool].
  bool gtBool(FixedPointValue other) => compareTo(other) > 0;

  /// Greater-than-or-equal operation that returns a [bool].
  bool gteBool(FixedPointValue other) => compareTo(other) >= 0;

  @override
  int get hashCode =>
      value.hashCode ^
      signed.hashCode ^
      integerWidth.hashCode ^
      fractionWidth.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is! FixedPointValue) {
      return false;
    }
    return compareTo(other) == 0;
  }

  /// Return a string representation of [FixedPointValue].
  /// Return sign, integer, fraction as binary strings.
  @override
  String toString() => "(${signed ? '${value[-1].bitString} ' : ''}"
      "${integerWidth > 0 ? '${value.getRange(fractionWidth).bitString} ' : ''}"
      '${value.slice(fractionWidth - 1, 0).bitString})';

  /// Converts a fixed-point value to a Dart [double].
  double toDouble() {
    if (integerWidth + fractionWidth > 52) {
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
    final value = number.toDouble() / pow(2, fractionWidth).toDouble();
    return isNegative() ? -value : value;
  }

  /// Negate operation for [FixedPointValue].
  FixedPointValue negate() => clonePopulator().ofLogicValue((~value) + 1);

  /// Addition operation that returns a [FixedPointValue].
  /// The result is signed if one of the operands is signed.
  /// The result integer has the max integer width of the operands plus one.
  /// The result fraction has the max fractional width of the operands.
  FixedPointValue operator +(FixedPointValue other) {
    if (!value.isValid | !other.value.isValid) {
      throw RohdHclException('Inputs must be valid.');
    }
    final s = signed | other.signed;
    final nr = max(fractionWidth, other.fractionWidth);
    final mr = max(integerWidth, other.integerWidth) + 1;
    final val1 = FixedPointValue.populator(
            integerWidth: mr, fractionWidth: nr, signed: s)
        .widen(this)
        .value;
    final val2 = FixedPointValue.populator(
            integerWidth: mr, fractionWidth: nr, signed: s)
        .widen(other)
        .value;
    return FixedPointValue.populator(
            integerWidth: mr, fractionWidth: nr, signed: s)
        .ofLogicValue(val1 + val2);
  }

  /// Subtraction operation that returns a [FixedPointValue].
  /// The result is always signed.
  /// The result integer has the max integer width of the operands plus one.
  /// The result fraction has the max fractional width of the operands.
  FixedPointValue operator -(FixedPointValue other) {
    if (!value.isValid | !other.value.isValid) {
      throw RohdHclException('Inputs must be valid.');
    }
    const s = true;
    final nr = max(fractionWidth, other.fractionWidth);
    final mr = max(integerWidth, other.integerWidth) + 1;
    final val1 = FixedPointValue.populator(
            integerWidth: mr, fractionWidth: nr, signed: s)
        .widen(this)
        .value;
    final val2 = FixedPointValue.populator(
            integerWidth: mr, fractionWidth: nr, signed: s)
        .widen(other)
        .value;
    return FixedPointValue.populator(
            integerWidth: mr, fractionWidth: nr, signed: s)
        .ofLogicValue(val1 - val2);
  }

  /// Multiplication operation that returns a [FixedPointValue].
  /// The result is signed if one of the operands is signed.
  /// The result fraction width is the sum of fraction widths of operands.
  FixedPointValue operator *(FixedPointValue other) {
    if (!value.isValid | !other.value.isValid) {
      throw RohdHclException('Inputs must be valid.');
    }
    final s = signed | other.signed;
    final mr = s
        ? integerWidth + other.integerWidth + 1
        : integerWidth + other.integerWidth;
    final nr = fractionWidth + other.fractionWidth;
    final tr = mr + nr;
    final val1 = FixedPointValue.populator(
            integerWidth: tr - fractionWidth,
            fractionWidth: fractionWidth,
            signed: s)
        .widen(this)
        .value;
    final val2 = FixedPointValue.populator(
            integerWidth: tr - other.fractionWidth,
            fractionWidth: other.fractionWidth,
            signed: s)
        .widen(other)
        .value;
    return FixedPointValue.populator(
            integerWidth: mr, fractionWidth: nr, signed: s)
        .ofLogicValue(val1 * val2);
  }

  /// Division operation that returns a [FixedPointValue].
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
    final m1 = s ? integerWidth + 1 : integerWidth;
    final m2 = s ? other.integerWidth + 1 : other.integerWidth;
    final mr = m1 + other.fractionWidth;
    final nr = fractionWidth + m2;
    final tr = mr + nr;
    var val1 = FixedPointValue.populator(
            integerWidth: m1, fractionWidth: tr - m1, signed: s)
        .widen(this)
        .value;
    var val2 = FixedPointValue.populator(
            integerWidth: tr - other.fractionWidth,
            fractionWidth: other.fractionWidth,
            signed: s)
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
    return FixedPointValue.populator(
            integerWidth: mr, fractionWidth: nr, signed: s)
        .ofLogicValue(val);
  }
}
