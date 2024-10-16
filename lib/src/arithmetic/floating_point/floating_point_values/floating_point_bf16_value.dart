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

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A representation of a single precision floating point value
class FloatingPointBF16Value extends FloatingPointValue {
  /// The exponent width
  static const int exponentWidth = 8;

  /// The mantissa width
  static const int mantissaWidth = 8;

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
      FloatingPointBF16Value.fromLogic(
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
      : super.ofBigInts();

  /// [FloatingPointBF16Value] constructor from a set of [int]s of the binary
  /// representation
  FloatingPointBF16Value.ofInts(super.exponent, super.mantissa, {super.sign})
      : super.ofInts();

  /// Numeric conversion of a [FloatingPointBF16Value] from a host double
  factory FloatingPointBF16Value.fromDouble(double inDouble) {
    final fpv = FloatingPointValue.fromDouble(inDouble,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

    return FloatingPointBF16Value.fromLogic(fpv.value);
  }

  /// Construct a [FloatingPointBF16Value] from a Logic word
  factory FloatingPointBF16Value.fromLogic(LogicValue val) =>
      FloatingPointBF16Value(
          sign: val[-1],
          exponent: val.slice(exponentWidth + mantissaWidth - 1, mantissaWidth),
          mantissa: val.slice(mantissaWidth - 1, 0));
}
