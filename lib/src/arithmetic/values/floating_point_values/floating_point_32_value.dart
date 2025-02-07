// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_32_value.dart
// Implementation of 32-bit Floating-Point value representations.
//
// 2024 October 15
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';
import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A representation of a single-precision floating-point value.
class FloatingPoint32Value extends FloatingPointValue {
  /// The exponent width
  static const int exponentWidth = 8;

  /// The mantissa width
  static const int mantissaWidth = 23;

  @override
  @protected
  int get constrainedExponentWidth => exponentWidth;

  @override
  @protected
  int get constrainedMantissaWidth => mantissaWidth;

  /// Constructor for a single precision floating point value
  FloatingPoint32Value(
      {required super.sign, required super.exponent, required super.mantissa});

  /// Return the [FloatingPoint32Value] representing the constant specified
  factory FloatingPoint32Value.getFloatingPointConstant(
          FloatingPointConstants constantFloatingPoint) =>
      FloatingPoint32Value.ofLogicValue(
          FloatingPointValue.getFloatingPointConstant(
                  constantFloatingPoint, exponentWidth, mantissaWidth)
              .value);

  /// [FloatingPoint32Value] constructor from string representation of
  /// individual bitfields
  FloatingPoint32Value.ofBinaryStrings(
      super.sign, super.exponent, super.mantissa)
      : super.ofBinaryStrings();

  /// [FloatingPoint32Value] constructor from spaced string representation of
  /// individual bitfields
  FloatingPoint32Value.ofSpacedBinaryString(super.fp)
      : super.ofSpacedBinaryString();

  /// [FloatingPoint32Value] constructor from a single string representing
  /// space-separated bitfields
  FloatingPoint32Value.ofString(String fp, {super.radix})
      : super.ofString(fp, exponentWidth, mantissaWidth);

  /// [FloatingPoint32Value] constructor from a set of [BigInt]s of the binary
  /// representation
  FloatingPoint32Value.ofBigInts(super.exponent, super.mantissa, {super.sign})
      : super.ofBigInts(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// [FloatingPoint32Value] constructor from a set of [int]s of the binary
  /// representation
  FloatingPoint32Value.ofInts(super.exponent, super.mantissa, {super.sign})
      : super.ofInts(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// Generate a random [FloatingPoint32Value], supplying random seed [rv].
  factory FloatingPoint32Value.random(Random rv, {bool normal = false}) {
    final randFloat = FloatingPointValue.random(rv,
        exponentWidth: exponentWidth,
        mantissaWidth: mantissaWidth,
        normal: normal);
    return FloatingPoint32Value.ofLogicValue(randFloat.value);
  }

  /// Numeric conversion of a [FloatingPoint32Value] from a host double
  factory FloatingPoint32Value.ofDouble(double inDouble) {
    final byteData = ByteData(4)..setFloat32(0, inDouble);
    final accum = byteData.buffer
        .asUint8List()
        .map((b) => LogicValue.ofInt(b, 32))
        .reduce((accum, v) => (accum << 8) | v);

    return FloatingPoint32Value(
        sign: accum[-1],
        exponent: accum.slice(exponentWidth + mantissaWidth - 1, mantissaWidth),
        mantissa: accum.slice(mantissaWidth - 1, 0));
  }

  /// Convert a floating point number into a [FloatingPoint32Value]
  /// representation. This form performs NO ROUNDING.
  factory FloatingPoint32Value.ofDoubleUnrounded(double inDouble) {
    final fpv = FloatingPointValue.ofDoubleUnrounded(inDouble,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

    return FloatingPoint32Value.ofLogicValue(fpv.value);
  }

  /// Construct a [FloatingPoint32Value] from a Logic word
  FloatingPoint32Value.ofLogicValue(LogicValue val)
      : super.ofLogicValue(exponentWidth, mantissaWidth, val);
}
