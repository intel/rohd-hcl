// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_8_e5m2.dart
// Implementation of Floating Point 8 E5M2
//
// 2024 April 1
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Eight-bit floating point representation for deep learning: E5M2.
class FloatingPoint8E5M2 extends FloatingPoint {
  /// Construct an 8-bit floating point number E5M2.
  FloatingPoint8E5M2({super.name})
      : super(
            mantissaWidth: FloatingPoint8E5M2Value.populator().mantissaWidth,
            exponentWidth: FloatingPoint8E5M2Value.populator().exponentWidth);

  /// Constructs an E5M2 constant from [value].
  factory FloatingPoint8E5M2.constant(FloatingPoint8E5M2Value value,
          {String? name}) =>
      FloatingPoint8E5M2._(
          Const(value.sign), Const(value.exponent), Const(value.mantissa),
          name: name);

  FloatingPoint8E5M2._(super.sign, super.exponent, super.mantissa,
      {super.name})
      : super.fromComponents(
            explicitJBit: false, subNormalAsZero: false);

  @override
  FloatingPoint8E5M2 clone({String? name}) => FloatingPoint8E5M2(name: name);

  @override
  FloatingPointValuePopulator<FloatingPoint8E5M2Value> valuePopulator() =>
      FloatingPoint8E5M2Value.populator();
}
