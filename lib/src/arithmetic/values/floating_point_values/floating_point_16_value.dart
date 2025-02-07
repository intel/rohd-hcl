// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_fp16_value.dart
// Implementation of FP16 Floating-Point value representations.
//
// 2024 October 15
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A representation of an FP16 floating-point value.
class FloatingPoint16Value extends FloatingPointValue {
  /// The exponent width
  static const int exponentWidth = 5;

  /// The mantissa width
  static const int mantissaWidth = 10;

  @override
  @protected
  int get constrainedExponentWidth => exponentWidth;

  @override
  @protected
  int get constrainedMantissaWidth => mantissaWidth;

  /// Constructor for a single precision floating point value
  FloatingPoint16Value(
      {required super.sign, required super.exponent, required super.mantissa});

  /// Return the [FloatingPoint16Value] representing the constant specified
  factory FloatingPoint16Value.getFloatingPointConstant(
          FloatingPointConstants constantFloatingPoint) =>
      FloatingPoint16Value.ofLogicValue(
          FloatingPointValue.getFloatingPointConstant(
                  constantFloatingPoint, exponentWidth, mantissaWidth)
              .value);

  /// [FloatingPoint16Value] constructor from string representation of
  /// individual bitfields
  FloatingPoint16Value.ofBinaryStrings(
      super.sign, super.exponent, super.mantissa)
      : super.ofBinaryStrings();

  /// [FloatingPoint16Value] constructor from spaced string representation of
  /// individual bitfields
  FloatingPoint16Value.ofSpacedBinaryString(super.fp)
      : super.ofSpacedBinaryString();

  /// [FloatingPoint16Value] constructor from a single string representing
  /// space-separated bitfields
  FloatingPoint16Value.ofString(String fp, {super.radix})
      : super.ofString(fp, exponentWidth, mantissaWidth);

  /// [FloatingPoint16Value] constructor from a set of [BigInt]s of the binary
  /// representation
  FloatingPoint16Value.ofBigInts(super.exponent, super.mantissa, {super.sign})
      : super.ofBigInts(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// [FloatingPoint16Value] constructor from a set of [int]s of the binary
  /// representation
  FloatingPoint16Value.ofInts(super.exponent, super.mantissa, {super.sign})
      : super.ofInts(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// Numeric conversion of a [FloatingPoint16Value] from a host double
  factory FloatingPoint16Value.ofDouble(double inDouble) {
    final fpv = FloatingPointValue.ofDouble(inDouble,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

    return FloatingPoint16Value.ofLogicValue(fpv.value);
  }

  /// Construct a [FloatingPoint16Value] from a Logic word
  FloatingPoint16Value.ofLogicValue(LogicValue val)
      : super.ofLogicValue(exponentWidth, mantissaWidth, val);
}
