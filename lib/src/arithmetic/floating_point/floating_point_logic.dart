// Copyright (C) 2024 Intel Corporation
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
  Logic isNormal() => exponent.neq(LogicValue.zero.zeroExtend(exponent.width));

  /// Return the zero exponent representation for this type of FloatingPoint
  Logic zeroExponent() => Const(LogicValue.zero).zeroExtend(exponent.width);

  /// Return the one exponent representation for this type of FloatingPoint
  Logic oneExponent() => Const(LogicValue.one).zeroExtend(exponent.width);

  @override
  void put(dynamic val, {bool fill = false}) {
    if (val is FloatingPointValue) {
      put(val.value);
    } else {
      super.put(val, fill: fill);
    }
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

/// Eight-bit floating point representation for deep learning
class FloatingPoint8 extends FloatingPoint {
  /// Calculate mantissa width and sanitize
  static int _calculateMantissaWidth(int exponentWidth) {
    final mantissaWidth = 7 - exponentWidth;
    if (!FloatingPoint8Value.isLegal(exponentWidth, mantissaWidth)) {
      throw RohdHclException('FloatingPoint8 must follow E4M3 or E5M2');
    } else {
      return mantissaWidth;
    }
  }

  /// Construct an 8-bit floating point number
  FloatingPoint8({required super.exponentWidth})
      : super(mantissaWidth: _calculateMantissaWidth(exponentWidth));
}
