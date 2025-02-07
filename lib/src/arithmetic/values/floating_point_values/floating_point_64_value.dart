// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_64_value.dart
// Implementation of 64-bit Floating-Point value representations.
//
// 2024 October 15
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:typed_data';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A representation of a double-precision floating-point value.
class FloatingPoint64Value extends FloatingPointValue {
  /// The exponent width
  static const int exponentWidth = 11;

  /// The mantissa width
  static const int mantissaWidth = 52;

  /// Constructor for a double precision floating point value
  FloatingPoint64Value(
      {required super.sign, required super.mantissa, required super.exponent});

  /// Return the [FloatingPoint64Value] representing the constant specified
  factory FloatingPoint64Value.getFloatingPointConstant(
          FloatingPointConstants constantFloatingPoint) =>
      FloatingPoint64Value.ofLogicValue(
          FloatingPointValue.getFloatingPointConstant(
                  constantFloatingPoint, exponentWidth, mantissaWidth)
              .value);

  /// [FloatingPoint64Value] constructor from string representation of
  /// individual bitfields
  FloatingPoint64Value.ofBinaryStrings(
      super.sign, super.exponent, super.mantissa)
      : super.ofBinaryStrings();

  /// [FloatingPoint64Value] constructor from spaced string representation of
  /// individual bitfields
  FloatingPoint64Value.ofSpacedBinaryString(super.fp)
      : super.ofSpacedBinaryString();

  /// [FloatingPoint64Value] constructor from a single string representing
  /// space-separated bitfields
  FloatingPoint64Value.ofString(String fp, {super.radix})
      : super.ofString(fp, exponentWidth, mantissaWidth);

  /// [FloatingPoint64Value] constructor from a set of [BigInt]s of the binary
  /// representation
  FloatingPoint64Value.ofBigInts(super.exponent, super.mantissa, {super.sign})
      : super.ofBigInts(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// [FloatingPoint64Value] constructor from a set of [int]s of the binary
  /// representation
  FloatingPoint64Value.ofInts(super.exponent, super.mantissa, {super.sign})
      : super.ofInts(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// Numeric conversion of a [FloatingPoint64Value] from a host double
  factory FloatingPoint64Value.ofDouble(double inDouble) {
    final byteData = ByteData(8)..setFloat64(0, inDouble);
    final accum = byteData.buffer
        .asUint8List()
        .map((b) => LogicValue.ofInt(b, 64))
        .reduce((accum, v) => (accum << 8) | v);

    return FloatingPoint64Value(
        sign: accum[-1],
        exponent: accum.slice(exponentWidth + mantissaWidth - 1, mantissaWidth),
        mantissa: accum.slice(mantissaWidth - 1, 0));
  }

  /// Construct a [FloatingPoint32Value] from a Logic word
  FloatingPoint64Value.ofLogicValue(LogicValue val)
      : super.ofLogicValue(exponentWidth, mantissaWidth, val);
}
