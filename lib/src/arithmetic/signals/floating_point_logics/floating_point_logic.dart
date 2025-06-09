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
  /// unsigned, biased binary [exponent]
  final Logic exponent;

  /// unsigned binary [mantissa]
  final Logic mantissa;

  /// [sign] bit with '1' representing a negative number
  final Logic sign;

  /// Utility to keep track of the Logic structure name by attaching it
  /// to the Logic signal name in the output Verilog.
  static String _nameJoin(String? structName, String signalName) {
    if (structName == null) {
      return signalName;
    }
    return '${structName}_$signalName';
  }

  /// [FloatingPoint] constructor for a variable size binary
  /// floating point number
  FloatingPoint(
      {required int exponentWidth,
      required int mantissaWidth,
      bool explicitJBit = false,
      String? name})
      : this._(
            Logic(name: _nameJoin(name, 'sign'), naming: Naming.mergeable),
            Logic(
                width: exponentWidth,
                name: _nameJoin(name, 'exponent'),
                naming: Naming.mergeable),
            Logic(
                width: mantissaWidth,
                name: _nameJoin(name, 'mantissa'),
                naming: Naming.mergeable),
            explicitJBit,
            name: name);

  /// [FloatingPoint] internal constructor.
  FloatingPoint._(this.sign, this.exponent, this.mantissa, this._explicitJBit,
      {super.name})
      : super([mantissa, exponent, sign]);

  @mustBeOverridden
  @override
  FloatingPoint clone({String? name}) => FloatingPoint(
        exponentWidth: exponent.width,
        mantissaWidth: mantissa.width,
        explicitJBit: explicitJBit,
        name: name,
      );

  /// A [FloatingPointValuePopulator] for values associated with this
  /// [FloatingPoint] type.
  @mustBeOverridden
  FloatingPointValuePopulator valuePopulator() => FloatingPointValue.populator(
      exponentWidth: exponent.width,
      mantissaWidth: mantissa.width,
      explicitJBit: explicitJBit);

  /// Return true if the J-bit is explicitly represented in the mantissa.
  bool get explicitJBit => _explicitJBit;

  late final bool _explicitJBit;

  /// Return the [FloatingPointValue] of the current [value].
  FloatingPointValue get floatingPointValue =>
      valuePopulator().ofFloatingPoint(this);

  /// Return the [FloatingPointValue] of the [previousValue].
  FloatingPointValue? get previousFloatingPointValue =>
      valuePopulator().ofFloatingPointPrevious(this);

  /// Return a Logic true if this FloatingPoint contains a normal number,
  /// defined as having mantissa in the range [1,2)
  late final Logic isNormal = exponent
      .neq(LogicValue.zero.zeroExtend(exponent.width))
      .named(_nameJoin('isNormal', name), naming: Naming.mergeable);

  /// Return a Logic true if this FloatingPoint is Not a Number (NaN)
  /// by having its exponent field set to the NaN value (typically all
  /// ones) and a non-zero mantissa.
  late final isNaN = exponent.eq(valuePopulator().nan.exponent) &
      mantissa.or().named(
            _nameJoin('isNaN', name),
            naming: Naming.mergeable,
          );

  /// Return a Logic true if this FloatingPoint is an infinity
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

  /// Return a Logic true if this FloatingPoint is an zero
  /// by having its exponent field set to the NaN value (typically all
  /// ones) and a zero mantissa.
  late final isAZero = (exponent.isIn([
            valuePopulator().positiveZero.exponent,
            valuePopulator().negativeZero.exponent,
          ]) &
          ~mantissa.or())
      .named(_nameJoin('isAZero', name), naming: Naming.mergeable);

  /// Return the zero exponent representation for this type of FloatingPoint
  late final zeroExponent = Const(LogicValue.zero, width: exponent.width)
      .named(_nameJoin('zeroExponent', name), naming: Naming.mergeable);

  /// Return the one exponent representation for this type of FloatingPoint
  late final oneExponent = Const(LogicValue.one, width: exponent.width)
      .named(_nameJoin('oneExponent', name), naming: Naming.mergeable);

  /// Return the exponent Logic value representing the true zero exponent
  /// 2^0 = 1 often termed [bias] or the offset of the stored exponent.
  late final bias = Const((1 << exponent.width - 1) - 1, width: exponent.width)
      .named(_nameJoin('bias', name), naming: Naming.mergeable);

  /// Construct a FloatingPoint that represents infinity for this FP type.
  FloatingPoint inf({Logic? sign, bool negative = false}) => FloatingPoint.inf(
      exponentWidth: exponent.width,
      mantissaWidth: mantissa.width,
      sign: sign,
      negative: negative);

  /// Construct a FloatingPoint that represents NaN for this FP type.
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
      put(val.value);
    } else {
      super.put(val, fill: fill);
    }
  }

  /// Construct a FloatingPoint that represents infinity.
  factory FloatingPoint.inf(
      {required int exponentWidth,
      required int mantissaWidth,
      Logic? sign,
      bool negative = false,
      bool explicitJBit = false}) {
    final signLogic = Logic()..gets(sign ?? Const(negative));
    final exponent = Const(1, width: exponentWidth, fill: true);
    final mantissa = Const(0, width: mantissaWidth, fill: true);
    return FloatingPoint._(signLogic, exponent, mantissa, explicitJBit);
  }

  /// Construct a FloatingPoint that represents NaN.
  factory FloatingPoint.nan(
      {required int exponentWidth,
      required int mantissaWidth,
      bool explicitJBit = false}) {
    final signLogic = Const(0);
    final exponent = Const(1, width: exponentWidth, fill: true);
    final mantissa = Const(1, width: mantissaWidth);
    return FloatingPoint._(signLogic, exponent, mantissa, explicitJBit);
  }

  /// Negate the [FloatingPoint].
  factory FloatingPoint.negate(FloatingPoint input) {
    final exponent = Logic(width: input.exponent.width)..gets(input.exponent);
    final mantissa = Logic(width: input.mantissa.width)..gets(input.mantissa);
    final sign = Logic()..gets(~input.sign);
    return FloatingPoint._(
      sign,
      exponent,
      mantissa,
      input.explicitJBit,
      name: input.name,
    );
  }

  @override
  FloatingPoint operator ~() => FloatingPoint.negate(this);

  /// Equal
  @override
  Logic eq(dynamic other) {
    if (other is! FloatingPoint) {
      throw RohdHclException('Input must be floating point signal.');
    }
    return mux(isNaN | other.isNaN, Const(0), super.eq(other));
  }

  /// Not Equal
  @override
  Logic neq(dynamic other) {
    if (other is! FloatingPoint) {
      throw RohdHclException('Input must be floating point signal.');
    }
    return mux(isNaN | other.isNaN, Const(1), super.neq(other));
  }

  /// Less-than.
  @override
  Logic lt(dynamic other) {
    if (other is! FloatingPoint) {
      throw RohdHclException('Input must be floating point signal.');
    }
    if (explicitJBit || other.explicitJBit) {
      throw RohdHclException(
          'FloatingPoint with explicit J-bit cannot be compared.');
    }
    return mux(
        isNaN | other.isNaN,
        Const(0),
        mux(this[-1], mux(other[-1], super.gt(other), Const(1)),
            mux(other[-1], Const(0), super.lt(other))));
  }

  @override
  Logic lte(dynamic other) {
    if (other is! FloatingPoint) {
      throw RohdHclException('Input must be floating point signal.');
    }
    if (explicitJBit || other.explicitJBit) {
      throw RohdHclException(
          'FloatingPoint with explicit J-bit cannot be compared.');
    }
    return mux(
        isNaN | other.isNaN,
        Const(0),
        mux(this[-1], mux(other[-1], super.gte(other), Const(1)),
            mux(other[-1], Const(0), super.lte(other))));
  }

  // For Greather-than operators, reverse the operands
  /// Greater-than.
  @override
  Logic gt(dynamic other) {
    if (other is! FloatingPoint) {
      throw RohdHclException('Input must be floating point signal.');
    }
    return other.lt(this);
  }

  /// Greater-than-or-equal-to.
  @override
  Logic gte(dynamic other) {
    if (other is! FloatingPoint) {
      throw RohdHclException('Input must be floating point signal.');
    }
    return other.lte(this);
  }
}
