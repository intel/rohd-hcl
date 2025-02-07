// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_bf16_value.dart
// Implementation of BF16 Floating-Point value representations.
//
// 2024 October 15
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A representation of a BF16 floating-point value.
class FloatingPointBF16Value extends FloatingPointValue {
  /// The exponent width
  static const int exponentWidth = 8;

  /// The mantissa width
  static const int mantissaWidth = 7;

  @override
  @protected
  int get constrainedExponentWidth => exponentWidth;

  @override
  @protected
  int get constrainedMantissaWidth => mantissaWidth;

  /// Constructor for a single precision floating point value
  FloatingPointBF16Value(
      {required super.sign, required super.exponent, required super.mantissa});

  /// Return the [FloatingPointBF16Value] representing the constant specified
  factory FloatingPointBF16Value.getFloatingPointConstant(
          FloatingPointConstants constantFloatingPoint) =>
      FloatingPointBF16Value.ofLogicValue(
          FloatingPointValue.getFloatingPointConstant(
                  constantFloatingPoint, exponentWidth, mantissaWidth)
              .value);

  /// [FloatingPointBF16Value] constructor from string representation of
  /// individual bitfields
  FloatingPointBF16Value.ofBinaryStrings(
      super.sign, super.exponent, super.mantissa)
      : super.ofBinaryStrings();

  /// [FloatingPointBF16Value] constructor from spaced string representation of
  /// individual bitfields
  FloatingPointBF16Value.ofSpacedBinaryString(super.fp)
      : super.ofSpacedBinaryString();

  /// [FloatingPointBF16Value] constructor from a single string representing
  /// space-separated bitfields
  FloatingPointBF16Value.ofString(String fp, {super.radix})
      : super.ofString(fp, exponentWidth, mantissaWidth);

  /// [FloatingPointBF16Value] constructor from a set of [BigInt]s of the binary
  /// representation
  FloatingPointBF16Value.ofBigInts(super.exponent, super.mantissa, {super.sign})
      : super.ofBigInts(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// [FloatingPointBF16Value] constructor from a set of [int]s of the binary
  /// representation
  FloatingPointBF16Value.ofInts(super.exponent, super.mantissa, {super.sign})
      : super.ofInts(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// Generate a random [FloatingPointBF16Value], supplying random seed [rv].
  factory FloatingPointBF16Value.random(Random rv, {bool normal = false}) {
    final randFloat = FloatingPointValue.random(rv,
        exponentWidth: exponentWidth,
        mantissaWidth: mantissaWidth,
        normal: normal);
    return FloatingPointBF16Value.ofLogicValue(randFloat.value);
  }

  /// Numeric conversion of a [FloatingPointBF16Value] from a host double
  factory FloatingPointBF16Value.ofDouble(double inDouble) {
    final fpv = FloatingPointValue.ofDouble(inDouble,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

    return FloatingPointBF16Value.ofLogicValue(fpv.value);
  }

  /// Convert a floating point number into a [FloatingPointBF16Value]
  /// representation. This form performs NO ROUNDING.
  factory FloatingPointBF16Value.ofDoubleUnrounded(double inDouble) {
    final fpv = FloatingPointValue.ofDoubleUnrounded(inDouble,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

    return FloatingPointBF16Value.ofLogicValue(fpv.value);
  }

  // TODO(desmonddak): We need to add all these operators for subclasses unless
  // We figure out a way to use templates to do them.  Currently just BF16

  /// Multiply operation for [FloatingPointBF16Value]
  @override
  FloatingPointBF16Value operator *(
      covariant FloatingPointBF16Value multiplicand) {
    final fpv = super * multiplicand;
    return FloatingPointBF16Value.ofLogicValue(fpv.value);
  }

  /// Addition operation for [FloatingPointBF16Value]
  @override
  FloatingPointBF16Value operator +(covariant FloatingPointBF16Value addend) {
    final fpv = super + addend;
    return FloatingPointBF16Value.ofLogicValue(fpv.value);
  }

  /// Divide operation for [FloatingPointBF16Value]
  @override
  FloatingPointBF16Value operator /(covariant FloatingPointBF16Value divisor) {
    final fpv = super / divisor;
    return FloatingPointBF16Value.ofLogicValue(fpv.value);
  }

  /// Subtract operation for [FloatingPointBF16Value]
  @override
  FloatingPointBF16Value operator -(covariant FloatingPointBF16Value subend) {
    final fpv = super - subend;
    return FloatingPointBF16Value.ofLogicValue(fpv.value);
  }

  /// Negate operation for [FloatingPointBF16Value]
  @override
  FloatingPointBF16Value negate() => FloatingPointBF16Value(
      sign: sign.isZero ? LogicValue.one : LogicValue.zero,
      exponent: exponent,
      mantissa: mantissa);

  /// Absolute value operation for [FloatingPointBF16Value]
  @override
  FloatingPointBF16Value abs() => FloatingPointBF16Value(
      sign: LogicValue.zero, exponent: exponent, mantissa: mantissa);

  /// Construct a [FloatingPointBF16Value] from a Logic word
  FloatingPointBF16Value.ofLogicValue(LogicValue val)
      : super.ofLogicValue(exponentWidth, mantissaWidth, val);
}
