// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sign_magnitude_value_populator.dart
// Populator for sign-magnitude values.
//
// 2025 September 8
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A populator for [SignMagnitudeValue]s, a utility that can populate various
/// forms of [SignMagnitudeValue]s.
class SignMagnitudeValuePopulator<SmvType extends SignMagnitudeValue> {
  /// An unpopulated [SignMagnitudeValue] that this populator will populate.
  ///
  /// The `late final` variables will not yet be initialized until after this
  /// populator is used to [populate] it.
  final SmvType _unpopulated;

  /// The width of the magnitude field.
  int get width => _unpopulated.width;

  /// Whether or not this populator has already populated values.
  bool _hasPopulated = false;

  /// Creates a [SignMagnitudeValuePopulator] for the given [_unpopulated]
  /// [SignMagnitudeValue].
  SignMagnitudeValuePopulator(this._unpopulated);

  /// Populates the [SignMagnitudeValue] with the given [sign] and
  /// [magnitude], then performs additional validation.
  SmvType populate({required LogicValue sign, required LogicValue magnitude}) {
    if (_hasPopulated) {
      throw RohdHclException('SignMagnitudeValuePopulator: already populated');
    }
    _hasPopulated = true;

    return _unpopulated
      ..sign = sign
      ..magnitude = magnitude;
  }

  /// Populates a [SignMagnitudeValue] from an integer [intValue].
  SmvType ofInt(int intValue) {
    final sign = LogicValue.ofBool(intValue < 0);
    final magnitude = LogicValue.ofInt(intValue.abs(), width);
    return populate(sign: sign, magnitude: magnitude);
  }

  /// Populates a [SignMagnitudeValue] from a big integer [intValue].
  SmvType ofBigInt(BigInt intValue) {
    final sign = LogicValue.ofBool(intValue.isNegative);
    final magnitude = LogicValue.ofBigInt(intValue.abs(), width);
    return populate(sign: sign, magnitude: magnitude);
  }

  /// Generate a random [SignMagnitudeValue] in a signed range.
  ///
  /// The range is defined by one of the following combinations of range
  /// parameters:
  /// - [gt], [lt]: generate a value in the range `([gt], [lt])`
  /// - [gte], [lt]: generate a value in the range `[[gte], [lt])`
  /// - [gt], [lte]: generate a value in the range `([gt], [lte]]`
  /// - [gte], [lte]: generate a value in the range `[[gte], [lte]]`
  /// - [gt]: generate a value in the range `([gt], ∞)`
  /// - [gte]: generate a value in the range `[[gte], ∞)`
  /// - [lt]: generate a value in the range `(-∞, [lt])`
  /// - [lte]: generate a value in the range `(-∞, [lte]]`
  /// - none: generate a value in the range `(-∞, ∞)`
  SmvType random(Random rv,
      {SignMagnitudeValue? gt,
      SignMagnitudeValue? gte,
      SignMagnitudeValue? lt,
      SignMagnitudeValue? lte}) {
    if ((gt != null) & (gte != null)) {
      throw RohdHclException('randomSignMagnitude: cannot have both '
          'gt and gte');
    }
    if ((lt != null) & (lte != null)) {
      throw RohdHclException('randomSignMagnitude: cannot have both '
          'lt and lte');
    }
    final lowerLimitSign = (gt ?? gte)?.sign ?? LogicValue.one;
    final isUpperZero = LogicValue.of((lte ?? lt)?.magnitude.isZero ?? false);
    final isLowerZero = LogicValue.of((gte ?? gt)?.magnitude.isZero ?? false);
    final upperLimitSign =
        ((lt ?? lte)?.sign ?? LogicValue.zero) | (isUpperZero & ~isLowerZero);

    if ((lowerLimitSign == LogicValue.zero) &
        (upperLimitSign == LogicValue.one)) {
      throw RohdHclException('randomSignMagnitude: cannot have positive '
          'lower limit with negative upper limit');
    }

    final one = BigInt.from(1);
    final zero = BigInt.from(0);
    final max = BigInt.two.pow(width) - one;

    final posLowerLimit = (lowerLimitSign == LogicValue.zero)
        ? gte?.magnitude.toBigInt() ?? (gt?.magnitude.toBigInt() ?? -one) + one
        : zero;

    final posUpperLimit = (upperLimitSign == LogicValue.zero)
        ? (lte?.magnitude.toBigInt() ??
            (lt?.magnitude.toBigInt() ?? max + one) - one)
        : zero;

    final negLowerLimit = (upperLimitSign == LogicValue.one)
        ? lte?.magnitude.toBigInt() ?? (lt?.magnitude.toBigInt() ?? -one) + one
        : zero;

    final negUpperLimit = (lowerLimitSign == LogicValue.one)
        ? gte?.magnitude.toBigInt() ??
            ((gt?.magnitude.toBigInt() ?? max + one) - one)
        : zero;

    final sign = (lowerLimitSign == upperLimitSign)
        ? lowerLimitSign
        : (negUpperLimit - negLowerLimit) > zero
            ? (rv.nextBool() ? LogicValue.zero : LogicValue.one)
            : LogicValue.zero;

    final LogicValue magnitude;
    final BigInt limit;
    final BigInt lower;
    if (sign == LogicValue.zero) {
      limit = posUpperLimit - posLowerLimit + one;
      lower = posLowerLimit;
    } else {
      limit = negUpperLimit - negLowerLimit + one;
      lower = negLowerLimit;
    }

    if (lower > max) {
      throw RohdHclException('randomSignMagnitude: invalid range, cannot '
          'generate value');
    }
    if (limit <= zero) {
      throw RohdHclException('randomSignMagnitude: invalid tight range, cannot '
          'generate value');
    }

    magnitude = rv.nextLogicValue(width: width, max: limit) +
        LogicValue.ofBigInt(lower, width);

    return populate(sign: sign, magnitude: magnitude);
  }
}
