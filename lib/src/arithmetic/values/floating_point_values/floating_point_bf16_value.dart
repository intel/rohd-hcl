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

/// A representation of a BF16 floating-point value.
class FloatingPointBF16Value extends FloatingPointValue {
  @override
  final int exponentWidth = 8;

  @override
  final int mantissaWidth = 7;

  /// Constructor for a BF16 precision floating point value.
  factory FloatingPointBF16Value(
          {required LogicValue sign,
          required LogicValue exponent,
          required LogicValue mantissa}) =>
      populator().populate(sign: sign, exponent: exponent, mantissa: mantissa);

  @protected
  @override
  FloatingPointBF16Value.uninitialized() : super.uninitialized();

  static FloatingPointValuePopulator<FloatingPointBF16Value> populator() =>
      FloatingPointValuePopulator(FloatingPointBF16Value.uninitialized());

  @override
  FloatingPointValuePopulator clonePopulator() => populator();
}
