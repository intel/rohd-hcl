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
  @override
  final int exponentWidth = 5;

  @override
  final int mantissaWidth = 10;

  /// Constructor for a FP16 floating point value.
  factory FloatingPoint16Value(
          {required LogicValue sign,
          required LogicValue exponent,
          required LogicValue mantissa}) =>
      populator().populate(sign: sign, exponent: exponent, mantissa: mantissa);

  @protected
  @override
  FloatingPoint16Value.uninitialized() : super.uninitialized();

  static FloatingPointValuePopulator<FloatingPoint16Value> populator() =>
      FloatingPointValuePopulator(FloatingPoint16Value.uninitialized());

  @override
  FloatingPointValuePopulator clonePopulator() => populator();
}
