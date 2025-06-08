// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_value_populator.dart
// Populator for Floating Point Values
//
// 2025 june 8, 2025
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A populator for [FixedPointValue]s, a utility that can populate various
/// forms of [FixedPointValue]s.
class FixedPointValuePopulator<FpvType extends FixedPointValue> {
  /// An unpopulated [FixedPointValue] that this populator will populate.
  ///
  /// The `late final` variables will not yet be initialized until after this
  /// populator is used to [populate] it.
  final FpvType _unpopulated;

  /// The width of the exponent field.
  int get integerWidth => _unpopulated.mWidth;

  /// The width of the mantissa field.
  int get fractionWidth => _unpopulated.nWidth;

  /// Return whether the [FixedPointValue] is signed.
  bool get signed => _unpopulated.signed;

  /// Whether or not this populator has already populated values.
  bool _hasPopulated = false;

  /// Creates a [FixedPointValuePopulator] for the given [_unpopulated]
  /// [FixedPointValue].
  FixedPointValuePopulator(this._unpopulated);

  /// Extracts a [FixedPointValue] from a [FixedPoint]'s current `value`.
  FpvType ofFixedPoint(FixedPoint fp) => populate(
        integer: fp.integer.value,
        fraction: fp.fraction.value,
      );

  @override
  String toString() => 'FixedPointValuePopulator<${_unpopulated.runtimeType}>';

  /// Populates the [FixedPointValue] with the given [integer] and
  /// [fraction], then performs additional validation.
  FpvType populate(
      {required LogicValue integer, required LogicValue fraction}) {
    if (_hasPopulated) {
      throw RohdHclException('FixedPointPopulator: already populated');
    }
    _hasPopulated = true;

    return _unpopulated
      ..integer = integer
      ..fraction = fraction;
  }

  /// Construct a [FixedPointValue] from a [LogicValue]
  FpvType ofLogicValue(LogicValue val) => populate(
        integer: val.getRange(
            fractionWidth, integerWidth + fractionWidth + (signed ? 1 : 0)),
        fraction: val.getRange(0, fractionWidth),
      );

  /// Return true if double [val] to be stored in [FixedPointValue]
  /// with [m] and [n] lengths without overflowing.
  static bool canStore(double val,
      {required bool signed, required int m, required int n}) {
    final w = signed ? 1 + m + n : m + n;
    if (val.isFinite) {
      final bigIntegerValue = BigInt.from(val * pow(2, n));
      final negBigIntegerValue = BigInt.from(-val * pow(2, n));
      final l = (val < 0.0)
          ? max(bigIntegerValue.bitLength, negBigIntegerValue.bitLength)
          : bigIntegerValue.bitLength;
      return l <= w;
    }
    return false;
  }

  /// Constructs [FixedPointValue] from a Dart [double] rounding away from zero.
  FpvType ofDouble(double val) {
    final m = integerWidth;
    final n = fractionWidth;
    final signed = _unpopulated.signed;
    if (!signed & (val < 0)) {
      throw RohdHclException('Negative input not allowed with unsigned');
    }
    if (!canStore(val, signed: signed, m: m, n: n)) {
      throw RohdHclException('Double is too long to store in '
          'FixedPointValue: $m, $n');
    }
    final integerValue = BigInt.from(val * pow(2, n));
    final w = signed ? 1 + m + n : m + n;
    final v = LogicValue.ofBigInt(integerValue, w);
    return ofLogicValue(v);
  }

  /// Constructs [FixedPointValue] from a Dart [double] without rounding.
  FpvType ofDoubleUnrounded(double val) {
    final m = integerWidth;
    final n = fractionWidth;
    final signed = _unpopulated.signed;
    if (!signed & (val < 0)) {
      throw RohdHclException('Negative input not allowed with unsigned');
    }
    final integerValue = BigInt.from(val * pow(2, n + 1));
    final w = signed ? 1 + m + n : m + n;
    final v = LogicValue.ofBigInt(integerValue >> 1, w);
    return ofLogicValue(v);
  }

  /// Constructs a [FixedPointValue] from another [FixedPointValue] with
  /// by widening the integer and/or fraction widths.
  FpvType widen(FpvType fpv) {
    if ((fpv.mWidth > integerWidth) || (fpv.nWidth > fractionWidth)) {
      throw RohdHclException('Cannot expand from $fpv to $_unpopulated');
    }

    var newInteger = fpv.signed
        ? fpv.integer.signExtend(fpv.integer.width + integerWidth - fpv.mWidth)
        : fpv.integer.zeroExtend(fpv.integer.width + integerWidth - fpv.mWidth);
    if (signed & !fpv.signed) {
      newInteger = newInteger.zeroExtend(newInteger.width + 1);
    }

    final newFraction =
        fpv.fraction.reversed.zeroExtend(fractionWidth).reversed;
    return populate(integer: newInteger, fraction: newFraction);
  }

  //   LogicValue expandWidth({required bool sign, int m = 0, int n = 0}) {
  //   if ((m < 0) | (n < 0)) {
  //     throw RohdHclException('Input width must be non-negative.');
  //   }
  //   if ((m > 0) & (m < mWidth)) {
  //     throw RohdHclException('Integer width is larger than input.');
  //   }
  //   if ((n > 0) & (n < nWidth)) {
  //     throw RohdHclException('Fraction width is larger than input.');
  //   }
  //   var newValue = value;
  //   if (m >= mWidth) {
  //     if (signed) {
  //       newValue = newValue.signExtend(newValue.width + m - mWidth);
  //     } else {
  //       newValue = newValue.zeroExtend(newValue.width + m - mWidth);
  //       if (sign) {
  //         newValue = newValue.zeroExtend(newValue.width + 1);
  //       }
  //     }
  //   }
  //   if (n > nWidth) {
  //     newValue =
  //         newValue.reversed.zeroExtend(newValue.width + n - nWidth).reversed;
  //   }
  //   return newValue;
  // }
}
