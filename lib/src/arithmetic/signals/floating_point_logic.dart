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
//

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Flexible floating point logic representation
class FloatingPoint extends LogicStructure {
  /// unsigned, biased binary [exponent]
  final Logic exponent;

  /// unsigned binary [mantissa]
  final Logic mantissa;

  /// [sign] bit with '1' representing a negative number
  final Logic sign;

  /// [FloatingPoint] Constructor for a variable size binary
  /// floating point number
  FloatingPoint({required int exponentWidth, required int mantissaWidth})
      : this._(
            Logic(name: 'sign'),
            Logic(width: exponentWidth, name: 'exponent'),
            Logic(width: mantissaWidth, name: 'mantissa'));

  FloatingPoint._(this.sign, this.exponent, this.mantissa, {String? name})
      : super([mantissa, exponent, sign], name: name ?? 'FloatingPoint');

  @override
  FloatingPoint clone({String? name}) => FloatingPoint(
        exponentWidth: exponent.width,
        mantissaWidth: mantissa.width,
      );

  /// Return the [FloatingPointValue]
  FloatingPointValue get floatingPointValue => FloatingPointValue(
      sign: sign.value, exponent: exponent.value, mantissa: mantissa.value);

  /// Return a Logic true if this FloatingPoint contains a normal number,
  /// defined as having mantissa in the range [1,2)
  late final Logic isNormal = Logic(name: 'isNormal', naming: Naming.mergeable)
    ..gets(exponent.neq(LogicValue.zero.zeroExtend(exponent.width)));

  /// Return a Logic true if this FloatingPoint is Not a Number (NaN)
  /// by having its exponent field set to the NaN value (typically all
  /// ones) and a non-zero mantissa.
  late final isNaN = Logic(name: 'isNaN', naming: Naming.mergeable)
    ..gets(exponent.eq(floatingPointValue.nan.exponent) & mantissa.or());

  /// Return a Logic true if this FloatingPoint is an infinity
  /// by having its exponent field set to the NaN value (typically all
  /// ones) and a zero mantissa.
  late final isInfinity = Logic(name: 'isInfinity', naming: Naming.mergeable)
    ..gets(exponent.eq(floatingPointValue.infinity.exponent) & ~mantissa.or());

  /// Return a Logic true if this FloatingPoint is an zero
  /// by having its exponent field set to the NaN value (typically all
  /// ones) and a zero mantissa.
  late final isZero = Logic(name: 'isZero', naming: Naming.mergeable)
    ..gets(exponent.eq(floatingPointValue.zero.exponent) & ~mantissa.or());

  /// Return the zero exponent representation for this type of FloatingPoint
  late final zeroExponent = Logic(
      name: 'zeroExponent', naming: Naming.mergeable, width: exponent.width)
    ..gets(Const(LogicValue.zero, width: exponent.width));

  /// Return the one exponent representation for this type of FloatingPoint
  late final oneExponent = Logic(
      name: 'oneExponent', naming: Naming.mergeable, width: exponent.width)
    ..gets(Const(LogicValue.one, width: exponent.width));

  /// Return the exponent Logic value representing the true zero exponent
  /// 2^0 = 1 often termed [bias] or the offset of the stored exponent.
  late final bias =
      Logic(name: 'bias', naming: Naming.mergeable, width: exponent.width)
        ..gets(Const((1 << exponent.width - 1) - 1, width: exponent.width));

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
      bool negative = false}) {
    final signLogic = Logic()..gets(sign ?? Const(negative));
    final exponent = Const(1, width: exponentWidth, fill: true);
    final mantissa = Const(0, width: mantissaWidth, fill: true);
    return FloatingPoint._(signLogic, exponent, mantissa);
  }

  /// Construct a FloatingPoint that represents NaN.
  factory FloatingPoint.nan(
      {required int exponentWidth, required int mantissaWidth}) {
    final signLogic = Const(0);
    final exponent = Const(1, width: exponentWidth, fill: true);
    final mantissa = Const(1, width: mantissaWidth);
    return FloatingPoint._(signLogic, exponent, mantissa);
  }
}

/// Single floating point representation
class FloatingPoint32 extends FloatingPoint {
  /// Construct a 32-bit (single-precision) floating point number
  FloatingPoint32()
      : super(
            exponentWidth: FloatingPoint32Value.exponentWidth,
            mantissaWidth: FloatingPoint32Value.mantissaWidth);
}

/// Double floating point representation
class FloatingPoint64 extends FloatingPoint {
  /// Construct a 64-bit (double-precision) floating point number
  FloatingPoint64()
      : super(
            exponentWidth: FloatingPoint64Value.exponentWidth,
            mantissaWidth: FloatingPoint64Value.mantissaWidth);
}

/// Eight-bit floating point representation for deep learning: E4M3
class FloatingPoint8E4M3 extends FloatingPoint {
  /// Construct an 8-bit floating point number
  FloatingPoint8E4M3()
      : super(
            mantissaWidth: FloatingPoint8E4M3Value.mantissaWidth,
            exponentWidth: FloatingPoint8E4M3Value.exponentWidth);
}

/// Eight-bit floating point representation for deep learning: E5M2
class FloatingPoint8E5M2 extends FloatingPoint {
  /// Construct an 8-bit floating point number
  FloatingPoint8E5M2()
      : super(
            mantissaWidth: FloatingPoint8E5M2Value.mantissaWidth,
            exponentWidth: FloatingPoint8E5M2Value.exponentWidth);
}

/// Sixteen-bit BF16 floating point representation
class FloatingPointBF16 extends FloatingPoint {
  /// Construct a BF16 16-bit floating point number
  FloatingPointBF16()
      : super(
            mantissaWidth: FloatingPointBF16Value.mantissaWidth,
            exponentWidth: FloatingPointBF16Value.exponentWidth);
}

/// Sixteen-bit floating point representation
class FloatingPoint16 extends FloatingPoint {
  /// Construct a 16-bit floating point number
  FloatingPoint16()
      : super(
            mantissaWidth: FloatingPoint16Value.mantissaWidth,
            exponentWidth: FloatingPoint16Value.exponentWidth);
}
