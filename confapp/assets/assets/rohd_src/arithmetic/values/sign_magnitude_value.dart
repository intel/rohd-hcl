// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sign_magnitude_value.dart
// Representation of sign-magnitude values.
//
// 2025 September 8
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
export 'sign_magnitude_value_populator.dart';

/// An immutable representation of a sign-magnitude value.
@immutable
class SignMagnitudeValue implements Comparable<SignMagnitudeValue> {
  /// The sign magnitude value is stored as [sign] and [magnitude], but the
  /// combined [value] is also provided for convenience.
  late final LogicValue value = [sign, magnitude].swizzle();

  /// The sign bit.
  late final LogicValue sign;

  /// The magnitude bits.
  late final LogicValue magnitude;

  /// [width] is the width of the [magnitude].
  late final int width;

  /// Construct a [SignMagnitudeValue] from a [sign] and [magnitude].
  factory SignMagnitudeValue(
          {required LogicValue sign, required LogicValue magnitude}) =>
      populator(width: magnitude.width)
          .populate(sign: sign, magnitude: magnitude);

  /// Creates an unpopulated version of a [SignMagnitudeValue], intended to be
  /// called with the [populator].
  @protected
  SignMagnitudeValue.uninitialized();

  /// Creates a [SignMagnitudeValuePopulator] with the provided [width] which
  ///  can then be used to complete construction of a [SignMagnitudeValue] using
  ///  population functions.
  static SignMagnitudeValuePopulator populator({required int width}) =>
      SignMagnitudeValuePopulator(
          SignMagnitudeValue.uninitialized()..width = width);

  /// Creates a [SignMagnitudeValuePopulator] for the same type as `this` and
  /// with the same widths.
  ///
  /// This must be overridden in subclasses so that the correct type of
  /// [SignMagnitudeValuePopulator] is returned for generating equivalent types
  /// of [SignMagnitudeValue]s.
  @mustBeOverridden
  SignMagnitudeValuePopulator clonePopulator() => SignMagnitudeValuePopulator(
      SignMagnitudeValue.uninitialized()..width = width);

  /// Returns a negative integer if `this` less than [other],
  /// a positive integer if `this` greater than [other],
  /// and zero if `this` and [other] are equal.
  @override
  int compareTo(Object other) {
    if (other is! SignMagnitudeValue) {
      throw RohdHclException('Input must be of type SignMagnitudeValue');
    }
    if (!value.isValid | !other.value.isValid) {
      throw RohdHclException('Inputs must be valid.');
    }

    final maxWidth = max(width, other.width);
    final val1 = magnitude.zeroExtend(maxWidth);
    final val2 = other.magnitude.zeroExtend(maxWidth);
    if (sign == other.sign) {
      return val1.compareTo(val2) * ((sign == LogicValue.one) ? -1 : 1);
    } else {
      // different signs, negative is less than positive
      return sign == LogicValue.one ? -1 : 1;
    }
  }

  /// Less-than operator for [SignMagnitudeValue].
  bool operator <(SignMagnitudeValue other) => compareTo(other) < 0;

  /// Less-than-or-equal operator for [SignMagnitudeValue].
  bool operator <=(SignMagnitudeValue other) => compareTo(other) <= 0;

  /// Greater-than operator for [SignMagnitudeValue].
  bool operator >(SignMagnitudeValue other) => compareTo(other) > 0;

  /// Greater-than-or-equal operator for [SignMagnitudeValue].
  bool operator >=(SignMagnitudeValue other) => compareTo(other) >= 0;

  @override
  int get hashCode => value.hashCode ^ width.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is! SignMagnitudeValue) {
      return false;
    }
    return compareTo(other) == 0;
  }

  /// Return a string representation of [SignMagnitudeValue].
  /// Return sign, integer, fraction as binary strings.
  @override
  String toString() => "${sign == LogicValue.one ? '-' : ''}"
      '${magnitude.toBigInt()}';

  /// Negate operation for [SignMagnitudeValue].
  SignMagnitudeValue negate() => clonePopulator().populate(
      sign: sign == LogicValue.one ? LogicValue.zero : LogicValue.one,
      magnitude: magnitude);

  /// Convert to [BigInt].
  BigInt toBigInt() =>
      (sign == LogicValue.one ? BigInt.from(-1) : BigInt.from(1)) *
      magnitude.toBigInt();

  /// Convert to [int], throwing an exception if out of range.
  int toInt() {
    final bi = toBigInt();
    if (bi < -BigInt.two.pow(width) || bi >= BigInt.two.pow(width)) {
      throw RohdHclException('SignMagnitudeValue.toInt: value $bi out of '
          'range for width $width');
    }
    return bi.toInt();
  }
}
