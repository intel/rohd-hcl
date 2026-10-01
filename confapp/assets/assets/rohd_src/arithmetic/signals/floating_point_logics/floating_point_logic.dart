// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_logic.dart
// Implementation of Floating Point objects
//
// 2024 April 1
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Flexible floating point logic representation.
class FloatingPoint extends LogicStructure {
  /// unsigned, biased binary [exponent].
  final Logic exponent;

  /// unsigned binary [mantissa].
  final Logic mantissa;

  /// [sign] bit with '1' representing a negative number.
  final Logic sign;

  /// Utility to keep track of the [LogicStructure] name by attaching it
  /// to the [Logic] signal name in the output Verilog.
  static String _nameJoin(String? structName, String signalName) {
    if (structName == null) {
      return signalName;
    }
    return '${structName}_$signalName';
  }

  /// [FloatingPoint] constructor for a variable size binary
  /// floating point number.
  FloatingPoint(
      {required int exponentWidth,
      required int mantissaWidth,
      bool explicitJBit = false,
      bool subNormalAsZero = false,
      String? name})
      : this._(
            Logic(name: 'sign', naming: Naming.mergeable),
            Logic(
                width: exponentWidth,
                name: 'exponent',
                naming: Naming.mergeable),
            Logic(
                width: mantissaWidth,
                name: 'mantissa',
                naming: Naming.mergeable),
            explicitJBit,
            subNormalAsZero,
            name: name);

  /// [FloatingPoint] internal constructor.
  FloatingPoint._(this.sign, this.exponent, this.mantissa, this.explicitJBit,
      this.subNormalAsZero,
      {super.name})
      : super([mantissa, exponent, sign]);

  @mustBeOverridden
  @override
  FloatingPoint clone({String? name}) => FloatingPoint(
        exponentWidth: exponent.width,
        mantissaWidth: mantissa.width,
        explicitJBit: explicitJBit,
        subNormalAsZero: subNormalAsZero,
        name: name,
      );

  /// A [FloatingPointValuePopulator] for values associated with this
  /// [FloatingPoint] type.
  @mustBeOverridden
  FloatingPointValuePopulator valuePopulator() => FloatingPointValue.populator(
      exponentWidth: exponent.width,
      mantissaWidth: mantissa.width,
      explicitJBit: explicitJBit,
      subNormalAsZero: subNormalAsZero);

  /// Return `true` if the J-bit is explicitly represented in the mantissa.
  final bool explicitJBit;

  /// Return `true` if subnormal numbers are represented as zero.
  final bool subNormalAsZero;

  /// Convert the current [FloatingPoint] to a new [FloatingPoint] but with the
  /// mantissa resolved if not [isNormal] and [subNormalAsZero] is `true`.
  FloatingPoint resolveSubNormalAsZero() {
    if (subNormalAsZero) {
      return clone()
        ..gets(mux(
            isNormal,
            this,
            FloatingPoint.zero(
                exponentWidth: exponent.width,
                mantissaWidth: mantissa.width,
                explicitJBit: explicitJBit,
                subNormalAsZero: subNormalAsZero)));
    } else {
      return this;
    }
  }

  /// Return the [FloatingPointValue] of the current [value].
  FloatingPointValue get floatingPointValue =>
      valuePopulator().ofFloatingPoint(this);

  /// Return the [FloatingPointValue] of the [previousValue].
  FloatingPointValue? get previousFloatingPointValue =>
      valuePopulator().ofFloatingPointPrevious(this);

  /// Return a [Logic] `1` if this [FloatingPoint] contains a normal number,
  /// defined as having mantissa in the range `[1,2)`.
  late final Logic isNormal = exponent
      .neq(LogicValue.zero.zeroExtend(exponent.width))
      .named(_nameJoin('isNormal', name), naming: Naming.mergeable);

  /// Return a [Logic] `1`if this [FloatingPoint] is Not a Number (NaN)
  /// by having its exponent field set to the NaN value (typically all
  /// ones) and a non-zero mantissa.
  late final isNaN = exponent.eq(valuePopulator().nan.exponent) &
      mantissa.or().named(
            _nameJoin('isNaN', name),
            naming: Naming.mergeable,
          );

  /// Return a [Logic] `1` if this [FloatingPoint] is an infinity
  /// by having its exponent field set to the NaN value (typically all
  /// ones) and a zero mantissa.
  late final isAnInfinity = (floatingPointValue.supportsInfinities
          ? exponent.isIn([
                valuePopulator().positiveInfinity.exponent,
                valuePopulator().negativeInfinity.exponent,
              ]) &
              ~mantissa.or()
          : Const(0))
      .named(_nameJoin('isAnInfinity', name), naming: Naming.mergeable);

  /// Return a [Logic] `1` if this [FloatingPoint] is a zero
  /// by having its exponent field set to the NaN value (typically all
  /// ones) and a zero mantissa.
  late final isAZero = (exponent.isIn([
            valuePopulator().positiveZero.exponent,
            valuePopulator().negativeZero.exponent,
          ]) &
          ~mantissa.or())
      .named(_nameJoin('isAZero', name), naming: Naming.mergeable);

  /// Return the zero exponent representation for this type of [FloatingPoint].
  late final zeroExponent = Const(LogicValue.zero, width: exponent.width)
      .named(_nameJoin('zeroExponent', name), naming: Naming.mergeable);

  /// Return the one exponent representation for this type of [FloatingPoint].
  late final oneExponent = Const(LogicValue.one, width: exponent.width)
      .named(_nameJoin('oneExponent', name), naming: Naming.mergeable);

  /// Return the exponent [Logic] representing the [bias] of this
  /// [FloatingPoint] signal, the offset of the exponent, also representing the
  /// zero exponent `2^0 = 1`.
  late final bias = Const((1 << exponent.width - 1) - 1, width: exponent.width)
      .named(_nameJoin('bias', name), naming: Naming.mergeable);

  /// Construct a [FloatingPoint] that represents infinity for this FP type.
  FloatingPoint inf({Logic? sign, bool negative = false}) => FloatingPoint.inf(
      exponentWidth: exponent.width,
      mantissaWidth: mantissa.width,
      sign: sign,
      negative: negative);

  /// Construct a [FloatingPoint] that represents NaN for this FP type.
  late final nan = FloatingPoint.nan(
      exponentWidth: exponent.width, mantissaWidth: mantissa.width);

  @override
  void put(dynamic val, {bool fill = false}) {
    if (val is FloatingPointValue) {
      if ((val.exponentWidth != exponent.width) ||
          (val.mantissaWidth != mantissa.width)) {
        throw RohdHclException('FloatingPoint width does not match');
      }
      if (val.explicitJBit != explicitJBit) {
        throw RohdHclException('FloatingPoint explicit jbit does not match');
      }
      if (val.subNormalAsZero != subNormalAsZero) {
        throw RohdHclException(
            'FloatingPoint subnormal as zero does not match');
      }
      put(val.value);
    } else {
      super.put(val, fill: fill);
    }
  }

  /// Construct a [FloatingPoint] that represents infinity.
  factory FloatingPoint.inf(
      {required int exponentWidth,
      required int mantissaWidth,
      Logic? sign,
      bool negative = false,
      bool explicitJBit = false,
      bool subNormalAsZero = false}) {
    final signLogic = Logic()..gets(sign ?? Const(negative));
    final exponent = Const(1, width: exponentWidth, fill: true);
    final mantissa = Const(0, width: mantissaWidth, fill: true);
    return FloatingPoint._(
        signLogic, exponent, mantissa, explicitJBit, subNormalAsZero);
  }

  /// Construct a [FloatingPoint] that represents NaN.
  factory FloatingPoint.nan(
      {required int exponentWidth,
      required int mantissaWidth,
      bool explicitJBit = false,
      bool subNormalAsZero = false}) {
    final signLogic = Const(0);
    final exponent = Const(1, width: exponentWidth, fill: true);
    final mantissa = Const(1, width: mantissaWidth);
    return FloatingPoint._(
        signLogic, exponent, mantissa, explicitJBit, subNormalAsZero);
  }

  /// Construct a [FloatingPoint] that represents zero.
  factory FloatingPoint.zero(
      {required int exponentWidth,
      required int mantissaWidth,
      bool explicitJBit = false,
      bool subNormalAsZero = false}) {
    final signLogic = Const(0);
    final exponent = Const(0, width: exponentWidth, fill: true);
    final mantissa = Const(0, width: mantissaWidth);
    return FloatingPoint._(
        signLogic, exponent, mantissa, explicitJBit, subNormalAsZero);
  }

  /// Negate the [FloatingPoint].
  FloatingPoint negate() => FloatingPoint._(
        Logic()..gets(~sign),
        Logic(width: exponent.width)..gets(exponent),
        Logic(width: mantissa.width)..gets(mantissa),
        explicitJBit,
        subNormalAsZero,
        name: name,
      );

  /// Negate the [FloatingPoint].
  FloatingPoint operator -() => negate();

  @override
  Logic operator >(dynamic other) => gt(other);
  @override
  Logic operator >=(dynamic other) => gte(other);

  /// Verify if comparable:  return `1` if comparable, throw exception
  /// on mismatch.
  Logic _verifyComparable(dynamic other) {
    if (other is! FloatingPoint) {
      throw RohdHclException('Input must be floating point signal.');
    }
    if (other.exponent.width != exponent.width ||
        other.mantissa.width != mantissa.width ||
        other.explicitJBit != explicitJBit) {
      throw RohdHclException('FloatingPoint width or J-bit does not match');
    }
    return ~(isNaN | other.isNaN);
  }

  /// Equal
  @override
  Logic eq(dynamic other) =>
      mux(_verifyComparable(other), super.eq(other), Const(0));

  /// Not Equal
  @override
  Logic neq(dynamic other) => ~eq(other);

  /// Less-than.
  @override
  Logic lt(dynamic other) {
    final otherSign = (other as FloatingPoint).sign;
    return mux(
        _verifyComparable(other),
        mux(sign, mux(otherSign, super.gt(other), Const(1)),
            mux(otherSign, Const(0), super.lt(other))),
        Const(0));
  }

  @override
  Logic lte(dynamic other) => lt(other) | eq(other);

  // For Greather-than operators, reverse the operands
  /// Greater-than.
  @override
  Logic gt(dynamic other) =>
      mux(_verifyComparable(other), ~lte(other), Const(0));

  /// Greater-than-or-equal-to.
  @override
  Logic gte(dynamic other) => gt(other) | eq(other);
}
