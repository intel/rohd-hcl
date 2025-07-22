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

  /// [integerWidth] is the number of bits reserved for the integer part.
  late final int integerWidth;

  /// [fractionWidth] is the number of bits reserved for the fractional part.
  late final int fractionWidth;

  /// [signed] indicates whether the representation is signed.
  late final bool signed;

  /// Returns `true` if the number is negative.
  bool isNegative() => signed & (value[-1] == LogicValue.one);

  /// Constructs [FixedPointValue] from sign, integer and fraction values.
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
  LogicValue eq(FixedPointValue other) =>
      compareTo(other) == 0 ? LogicValue.one : LogicValue.zero;

  /// Not equal-to operation that returns a [LogicValue].
  LogicValue neq(FixedPointValue other) =>
      compareTo(other) != 0 ? LogicValue.one : LogicValue.zero;

  /// Less-than operation that returns a [LogicValue].
  LogicValue operator <(FixedPointValue other) =>
      compareTo(other) < 0 ? LogicValue.one : LogicValue.zero;

  /// Less-than operation that returns a [LogicValue].
  LogicValue operator <=(FixedPointValue other) =>
      compareTo(other) <= 0 ? LogicValue.one : LogicValue.zero;

  /// Less-than operation that returns a [LogicValue].
  LogicValue operator >(FixedPointValue other) =>
      compareTo(other) > 0 ? LogicValue.one : LogicValue.zero;

  /// Less-than operation that returns a [LogicValue].
  LogicValue operator >=(FixedPointValue other) =>
      compareTo(other) >= 0 ? LogicValue.one : LogicValue.zero;

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

  /// Converts a [FixedPointValue] to a [FloatingPointValue].
  FloatingPointValue toFloatingPointValue({required bool explicitJBit}) {
    if (!value.isValid) {
      throw RohdHclException('Inputs must be valid.');
    }

    // Qm.n need to be converted so we have it in the form (1.<MANTISSA>).
    const minmialExponentWidth = 4;
    var sign = value[-1];
    if (!signed) {
      sign = LogicValue.zero; // if not signed, we set sign to zero.
    }
    // need to verify if we have a signed representation or not.
    final fixedNum = sign.toBool() ? ~value + 1 : value;

    var firstOneIndex = 0;
    final LogicValue mantissaVal;
    final LogicValue exponentVal;

    // if we have a zero value, we can return a zero floating point value.
    if (fixedNum.isZero) {
      return FloatingPointValue(
          sign: LogicValue.zero,
          exponent: LogicValue.zero,
          mantissa: LogicValue.zero,
          explicitjBit: true);
    }

    // Count the leading zeros in order to correct the exponent value.
    for (var i = fixedNum.width - 1; i > 0; i--) {
      if (fixedNum[i] == LogicValue.one) {
        firstOneIndex = i;
        break;
      }
    }
    mantissaVal = explicitJBit
        ? fixedNum
            .slice(firstOneIndex, 0)
            .extend(firstOneIndex + 1, LogicValue.zero)
        : firstOneIndex == 0
            ? LogicValue.filled(integerWidth + fractionWidth, LogicValue.zero)
            : fixedNum.slice(firstOneIndex - 1, 0);

    // now we have (1.<MANTISSA>) so we can calculate the exponent.
    final radix = (fixedNum.width - 1) - integerWidth;
    var shiftAmnt = firstOneIndex - radix;
    if (!signed) {
      shiftAmnt -= 1; // shiftAmnt is reduced by one for unsigned.
    }
    if (explicitJBit && mantissaVal[mantissaVal.width - 1] == LogicValue.zero) {
      shiftAmnt += 1;
    }
    var expWidth = 0;
    if (shiftAmnt != 0) {
      // if shiftAmnt is not zero, we need to calculate the exponent width.
      expWidth = log2Ceil(shiftAmnt.abs()) << 1;
    }
    if (expWidth < minmialExponentWidth) {
      expWidth = minmialExponentWidth; // minimum exponent width needed.
    }
    // set the bias amount which is 2^(expWidth - 1) - 1.
    final bias = LogicValue.ofInt((pow(2, expWidth - 1) - 1).toInt(), expWidth);
    // bias our exponent value.
    exponentVal = LogicValue.ofInt(shiftAmnt, expWidth) + bias;

    return FloatingPointValue(
        sign: sign,
        exponent: exponentVal,
        mantissa: mantissaVal,
        explicitjBit: explicitJBit);
  }

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
