// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_64.dart
// Implementation of Floating Point 64
//
// 2024 April 1
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Double floating point representation.
class FloatingPoint64 extends FloatingPoint {
  /// Construct a 64-bit (double-precision) floating point number.
  FloatingPoint64({super.name})
      : super(
            exponentWidth: FloatingPoint64Value.populator().exponentWidth,
            mantissaWidth: FloatingPoint64Value.populator().mantissaWidth);

  /// Constructs a binary64 constant from [value].
  factory FloatingPoint64.constant(FloatingPoint64Value value,
          {String? name}) =>
      FloatingPoint64._(
          Const(value.sign), Const(value.exponent), Const(value.mantissa),
          name: name);

  FloatingPoint64._(super.sign, super.exponent, super.mantissa, {super.name})
      : super.fromComponents(explicitJBit: false, subNormalAsZero: false);

  @override
  FloatingPoint64 clone({String? name}) => FloatingPoint64(name: name);

  @override
  FloatingPointValuePopulator<FloatingPoint64Value> valuePopulator() =>
      FloatingPoint64Value.populator();
}
