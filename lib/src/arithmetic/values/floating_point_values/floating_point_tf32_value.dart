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
  @override
  final int exponentWidth = 8;

  @override
  final int mantissaWidth = 10;

  /// Constructor for a TF16 precision floating point value.
  factory FloatingPointTF32Value(
          {required LogicValue sign,
          required LogicValue exponent,
          required LogicValue mantissa}) =>
      populator().populate(sign: sign, exponent: exponent, mantissa: mantissa);

  @protected
  @override
  FloatingPointTF32Value.uninitialized() : super.uninitialized();

  static FloatingPointValuePopulator<FloatingPointTF32Value> populator() =>
      FloatingPointValuePopulator(FloatingPointTF32Value.uninitialized());

  @override
  FloatingPointValuePopulator clonePopulator() => populator();
}
