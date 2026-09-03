// Copyright (C) 2024-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_logic.dart
// Implementation of Floating Point objects
//
// 2024 April 1
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:math';

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

  /// Constructs a constant [FloatingPoint] from [value].
  factory FloatingPoint.constant(FloatingPointValue value, {String? name}) =>
      FloatingPoint._(Const(value.sign), Const(value.exponent),
          Const(value.mantissa), value.explicitJBit, value.subNormalAsZero,
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

  /// Whether this format represents positive and negative infinity.
  bool get supportsInfinities =>
      valuePopulator().positiveZero.supportsInfinities;

  /// Whether this format distinguishes signaling and quiet NaNs.
  bool get supportsSignalingNaNs =>
      valuePopulator().positiveZero.supportsSignalingNaNs;

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

  late final Logic _fraction = explicitJBit
      ? (mantissa.width > 1 ? mantissa.slice(mantissa.width - 2, 0) : Const(0))
      : mantissa;

  /// Return a [Logic] `1`if this [FloatingPoint] is Not a Number (NaN)
  /// by having its exponent field set to the NaN value (typically all
  /// ones) and a non-zero mantissa.
  late final Logic isNaN = (supportsSignalingNaNs
          ? exponent.eq(valuePopulator().nan.exponent) & _fraction.or()
          : exponent.eq(valuePopulator().nan.exponent) &
              mantissa.eq(valuePopulator().nan.mantissa))
      .named(_nameJoin('isNaN', name), naming: Naming.mergeable);

  /// Return `1` if this is a signaling NaN.
  late final Logic isSignalingNaN =
      (supportsSignalingNaNs && _fraction.width > 0
              ? isNaN & ~_fraction[-1]
              : Const(0))
          .named(_nameJoin('isSignalingNaN', name), naming: Naming.mergeable);

  /// Return `1` if this is a quiet NaN.
  late final Logic isQuietNaN = (isNaN & ~isSignalingNaN)
      .named(_nameJoin('isQuietNaN', name), naming: Naming.mergeable);

  /// Return a [Logic] `1` if this [FloatingPoint] is an infinity
  /// by having its exponent field set to the NaN value (typically all
  /// ones) and a zero mantissa.
  late final isAnInfinity = (supportsInfinities
          ? exponent.isIn([
                valuePopulator().positiveInfinity.exponent,
                valuePopulator().negativeInfinity.exponent,
              ]) &
              ~_fraction.or()
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
  FloatingPoint inf({Logic? sign, bool negative = false}) {
    final value = valuePopulator().ofConstant(supportsInfinities
        ? (negative
            ? FloatingPointConstants.negativeInfinity
            : FloatingPointConstants.positiveInfinity)
        : FloatingPointConstants.largestNormal);
    return _constant(value, sign: sign ?? Const(negative));
  }

  /// Construct a [FloatingPoint] that represents NaN for this FP type.
  late final FloatingPoint nan = _constant(valuePopulator().nan);

  /// Construct the largest finite value with the provided [sign].
  FloatingPoint largestFinite({Logic? sign, bool negative = false}) =>
      _constant(
          valuePopulator().ofConstant(FloatingPointConstants.largestNormal),
          sign: sign ?? Const(negative));

  /// Quiet and convert the NaN payload and sign from [source] into this format.
  FloatingPoint quietNaNFrom(FloatingPoint source) {
    if (!supportsSignalingNaNs) {
      return _constant(valuePopulator().nan, sign: source.sign);
    }

    final targetFractionWidth = mantissa.width - (explicitJBit ? 1 : 0);
    final sourceFractionWidth =
        source.mantissa.width - (source.explicitJBit ? 1 : 0);
    final targetPayloadWidth = max(0, targetFractionWidth - 1);
    final sourcePayloadWidth = max(0, sourceFractionWidth - 1);
    late final Logic quietMantissa;
    if (targetFractionWidth == 0) {
      quietMantissa = Const(1, width: mantissa.width);
    } else {
      Logic payload;
      if (sourcePayloadWidth == 0) {
        payload = Const(0, width: targetPayloadWidth);
      } else {
        payload = source.mantissa.getRange(0, sourcePayloadWidth);
        payload = payload.width > targetPayloadWidth
            ? payload.getRange(0, targetPayloadWidth)
            : payload.zeroExtend(targetPayloadWidth);
      }
      quietMantissa = [
        if (explicitJBit) Const(1),
        Const(1),
        if (targetPayloadWidth > 0) payload
      ].swizzle();
    }
    final quiet = clone(name: 'quietNaN');
    quiet.sign <= source.sign;
    quiet.exponent <= Const(valuePopulator().nan.exponent);
    quiet.mantissa <= quietMantissa;
    return quiet;
  }

  /// Propagate the first signaling NaN, otherwise the first quiet NaN.
  FloatingPoint propagateNaN(FloatingPoint first, FloatingPoint second) {
    final selectSecond = (~first.isSignalingNaN &
            (second.isSignalingNaN | (~first.isNaN & second.isNaN)))
        .named('selectSecondNaN');
    final selected = first.clone(name: 'selectedNaN')
      ..gets(mux(selectSecond, second, first));
    return quietNaNFrom(selected);
  }

  FloatingPoint _constant(FloatingPointValue value, {Logic? sign}) {
    final constant = clone(name: 'specialConstant');
    constant.sign <= (sign ?? Const(value.sign));
    constant.exponent <= Const(value.exponent);
    constant.mantissa <= Const(value.mantissa);
    return constant;
  }

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
    final mantissa =
        Const(BigInt.one << (mantissaWidth - 1), width: mantissaWidth);
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

  /// Adds [other] using a single-path adder.
  FloatingPoint add(dynamic other,
      {FloatingPointRoundingMode roundingMode =
          FloatingPointRoundingMode.roundNearestEven}) {
    final comparable = _validateComparable(other);
    return FloatingPointAdderSinglePath<FloatingPoint, FloatingPoint>(
            this, comparable,
            roundingMode: roundingMode)
        .sum;
  }

  /// Subtracts [other] using a single-path adder.
  FloatingPoint subtract(dynamic other,
      {FloatingPointRoundingMode roundingMode =
          FloatingPointRoundingMode.roundNearestEven}) {
    final comparable = _validateComparable(other);
    return FloatingPointAdderSinglePath<FloatingPoint, FloatingPoint>(
            this, comparable.negate(),
            roundingMode: roundingMode)
        .sum;
  }

  /// Multiplies by [other] using a simple floating-point multiplier.
  FloatingPoint multiply(dynamic other,
      {FloatingPointRoundingMode roundingMode =
          FloatingPointRoundingMode.roundNearestEven}) {
    final comparable = _validateComparable(other);
    return FloatingPointMultiplierSimple<FloatingPoint, FloatingPoint>(
            this, comparable,
            roundingMode: roundingMode)
        .product;
  }

  /// Addition operator.
  @override
  FloatingPoint operator +(dynamic other) => add(other);

  /// Subtraction operator.
  @override
  FloatingPoint operator -(dynamic other) => subtract(other);

  /// Multiplication operator.
  @override
  FloatingPoint operator *(dynamic other) => multiply(other);

  @override
  Logic operator >(dynamic other) => gt(other);
  @override
  Logic operator >=(dynamic other) => gte(other);

  /// Modulo is not defined for [FloatingPoint].
  @override
  Logic operator %(dynamic other) =>
      throw UnimplementedError('Operator not implemented.');

  /// Division does not yet have a signal-level implementation.
  @override
  Logic operator /(dynamic other) =>
      throw UnimplementedError('Operator not implemented.');

  /// Power does not yet have a signal-level implementation.
  @override
  Logic pow(dynamic exponent) =>
      throw UnimplementedError('Operator not implemented.');

  FloatingPoint _validateComparable(dynamic other) {
    if (other is! FloatingPoint) {
      throw RohdHclException('Input must be floating point signal.');
    }
    if (other.exponent.width != exponent.width ||
        other.mantissa.width != mantissa.width ||
        other.explicitJBit != explicitJBit) {
      throw RohdHclException('FloatingPoint width or J-bit does not match');
    }
    return other;
  }

  Logic _areOrdered(dynamic other) {
    final comparable = _validateComparable(other);
    return ~(isNaN | comparable.isNaN);
  }

  /// Whether an IEEE quiet comparison with [other] signals invalid.
  Logic comparisonInvalid(dynamic other) {
    final comparable = _validateComparable(other);
    return isSignalingNaN | comparable.isSignalingNaN;
  }

  /// IEEE quiet equality.
  @override
  Logic eq(dynamic other) {
    final comparable = _validateComparable(other);
    final bothZero = isAZero & comparable.isAZero;
    return mux(
        _areOrdered(comparable), bothZero | super.eq(comparable), Const(0));
  }

  /// IEEE quiet inequality.
  @override
  Logic neq(dynamic other) => ~eq(other);

  /// IEEE quiet less-than.
  @override
  Logic lt(dynamic other) {
    final comparable = _validateComparable(other);
    final otherSign = comparable.sign;
    final bothZero = isAZero & comparable.isAZero;
    return mux(
        _areOrdered(comparable),
        mux(
            bothZero,
            Const(0),
            mux(sign, mux(otherSign, super.gt(comparable), Const(1)),
                mux(otherSign, Const(0), super.lt(comparable)))),
        Const(0));
  }

  /// IEEE quiet less-than-or-equal.
  @override
  Logic lte(dynamic other) => lt(other) | eq(other);

  /// IEEE quiet greater-than.
  @override
  Logic gt(dynamic other) => _validateComparable(other).lt(this);

  /// IEEE quiet greater-than-or-equal.
  @override
  Logic gte(dynamic other) => _validateComparable(other).lte(this);
}
