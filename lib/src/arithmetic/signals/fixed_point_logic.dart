// Copyright (C) 2024-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_point_logic.dart
// Representation of fixed-point signals.
//
// 2024 October 24
// Author: Soner Yaldiz <soner.yaldiz@intel.com>

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
  FixedPoint _verifyCompatible(dynamic other) {
    if (other is! FixedPoint) {
      throw RohdHclException('Input must be fixed point signal.');
    }
    if ((signed != other.signed) |
        (integerWidth != other.integerWidth) |
        (fractionWidth != other.fractionWidth)) {
      throw RohdHclException('Inputs are not comparable.');
    }
    return other;
  }

  /// Less-than.
  @override
  Logic lt(dynamic other) {
    final comparable = _verifyCompatible(other);
    return mux(
        Const(signed) & this[-1], super.gt(comparable), super.lt(comparable));
  }

  /// Less-than-or-equal-to.
  @override
  Logic lte(dynamic other) {
    final comparable = _verifyCompatible(other);
    return mux(
        Const(signed) & this[-1], super.gte(comparable), super.lte(comparable));
  }

  /// Greater-than.
  @override
  Logic gt(dynamic other) {
    final comparable = _verifyCompatible(other);
    return mux(
        Const(signed) & this[-1], super.lt(comparable), super.gt(comparable));
  }

  /// Greater-than.
  @override
  Logic gte(dynamic other) {
    final comparable = _verifyCompatible(other);
    return mux(
        Const(signed) & this[-1], super.lte(comparable), super.gte(comparable));
  }

  /// Multiply
  FixedPoint multiply(dynamic other) {
    final comparable = _verifyCompatible(other);
    // ROHD's native `Multiply` gate truncates its output to the input width
    // and always treats operands as unsigned, so it cannot produce a correct
    // full-precision signed product. `NativeMultiplier` sign/zero-extends
    // the operands and produces a full double-width product instead.
    final product = NativeMultiplier(this, comparable,
            signedMultiplicand: signed, signedMultiplier: signed)
        .product;
    return FixedPoint.of(product,
        signed: signed,
        integerWidth: 2 * integerWidth + (signed ? 1 : 0),
        fractionWidth: 2 * fractionWidth);
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
    final comparable = _verifyCompatible(other);
    final resultWidth = width + 1;
    final left = signed ? signExtend(resultWidth) : zeroExtend(resultWidth);
    final right = signed
        ? comparable.signExtend(resultWidth)
        : comparable.zeroExtend(resultWidth);
    return FixedPoint.of(left + right,
        signed: signed,
        integerWidth: integerWidth + 1,
        fractionWidth: fractionWidth);
  }

  /// Subtracts [other] and returns a full-precision signed [FixedPoint].
  FixedPoint subtract(dynamic other) {
    final comparable = _verifyCompatible(other);
    final resultIntegerWidth = integerWidth + 1;
    final resultWidth = resultIntegerWidth + fractionWidth + 1;
    final left = signed ? signExtend(resultWidth) : zeroExtend(resultWidth);
    final right = signed
        ? comparable.signExtend(resultWidth)
        : comparable.zeroExtend(resultWidth);
    return FixedPoint.of(left - right,
        integerWidth: resultIntegerWidth, fractionWidth: fractionWidth);
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
    final comparable = _verifyCompatible(other);
    return super.eq(comparable);
  }

  /// Inequality operator.
  @override
  Logic neq(dynamic other) {
    final comparable = _verifyCompatible(other);
    return super.neq(comparable);
  }

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
