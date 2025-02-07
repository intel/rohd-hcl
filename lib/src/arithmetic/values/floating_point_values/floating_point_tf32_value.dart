// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_tf32_value.dart
// Implementation of TF32 Floating-Point value representations.
//
// 2024 October 15
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A representation of a TF32 floating-point value.
class FloatingPointTF32Value extends FloatingPointValue {
  /// The exponent width
  static const int exponentWidth = 8;

  /// The mantissa width
  static const int mantissaWidth = 10;

  @override
  @protected
  int get constrainedExponentWidth => exponentWidth;

  @override
  @protected
  int get constrainedMantissaWidth => mantissaWidth;

  /// Constructor for a single precision floating point value
  FloatingPointTF32Value(
      {required super.sign, required super.exponent, required super.mantissa});

  /// Return the [FloatingPointTF32Value] representing the constant specified
  factory FloatingPointTF32Value.getFloatingPointConstant(
          FloatingPointConstants constantFloatingPoint) =>
      FloatingPointTF32Value.ofLogicValue(
          FloatingPointValue.getFloatingPointConstant(
                  constantFloatingPoint, exponentWidth, mantissaWidth)
              .value);

  /// [FloatingPointTF32Value] constructor from string representation of
  /// individual bitfields
  FloatingPointTF32Value.ofBinaryStrings(
      super.sign, super.exponent, super.mantissa)
      : super.ofBinaryStrings();

  /// [FloatingPointTF32Value] constructor from spaced string representation of
  /// individual bitfields
  FloatingPointTF32Value.ofSpacedBinaryString(super.fp)
      : super.ofSpacedBinaryString();

  /// [FloatingPointTF32Value] constructor from a single string representing
  /// space-separated bitfields
  FloatingPointTF32Value.ofString(String fp, {super.radix})
      : super.ofString(fp, exponentWidth, mantissaWidth);

  /// [FloatingPointTF32Value] constructor from a set of [BigInt]s of the binary
  /// representation
  FloatingPointTF32Value.ofBigInts(super.exponent, super.mantissa, {super.sign})
      : super.ofBigInts(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// [FloatingPointTF32Value] constructor from a set of [int]s of the binary
  /// representation
  FloatingPointTF32Value.ofInts(super.exponent, super.mantissa, {super.sign})
      : super.ofInts(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// Numeric conversion of a [FloatingPointTF32Value] from a host double
  factory FloatingPointTF32Value.ofDouble(double inDouble) {
    final fpv = FloatingPointValue.ofDouble(inDouble,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    return FloatingPointTF32Value.ofLogicValue(fpv.value);
  }

  /// Construct a [FloatingPointTF32Value] from a Logic word
  FloatingPointTF32Value.ofLogicValue(LogicValue val)
      : super.ofLogicValue(exponentWidth, mantissaWidth, val);
}
