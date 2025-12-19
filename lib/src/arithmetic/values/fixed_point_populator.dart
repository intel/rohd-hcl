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
      required int fractionWidth}) {
    final w = signed
        ? 1 + integerWidth + fractionWidth
        : integerWidth + fractionWidth;
    if (val.isFinite) {
      final bigIntegerValue = BigInt.from(val * pow(2.0, fractionWidth));
      final negBigIntegerValue = BigInt.from(-val * pow(2.0, fractionWidth));
      final l = (val < 0.0)
          ? max(bigIntegerValue.bitLength, negBigIntegerValue.bitLength)
          : bigIntegerValue.bitLength;
      return l <= w;
    }
    return false;
  }

  /// Constructs [FixedPointValue] from a Dart [double] rounding away from zero.
  FxvType ofDouble(double val) {
    final signed = _unpopulated.signed;
    if (!signed & (val < 0)) {
      throw RohdHclException('Negative input not allowed with unsigned');
    }
    if (!canStore(val,
        signed: signed,
        integerWidth: integerWidth,
        fractionWidth: fractionWidth)) {
      throw RohdHclException('Double is too long to store in '
          'FixedPointValue: $integerWidth, $fractionWidth');
    }
    final integerValue = BigInt.from(val * pow(2, fractionWidth));
    final w = signed
        ? 1 + integerWidth + fractionWidth
        : integerWidth + fractionWidth;
    final v = LogicValue.ofBigInt(integerValue, w);
    return ofLogicValue(v);
  }

  /// Constructs [FixedPointValue] from a Dart [double] without rounding.
  @internal
  FxvType ofDoubleUnrounded(double val) {
    final signed = _unpopulated.signed;
    if (!signed & (val < 0)) {
      throw RohdHclException('Negative input not allowed with unsigned');
    }
    final integerValue = BigInt.from(val * pow(2, fractionWidth + 1));
    final w = signed
        ? 1 + integerWidth + fractionWidth
        : integerWidth + fractionWidth;
    final v = LogicValue.ofBigInt(integerValue >> 1, w);
    return ofLogicValue(v);
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
