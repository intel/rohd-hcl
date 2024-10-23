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
class FloatingPointFP16Value extends FloatingPointValue {
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
  FloatingPointFP16Value(
      {required super.sign, required super.exponent, required super.mantissa});

  /// Return the [FloatingPointFP16Value] representing the constant specified
  factory FloatingPointFP16Value.getFloatingPointConstant(
          FloatingPointConstants constantFloatingPoint) =>
      FloatingPointFP16Value.fromLogicValue(
          FloatingPointValue.getFloatingPointConstant(
                  constantFloatingPoint, exponentWidth, mantissaWidth)
              .value);

  /// [FloatingPointFP16Value] constructor from string representation of
  /// individual bitfields
  FloatingPointFP16Value.ofBinaryStrings(
      super.sign, super.exponent, super.mantissa)
      : super.ofBinaryStrings();

  /// [FloatingPointFP16Value] constructor from spaced string representation of
  /// individual bitfields
  FloatingPointFP16Value.ofSpacedBinaryString(super.fp)
      : super.ofSpacedBinaryString();

  /// [FloatingPointFP16Value] constructor from a single string representing
  /// space-separated bitfields
  FloatingPointFP16Value.ofString(String fp, {super.radix})
      : super.ofString(fp, exponentWidth, mantissaWidth);

  /// [FloatingPointFP16Value] constructor from a set of [BigInt]s of the binary
  /// representation
  FloatingPointFP16Value.ofBigInts(super.exponent, super.mantissa, {super.sign})
      : super.ofBigInts();

  /// [FloatingPointFP16Value] constructor from a set of [int]s of the binary
  /// representation
  FloatingPointFP16Value.ofInts(super.exponent, super.mantissa, {super.sign})
      : super.ofInts();

  /// Numeric conversion of a [FloatingPointFP16Value] from a host double
  factory FloatingPointFP16Value.fromDouble(double inDouble) {
    final fpv = FloatingPointValue.fromDouble(inDouble,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

    return FloatingPointFP16Value.fromLogicValue(fpv.value);
  }

  /// Construct a [FloatingPointFP16Value] from a Logic word
  factory FloatingPointFP16Value.fromLogicValue(LogicValue val) =>
      FloatingPointValue.buildFromLogicValue(
          FloatingPointFP16Value.new, exponentWidth, mantissaWidth, val);
}
