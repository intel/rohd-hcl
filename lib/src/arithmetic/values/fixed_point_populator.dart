// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_point_value_populator.dart
// Populator for Fixed Point Values
//
// 2025 June 8, 2025
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A populator for [FixedPointValue]s, a utility that can populate various
/// forms of [FixedPointValue]s.
class FixedPointValuePopulator<FxvType extends FixedPointValue> {
  /// An unpopulated [FixedPointValue] that this populator will populate.
  ///
  /// The `late final` variables will not yet be initialized until after this
  /// populator is used to [populate] it.
  final FxvType _unpopulated;

  /// The width of the exponent field.
  int get integerWidth => _unpopulated.integerWidth;

  /// The width of the mantissa field.
  int get fractionWidth => _unpopulated.fractionWidth;

  /// Return whether the [FixedPointValue] is signed.
  bool get signed => _unpopulated.signed;

  /// Whether or not this populator has already populated values.
  bool _hasPopulated = false;

  /// Creates a [FixedPointValuePopulator] for the given [_unpopulated]
  /// [FixedPointValue].
  FixedPointValuePopulator(this._unpopulated);

  /// Extracts a [FixedPointValue] from a [FixedPoint]'s current `value`.
  FxvType ofFixedPoint(FixedPoint fp) => populate(
        integer: fp.integer.value,
        fraction: fp.fraction.value,
      );

  @override
  String toString() => 'FixedPointValuePopulator<${_unpopulated.runtimeType}>';

  /// Populates the [FixedPointValue] with the given [integer] and
  /// [fraction], then performs additional validation.
  FxvType populate(
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
  FxvType ofLogicValue(LogicValue val) => populate(
        integer: val.getRange(
            fractionWidth, integerWidth + fractionWidth + (signed ? 1 : 0)),
        fraction: val.getRange(0, fractionWidth),
      );

  /// Return `true` if double [val] to be stored in [FixedPointValue]
  /// with [integerWidth] and [fractionWidth] lengths without overflowing.
  static bool canStore(double val,
      {required bool signed,
      required int integerWidth,
      required int fractionWidth,
      FloatingPointRoundingMode roundingMode =
          FloatingPointRoundingMode.truncate}) {
    if (!val.isFinite) {
      return false;
    }
    final exact =
        FloatingPoint64Value.populator().ofDouble(val).toScaledBigInt();
    if (!signed && exact.significand.isNegative) {
      return false;
    }
    final shift = exact.exponent + fractionWidth;
    final scaled = shift >= 0
        ? exact.significand << shift
        : roundBigIntByPowerOfTwo(exact.significand, -shift,
            roundingMode: roundingMode);
    final width = integerWidth + fractionWidth + (signed ? 1 : 0);
    if (width < 1) {
      return false;
    }
    final minValue = signed ? -(BigInt.one << (width - 1)) : BigInt.zero;
    final maxValue = signed
        ? (BigInt.one << (width - 1)) - BigInt.one
        : (BigInt.one << width) - BigInt.one;
    return scaled >= minValue && scaled <= maxValue;
  }

  /// Constructs a [FixedPointValue] from a Dart [double].
  ///
  /// [roundingMode] defaults to truncation to preserve the historical behavior
  /// of this method.
  FxvType ofDouble(double val,
      {FloatingPointRoundingMode roundingMode =
          FloatingPointRoundingMode.truncate}) {
    if (!val.isFinite) {
      throw RohdHclException(
          'NaN and infinity cannot be converted to FixedPointValue.');
    }
    final fpv = FloatingPoint64Value.populator().ofDouble(val);
    return ofFloatingPointValue(fpv, roundingMode: roundingMode);
  }

  /// Constructs [FixedPointValue] from a Dart [double] without rounding.
  @internal
  FxvType ofDoubleUnrounded(double val) {
    if (!signed & (val < 0)) {
      throw RohdHclException('Negative input not allowed with unsigned');
    }
    final integerValue = BigInt.from(val * pow(2, fractionWidth + 1));
    final width = integerWidth + fractionWidth + (signed ? 1 : 0);
    return ofLogicValue(LogicValue.ofBigInt(integerValue >> 1, width));
  }

  /// Constructs a value equal to [significand] times two to [exponent].
  ///
  /// The exact dyadic value is rounded once into this fixed-point format.
  FxvType ofScaledBigInt(BigInt significand, int exponent,
      {FloatingPointRoundingMode roundingMode =
          FloatingPointRoundingMode.truncate}) {
    if (!signed && significand.isNegative) {
      throw RohdHclException('Negative input not allowed with unsigned');
    }

    final shift = exponent + fractionWidth;
    final scaled = shift >= 0
        ? significand << shift
        : roundBigIntByPowerOfTwo(significand, -shift,
            roundingMode: roundingMode);
    final width = integerWidth + fractionWidth + (signed ? 1 : 0);
    if (width < 1) {
      throw RohdHclException('FixedPointValue width must be positive.');
    }
    final minValue = signed ? -(BigInt.one << (width - 1)) : BigInt.zero;
    final maxValue = signed
        ? (BigInt.one << (width - 1)) - BigInt.one
        : (BigInt.one << width) - BigInt.one;
    if (scaled < minValue || scaled > maxValue) {
      throw RohdHclException('Value cannot be represented by FixedPointValue '
          'with integerWidth=$integerWidth, fractionWidth=$fractionWidth, '
          'signed=$signed.');
    }

    return ofLogicValue(LogicValue.ofBigInt(scaled, width));
  }

  /// Converts [fpv] directly into this fixed-point format.
  ///
  /// NaN and infinity cannot be represented and cause an exception.
  FxvType ofFloatingPointValue(FloatingPointValue fpv,
      {FloatingPointRoundingMode roundingMode =
          FloatingPointRoundingMode.truncate}) {
    final exact = fpv.toScaledBigInt();
    return ofScaledBigInt(exact.significand, exact.exponent,
        roundingMode: roundingMode);
  }

  /// Constructs a [FixedPointValue] from another [FixedPointValue] with
  /// by widening the integer and/or fraction widths.
  FxvType widen(FxvType fxv) {
    if ((fxv.integerWidth > integerWidth) ||
        (fxv.fractionWidth > fractionWidth)) {
      throw RohdHclException('Cannot expand from $fxv to $_unpopulated');
    }

    var newInteger = fxv.signed
        ? fxv.integer
            .signExtend(fxv.integer.width + integerWidth - fxv.integerWidth)
        : fxv.integer
            .zeroExtend(fxv.integer.width + integerWidth - fxv.integerWidth);
    if (signed & !fxv.signed) {
      newInteger = newInteger.zeroExtend(newInteger.width + 1);
    }

    final newFraction =
        fxv.fraction.reversed.zeroExtend(fractionWidth).reversed;
    return populate(integer: newInteger, fraction: newFraction);
  }

  void _checkMatching(String name, FxvType? fxv) {
    if (fxv != null) {
      if (fxv.integerWidth != integerWidth) {
        throw RohdHclException(
            'FixedPointValuePopulator.random: $name integerWidth mismatch: '
            '${fxv.integerWidth} vs $integerWidth');
      }
      if (fxv.fractionWidth != fractionWidth) {
        throw RohdHclException(
            'FixedPointValuePopulator.random: $name fractionWidth mismatch: '
            '${fxv.fractionWidth} vs $fractionWidth');
      }
      if (fxv.signed != signed) {
        throw RohdHclException(
            'FixedPointValuePopulator.random: $name signed mismatch: '
            '${fxv.signed} vs $signed');
      }
    }
  }

  /// Generate a random [FixedPointValue], using random seed [rv].
  ///
  /// This generates a valid [FixedPointValue] anywhere in the range specified.
  /// The range is interpreted as follows:
  /// - [gt], [lt]: generate a value in the range `([gt], [lt])`
  /// - [gte], [lt]: generate a value in the range `[[gte], [lt])`
  /// - [gt], [lte]: generate a value in the range `([gt], [lte]]`
  /// - [gte], [lte]: generate a value in the range `[[gte], [lte]]`
  /// - [gt]: generate a value in the range `([gt], ∞)`
  /// - [gte]: generate a value in the range `[[gte], ∞)`
  /// - [lt]: generate a value in the range `(-∞, [lt])`
  /// - [lte]: generate a value in the range `(-∞, [lte]]`
  /// - none: generate a value in the range `(-∞, ∞)`
  FxvType random(Random rv,
      {bool subNormal = false, // if true generate only subnormal numbers
      bool genNormal = true,
      bool genSubNormal = true,
      FxvType? gt,
      FxvType? lt,
      FxvType? gte,
      FxvType? lte}) {
    _checkMatching('gt', gt);
    _checkMatching('lt', lt);
    _checkMatching('gte', gte);
    _checkMatching('lte', lte);

    if (gt != null) {
      if (lt != null) {
        if (gt.compareTo(lt) >= 0) {
          throw RohdHclException(
              'FloatingPointValuePopulator.random: cannot have $gt >= '
              '$lt');
        }
      } else if (lte != null) {
        if (gt.compareTo(lte) > 0) {
          throw RohdHclException(
              'FloatingPointValuePopulator.random: cannot have $gt > '
              '$lte');
        }
      }
    } else if (gte != null) {
      if (lt != null) {
        if (gte.compareTo(lt) >= 0) {
          throw RohdHclException(
              'FloatingPointValuePopulator.random: cannot have $gte >= '
              '$lt');
        }
      } else if (lte != null) {
        if (gte.compareTo(lte) > 0) {
          throw RohdHclException(
              'FloatingPointValuePopulator.random: cannot have $gte > '
              '$lte');
        }
      }
    }

    final gtSign =
        signed ? (gt ?? gte)?.value[-1] ?? LogicValue.one : LogicValue.zero;
    final ltSign =
        signed ? (lt ?? lte)?.value[-1] ?? LogicValue.zero : LogicValue.zero;

    final gtMagnitude = gt?.value.abs();
    final gteMagnitude = gte?.value.abs();
    final ltMagnitude = lt?.value.abs();
    final lteMagnitude = lte?.value.abs();

    final tgt = (gtMagnitude == null)
        ? null
        : SignMagnitudeValue(sign: gtSign, magnitude: gtMagnitude);
    final tgte = (gteMagnitude == null)
        ? null
        : SignMagnitudeValue(sign: gtSign, magnitude: gteMagnitude);
    final tlt = (ltMagnitude == null)
        ? null
        : SignMagnitudeValue(sign: ltSign, magnitude: ltMagnitude);
    final tlte = (lteMagnitude == null)
        ? null
        : SignMagnitudeValue(sign: ltSign, magnitude: lteMagnitude);

    final smv =
        SignMagnitudeValue.populator(width: integerWidth + fractionWidth)
            .random(rv, gt: tgt, gte: tgte, lt: tlt, lte: tlte);
    final newValue =
        signed ? [smv.sign, smv.magnitude].swizzle() : smv.magnitude;
    return ofLogicValue(newValue);
  }
}
