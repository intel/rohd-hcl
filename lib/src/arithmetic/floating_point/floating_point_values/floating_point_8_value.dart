// Copyright (C) 2024 Intel Corporation
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
  static double get maxValue => 448.toDouble();

  /// The minimum value representable by the E4M3 format
  static double get minValue => pow(2, -9).toDouble();

  /// Return if the exponent and mantissa widths match E4M3
  static bool isLegal(int exponentWidth, int mantissaWidth) =>
      (exponentWidth == 4) & (mantissaWidth == 3);

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
      : super.ofBigInts();

  /// [FloatingPoint8E4M3Value] constructor from a set of [int]s of the binary
  /// representation
  FloatingPoint8E4M3Value.ofInts(super.exponent, super.mantissa, {super.sign})
      : super.ofInts();

  /// Numeric conversion of a [FloatingPoint8E4M3Value] from a host double
  factory FloatingPoint8E4M3Value.fromDouble(double inDouble) {
    if ((inDouble.abs() > maxValue) |
        ((inDouble != 0) & (inDouble.abs() < minValue))) {
      throw RohdHclException('Number exceeds E4M3 range');
    }
    final fpv = FloatingPointValue.fromDouble(inDouble,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    return FloatingPoint8E4M3Value(
        sign: fpv.sign, exponent: fpv.exponent, mantissa: fpv.mantissa);
  }

  /// Construct a [FloatingPoint8E4M3Value] from a Logic word
  factory FloatingPoint8E4M3Value.fromLogicValue(LogicValue val) =>
      FloatingPointValue.buildFromLogicValue(
          FloatingPoint8E4M3Value.new, exponentWidth, mantissaWidth, val);
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

  /// Return if the exponent and mantissa widths match E5M2
  static bool isLegal(int exponentWidth, int mantissaWidth) =>
      (exponentWidth == 5) & (mantissaWidth == 2);

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
      : super.ofBigInts();

  /// [FloatingPoint8E5M2Value] constructor from a set of [int]s of the binary
  /// representation
  FloatingPoint8E5M2Value.ofInts(super.exponent, super.mantissa, {super.sign})
      : super.ofInts();

  /// Numeric conversion of a [FloatingPoint8E5M2Value] from a host double
  factory FloatingPoint8E5M2Value.fromDouble(double inDouble) {
    if ((inDouble.abs() > maxValue) |
        ((inDouble != 0) & (inDouble.abs() < minValue))) {
      throw RohdHclException('Number exceeds E5M2 range');
    }
    final fpv = FloatingPointValue.fromDouble(inDouble,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    return FloatingPoint8E5M2Value(
        sign: fpv.sign, exponent: fpv.exponent, mantissa: fpv.mantissa);
  }

  /// Construct a [FloatingPoint8E5M2Value] from a Logic word
  factory FloatingPoint8E5M2Value.fromLogicValue(LogicValue val) =>
      FloatingPointValue.buildFromLogicValue(
          FloatingPoint8E5M2Value.new, exponentWidth, mantissaWidth, val);
}
