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

/// The E5M2 representation of a 8-bit floating point value as defined in
/// [FP8 Formats for Deep Learning](https://arxiv.org/abs/2209.05433).
class FloatingPoint8E5M2Value extends FloatingPointValue {
  @override
  final int exponentWidth = 5;

  @override
  final int mantissaWidth = 2;

  /// The maximum value representable by the E5M2 format.
  static double get maxValue => 57344.toDouble();

  /// The minimum value representable by the E5M2 format.
  static double get minValue => pow(2, -16).toDouble();

  /// Constructor for an 8-bit E5M2 floating point value.
  factory FloatingPoint8E5M2Value(
          {required LogicValue sign,
          required LogicValue exponent,
          required LogicValue mantissa}) =>
      populator().populate(sign: sign, exponent: exponent, mantissa: mantissa);

  @protected
  @override
  FloatingPoint8E5M2Value.unpop() : super.uninitialized();

  static FloatingPointValuePopulator<FloatingPoint8E5M2Value> populator() =>
      FloatingPointValuePopulator(FloatingPoint8E5M2Value.unpop());

  @override
  FloatingPointValuePopulator clonePopulator() => populator();
}
