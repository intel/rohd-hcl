// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_8_value.dart
// Implementation of 8-bit Floating-Point value representations.
//
// 2024 October 15
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';
import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// The E4M3 representation of a 8-bit floating point value as defined in
/// [FP8 Formats for Deep Learning](https://arxiv.org/abs/2209.05433).
class FloatingPoint8E4M3Value extends FloatingPointValue {
  /// The exponent width
  static const int exponentWidth = 4;

  /// The mantissa width
  static const int mantissaWidth = 3;

  @override
  @protected
  int get constrainedExponentWidth => exponentWidth;

  @override
  @protected
  int get constrainedMantissaWidth => mantissaWidth;

  /// The maximum value representable by the E4M3 format
  static double get maxValue =>
      FloatingPoint8E4M3Value.getFloatingPointConstant(
              FloatingPointConstants.largestNormal)
          .toDouble();

  /// The minimum value representable by the E4M3 format
  static double get minValue => FloatingPointValue.getFloatingPointConstant(
          FloatingPointConstants.smallestPositiveSubnormal, 4, 3)
      .toDouble();

  /// Constructor for a double precision floating point value
  FloatingPoint8E4M3Value(
      {required super.sign, required super.exponent, required super.mantissa});

  /// [FloatingPoint8E4M3Value] constructor from string representation of
  /// individual bitfields
  FloatingPoint8E4M3Value.ofBinaryStrings(
      super.sign, super.exponent, super.mantissa)
      : super.ofBinaryStrings();

  /// [FloatingPoint8E4M3Value] constructor from spaced string representation of
  /// individual bitfields
  FloatingPoint8E4M3Value.ofSpacedBinaryString(super.fp)
      : super.ofSpacedBinaryString();

  /// [FloatingPoint8E4M3Value] constructor from a single string representing
  /// space-separated bitfields
  FloatingPoint8E4M3Value.ofString(String fp, {super.radix})
      : super.ofString(fp, exponentWidth, mantissaWidth);

  /// [FloatingPoint8E4M3Value] constructor from a set of [BigInt]s of the
  ///  binary representation
  FloatingPoint8E4M3Value.ofBigInts(super.exponent, super.mantissa,
      {super.sign})
      : super.ofBigInts(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// [FloatingPoint8E4M3Value] constructor from a set of [int]s of the binary
  /// representation
  FloatingPoint8E4M3Value.ofInts(super.exponent, super.mantissa, {super.sign})
      : super.ofInts(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// Inf is not representable in this format
  @override
  bool get isAnInfinity => false;

  @override
  bool get isNaN => (exponent.toInt() == 15) && (mantissa.toInt() == 7);

  /// Override the toDouble to avoid NaN
  @override
  double toDouble() {
    if (exponent.toInt() == 15) {
      return 448;
    }
    return super.toDouble();
  }

  /// Numeric conversion of a [FloatingPoint8E4M3Value] from a host double
  factory FloatingPoint8E4M3Value.ofDouble(double inDouble) {
    if ((inDouble.abs() > maxValue) |
        ((inDouble != 0) & (inDouble.abs() < minValue))) {
      throw RohdHclException('Number exceeds E4M3 range');
    }
    final fpv = FloatingPointValue.ofDouble(inDouble,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    return FloatingPoint8E4M3Value(
        sign: fpv.sign, exponent: fpv.exponent, mantissa: fpv.mantissa);
  }

  /// Construct a [FloatingPoint8E4M3Value] from a Logic word
  FloatingPoint8E4M3Value.ofLogicValue(LogicValue val)
      : super.ofLogicValue(exponentWidth, mantissaWidth, val);

  /// Return the [FloatingPointValue] representing the constant specified.
  /// Special case for 8E4M3 type.
  factory FloatingPoint8E4M3Value.getFloatingPointConstant(
      FloatingPointConstants constantFloatingPoint) {
    switch (constantFloatingPoint) {
      /// Largest positive number, most positive exponent, full mantissa
      case FloatingPointConstants.largestNormal:
        return FloatingPoint8E4M3Value.ofBinaryStrings(
            '0', '1' * exponentWidth, '${'1' * (mantissaWidth - 1)}0');
      case FloatingPointConstants.nan:
        return FloatingPoint8E4M3Value.ofBinaryStrings(
            '0', '${'1' * (exponentWidth - 1)}1', '1' * mantissaWidth);
      case FloatingPointConstants.infinity:
      case FloatingPointConstants.negativeInfinity:
        throw RohdHclException('Infinity is not representable in this format');
      case _:
        return FloatingPointValue.getFloatingPointConstant(
                constantFloatingPoint, exponentWidth, mantissaWidth)
            as FloatingPoint8E4M3Value;
    }
  }
}

/// The E5M2 representation of a 8-bit floating point value as defined in
/// [FP8 Formats for Deep Learning](https://arxiv.org/abs/2209.05433).
class FloatingPoint8E5M2Value extends FloatingPointValue {
  /// The exponent width
  static const int exponentWidth = 5;

  /// The mantissa width
  static const int mantissaWidth = 2;

  @override
  @protected
  int get constrainedExponentWidth => exponentWidth;

  @override
  @protected
  int get constrainedMantissaWidth => mantissaWidth;

  /// The maximum value representable by the E5M2 format
  static double get maxValue => 57344.toDouble();

  /// The minimum value representable by the E5M2 format
  static double get minValue => pow(2, -16).toDouble();

  /// Constructor for a double precision floating point value
  FloatingPoint8E5M2Value(
      {required super.sign, required super.exponent, required super.mantissa});

  /// [FloatingPoint8E5M2Value] constructor from string representation of
  /// individual bitfields
  FloatingPoint8E5M2Value.ofBinaryStrings(
      super.sign, super.exponent, super.mantissa)
      : super.ofBinaryStrings();

  /// [FloatingPoint8E5M2Value] constructor from spaced string representation of
  /// individual bitfields
  FloatingPoint8E5M2Value.ofSpacedBinaryString(super.fp)
      : super.ofSpacedBinaryString();

  /// [FloatingPoint8E5M2Value] constructor from a single string representing
  /// space-separated bitfields
  FloatingPoint8E5M2Value.ofString(String fp, {super.radix})
      : super.ofString(fp, exponentWidth, mantissaWidth);

  /// [FloatingPoint8E5M2Value] constructor from a set of [BigInt]s of the
  /// binary representation
  FloatingPoint8E5M2Value.ofBigInts(super.exponent, super.mantissa,
      {super.sign})
      : super.ofBigInts(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// [FloatingPoint8E5M2Value] constructor from a set of [int]s of the binary
  /// representation
  FloatingPoint8E5M2Value.ofInts(super.exponent, super.mantissa, {super.sign})
      : super.ofInts(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// Numeric conversion of a [FloatingPoint8E5M2Value] from a host double
  factory FloatingPoint8E5M2Value.ofDouble(double inDouble) {
    if ((inDouble.abs() > maxValue) |
        ((inDouble != 0) & (inDouble.abs() < minValue))) {
      throw RohdHclException('Number exceeds E5M2 range');
    }
    final fpv = FloatingPointValue.ofDouble(inDouble,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    return FloatingPoint8E5M2Value(
        sign: fpv.sign, exponent: fpv.exponent, mantissa: fpv.mantissa);
  }

  /// Construct a [FloatingPoint8E5M2Value] from a Logic word
  FloatingPoint8E5M2Value.ofLogicValue(LogicValue val)
      : super.ofLogicValue(exponentWidth, mantissaWidth, val);
}
