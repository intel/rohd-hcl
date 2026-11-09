// Copyright (C) 2024-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_point_logic.dart
// Representation of fixed-point signals.
//
// 2024 October 24
// Author: Soner Yaldiz <soner.yaldiz@intel.com>

// The legacy multiply operator remains for source compatibility.

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A representation of (un)signed fixed-point logic following
/// Q notation (Qm.n format) as introduced by
/// Texas Instruments: (https://www.ti.com/lit/ug/spru565b/spru565b.pdf).
class FixedPoint extends LogicStructure {
  /// The integer part of the fixed-point number.
  Logic integer;

  /// The fractional part of the fixed-point number.
  Logic fraction;

  /// Return `true` if signed.
  final bool signed;

  /// [integerWidth] is the number of bits reserved for the integer part.
  int get integerWidth => integer.width - (signed ? 1 : 0);

  /// [fractionWidth] is the number of bits reserved for the fractional part.
  int get fractionWidth => fraction.width;

  /// Constructs a [FixedPoint] signal.
  FixedPoint(
      {required int integerWidth,
      required int fractionWidth,
      bool signed = true,
      String? name})
      : this._(
            Logic(
                width: integerWidth + (signed ? 1 : 0),
                name: 'integer',
                naming: Naming.mergeable),
            Logic(
                width: fractionWidth,
                name: 'fraction',
                naming: Naming.mergeable),
            signed,
            name: name);

  /// Constructs a constant [FixedPoint] from [value].
  factory FixedPoint.constant(FixedPointValue value, {String? name}) =>
      FixedPoint._(Const(value.integer), Const(value.fraction), value.signed,
          name: name);

  /// [FixedPoint] internal constructor.
  FixedPoint._(this.integer, this.fraction, this.signed, {super.name})
      : super([fraction, integer]);

  /// Retrieve the [FixedPointValue] of this [FixedPoint] logical signal.
  FixedPointValue get fixedPointValue => valuePopulator().ofFixedPoint(this);

  /// A [FixedPointValuePopulator] for values associated with this
  /// [FloatingPoint] type.
  @mustBeOverridden
  FixedPointValuePopulator valuePopulator() =>
      FixedPointValue.populatorWithSignedness(
          integerWidth: integerWidth,
          fractionWidth: fractionWidth,
          signed: signed);

  /// Clone for I/O ports.
  @override
  FixedPoint clone({String? name}) => FixedPoint(
      signed: signed,
      integerWidth: integerWidth,
      fractionWidth: fractionWidth,
      name: name ?? this.name);

  /// Cast logic to fixed point
  FixedPoint.of(Logic signal,
      {required int integerWidth,
      required int fractionWidth,
      bool signed = true})
      : this._(
            signal.slice(
                fractionWidth + (signed ? integerWidth : integerWidth - 1),
                fractionWidth),
            signal.slice(fractionWidth - 1, 0),
            signed,
            name: signal.name);

  @override
  void put(dynamic val, {bool fill = false}) {
    if (val is FixedPointValue) {
      if ((signed != val.signed) |
          (integerWidth != val.integerWidth) |
          (fractionWidth != val.fractionWidth)) {
        throw RohdHclException('Value is not compatible with signal. '
            'Expected: signed=$signed, integerWidth=$integerWidth, '
            'nWidth=$fractionWidth. '
            'Got: signed=${val.signed}, fractionWidth=${val.integerWidth}, '
            'nWidth=${val.fractionWidth}.');
      }
      super.put(val.value);
    } else {
      throw RohdHclException('Only FixedPointValue is allowed');
    }
  }

  /// Check compatibility
  FixedPoint _requireFixedPoint(dynamic other) {
    if (other is! FixedPoint) {
      throw RohdHclException('Input must be fixed point signal.');
    }
    return other;
  }

  /// Checks that [other] has the same Q format as this signal.
  FixedPoint _verifyCompatible(dynamic other) {
    final fixedPoint = _requireFixedPoint(other);
    if ((signed != fixedPoint.signed) |
        (integerWidth != fixedPoint.integerWidth) |
        (fractionWidth != fixedPoint.fractionWidth)) {
      throw RohdHclException('Inputs are not comparable.');
    }
    return fixedPoint;
  }

  /// Returns this signal widened to the requested format.
  ///
  /// This operation is lossless and therefore only supports increasing the
  /// fractional width. Use [cast] for narrowing or overflow handling.
  FixedPoint _widenTo({
    required int integerWidth,
    required int fractionWidth,
    required bool signed,
  }) {
    if (integerWidth < this.integerWidth ||
        fractionWidth < this.fractionWidth) {
      throw ArgumentError(
          'Cannot losslessly widen FixedPoint to a narrower format.');
    }

    final fractionPadding = fractionWidth - this.fractionWidth;
    final aligned = fractionPadding == 0
        ? packed
        : [packed, Const(0, width: fractionPadding)].concat();
    final targetWidth = integerWidth + fractionWidth + (signed ? 1 : 0);
    final extended = this.signed
        ? aligned.signExtend(targetWidth)
        : aligned.zeroExtend(targetWidth);
    return FixedPoint.of(
      extended,
      integerWidth: integerWidth,
      fractionWidth: fractionWidth,
      signed: signed,
    );
  }

  /// Converts this signal to another Q format.
  ///
  /// Widening appends zero fractional bits and sign- or zero-extends the
  /// integer part. Narrowing drops fractional bits using [roundingMode].
  /// Overflow either wraps or clamps according to [overflow].
  FixedPoint cast({
    required int integerWidth,
    required int fractionWidth,
    bool? signed,
    FixedPointOverflowMode overflow = FixedPointOverflowMode.wrap,
    FloatingPointRoundingMode roundingMode = FloatingPointRoundingMode.truncate,
  }) {
    if (integerWidth < 0 || fractionWidth < 0) {
      throw ArgumentError('Fixed-point widths must be non-negative.');
    }
    final targetSigned = signed ?? this.signed;
    final targetWidth = integerWidth + fractionWidth + (targetSigned ? 1 : 0);
    if (targetWidth == 0) {
      throw ArgumentError('Fixed-point format must have a positive width.');
    }

    Logic rescaled;
    if (fractionWidth >= this.fractionWidth) {
      final padding = fractionWidth - this.fractionWidth;
      rescaled =
          padding == 0 ? packed : [packed, Const(0, width: padding)].concat();
    } else {
      final discarded = this.fractionWidth - fractionWidth;
      final sign = this.signed ? packed[-1] : Const(0);
      final magnitude = mux(sign, ~packed + 1, packed);
      final retained = magnitude.getRange(discarded, magnitude.width);
      final rounder = FloatingPointRounder(
        magnitude,
        discarded,
        roundingMode: roundingMode,
        sign: sign,
      );
      final roundedMagnitude = retained.zeroExtend(retained.width + 1) +
          rounder.doRound.zeroExtend(retained.width + 1);
      rescaled = mux(sign, ~roundedMagnitude + 1, roundedMagnitude);
    }

    final workingWidth =
        rescaled.width > targetWidth ? rescaled.width + 1 : targetWidth + 1;
    final working = this.signed
        ? rescaled.signExtend(workingWidth)
        : rescaled.zeroExtend(workingWidth);
    final wrapped = working.getRange(0, targetWidth);

    if (overflow == FixedPointOverflowMode.wrap) {
      final result = Logic(width: targetWidth)..gets(wrapped);
      return FixedPoint(
        integerWidth: integerWidth,
        fractionWidth: fractionWidth,
        signed: targetSigned,
      )..gets(result);
    }

    final maximum = targetSigned
        ? (BigInt.one << (targetWidth - 1)) - BigInt.one
        : (BigInt.one << targetWidth) - BigInt.one;
    final minimum = targetSigned ? -(BigInt.one << (targetWidth - 1)) : 0;
    final maxValue = Const(maximum, width: workingWidth);
    final minValue = Const(minimum, width: workingWidth);
    final aboveMaximum = targetSigned
        ? _signedGt(working, maxValue)
        : (this.signed
            ? ~working[-1] & working.gt(maxValue)
            : working.gt(maxValue));
    final belowMinimum = targetSigned
        ? _signedLt(working, minValue)
        : (this.signed ? working[-1] : Const(0));
    final saturated = mux(
      aboveMaximum,
      Const(maximum, width: targetWidth),
      mux(belowMinimum, Const(minimum, width: targetWidth), wrapped),
    );
    final result = Logic(width: targetWidth)..gets(saturated);
    return FixedPoint(
      integerWidth: integerWidth,
      fractionWidth: fractionWidth,
      signed: targetSigned,
    )..gets(result);
  }

  /// Signed less-than comparison for equal-width two's-complement signals.
  static Logic _signedLt(Logic left, Logic right) {
    if (left.width != right.width) {
      throw ArgumentError('Signed comparisons require matching widths.');
    }
    return mux(left[-1] ^ right[-1], left[-1], left.lt(right));
  }

  /// Signed greater-than comparison for equal-width two's-complement signals.
  static Logic _signedGt(Logic left, Logic right) {
    if (left.width != right.width) {
      throw ArgumentError('Signed comparisons require matching widths.');
    }
    return mux(left[-1] ^ right[-1], ~left[-1], left.gt(right));
  }

  ({FixedPoint left, FixedPoint right, bool signed}) _promoteWith(dynamic other,
      {required bool carry}) {
    final fixedPoint = _requireFixedPoint(other);
    final promotedSigned = signed | fixedPoint.signed;
    final promotedIntegerWidth =
        max(integerWidth, fixedPoint.integerWidth) + (carry ? 1 : 0);
    final promotedFractionWidth = max(fractionWidth, fixedPoint.fractionWidth);
    return (
      left: _widenTo(
        integerWidth: promotedIntegerWidth,
        fractionWidth: promotedFractionWidth,
        signed: promotedSigned,
      ),
      right: fixedPoint._widenTo(
        integerWidth: promotedIntegerWidth,
        fractionWidth: promotedFractionWidth,
        signed: promotedSigned,
      ),
      signed: promotedSigned,
    );
  }

  /// Less-than.
  @override
  Logic lt(dynamic other) {
    final promoted = _promoteWith(other, carry: false);
    return promoted.signed
        ? _signedLt(promoted.left.packed, promoted.right.packed)
        : promoted.left.packed.lt(promoted.right.packed);
  }

  /// Less-than-or-equal-to.
  @override
  Logic lte(dynamic other) => ~gt(other);

  /// Greater-than.
  @override
  Logic gt(dynamic other) {
    final promoted = _promoteWith(other, carry: false);
    return promoted.signed
        ? _signedGt(promoted.left.packed, promoted.right.packed)
        : promoted.left.packed.gt(promoted.right.packed);
  }

  /// Greater-than.
  @override
  Logic gte(dynamic other) => ~lt(other);

  /// Multiply
  FixedPoint multiply(dynamic other) {
    final comparable = _requireFixedPoint(other);
    final resultSigned = signed | comparable.signed;
    // ROHD's native `Multiply` gate truncates its output to the input width
    // and always treats operands as unsigned, so it cannot produce a correct
    // full-precision signed product. `NativeMultiplier` sign/zero-extends
    // the operands and produces a full double-width product instead.
    final left = _widenTo(
      integerWidth: integerWidth,
      fractionWidth: fractionWidth,
      signed: resultSigned,
    );
    final right = comparable._widenTo(
      integerWidth: comparable.integerWidth,
      fractionWidth: comparable.fractionWidth,
      signed: resultSigned,
    );
    final product = NativeMultiplier(left, right,
            signedMultiplicand:
                StaticOrRuntimeParameter.staticValue(value: resultSigned),
            signedMultiplier:
                StaticOrRuntimeParameter.staticValue(value: resultSigned))
        .product;
    return FixedPoint.of(product,
        signed: resultSigned,
        integerWidth:
            integerWidth + comparable.integerWidth + (resultSigned ? 1 : 0),
        fractionWidth: fractionWidth + comparable.fractionWidth);
  }

  FixedPoint _legacyMultiply(dynamic other) {
    final comparable = _verifyCompatible(other);
    final product = NativeMultiplier(this, comparable).product;
    return FixedPoint.of(product,
        signed: false,
        integerWidth: 2 * integerWidth,
        fractionWidth: 2 * fractionWidth);
  }

  /// Adds [other] and returns a full-precision [FixedPoint].
  FixedPoint add(dynamic other) {
    final promoted = _promoteWith(other, carry: true);
    return FixedPoint.of(
      promoted.left.packed + promoted.right.packed,
      signed: promoted.signed,
      integerWidth: promoted.left.integerWidth,
      fractionWidth: promoted.left.fractionWidth,
    );
  }

  /// Subtracts [other] and returns a full-precision signed [FixedPoint].
  FixedPoint subtract(dynamic other) {
    final comparable = _requireFixedPoint(other);
    final resultIntegerWidth = max(integerWidth, comparable.integerWidth) +
        ((signed | comparable.signed) ? 1 : 0);
    final resultFractionWidth = max(fractionWidth, comparable.fractionWidth);
    final left = _widenTo(
      integerWidth: resultIntegerWidth,
      fractionWidth: resultFractionWidth,
      signed: true,
    );
    final right = comparable._widenTo(
      integerWidth: resultIntegerWidth,
      fractionWidth: resultFractionWidth,
      signed: true,
    );
    return FixedPoint.of(
      left.packed - right.packed,
      integerWidth: resultIntegerWidth,
      fractionWidth: resultFractionWidth,
    );
  }

  /// Negate the [FixedPoint].
  FixedPoint operator -() => negate();

  /// Negate the [FixedPoint].
  FixedPoint negate() {
    final val = ~this + 1;
    return FixedPoint._(
        Logic(width: integer.width)..gets(val.getRange(fractionWidth)),
        Logic(width: fraction.width)..gets(val.slice(fractionWidth - 1, 0)),
        signed);
  }

  /// Greater-than.
  @override
  Logic operator >(dynamic other) => gt(other);

  /// Greater-than-or-equal-to.
  @override
  Logic operator >=(dynamic other) => gte(other);

  /// Addition operator.
  @override
  FixedPoint operator +(dynamic other) => add(other);

  /// Subtraction operator.
  @override
  FixedPoint operator -(dynamic other) => subtract(other);

  /// Multiply operator.
  @override
  @Deprecated('Use multiply instead.')
  FixedPoint operator *(dynamic other) => _legacyMultiply(other);

  /// Equality operator.
  @override
  Logic eq(dynamic other) {
    final promoted = _promoteWith(other, carry: false);
    return promoted.left.packed.eq(promoted.right.packed);
  }

  /// Inequality operator.
  @override
  Logic neq(dynamic other) => ~eq(other);

  /// Modulo operator. Currently unimplemented
  @override
  Logic operator %(dynamic other) {
    throw UnimplementedError('Operator not implemented.');
  }

  /// Divide operator. Currently unimplemented.
  @override
  Logic operator /(dynamic other) {
    throw UnimplementedError('Operator not implemented.');
  }

  /// Power operator, Currently unimplemented
  @override
  Logic pow(dynamic exponent) {
    throw UnimplementedError('Operator not implemented.');
  }
}
