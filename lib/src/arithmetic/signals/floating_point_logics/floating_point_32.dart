// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_32.dart
// Implementation of Floating Point 32
//
// 2024 April 1
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Single floating point representation.
class FloatingPoint32 extends FloatingPoint {
  /// Construct a 32-bit (single-precision) floating point number.
  FloatingPoint32({super.name})
      : super(
            exponentWidth: FloatingPoint32Value.populator().exponentWidth,
            mantissaWidth: FloatingPoint32Value.populator().mantissaWidth);

  /// Constructs a binary32 constant from [value].
  factory FloatingPoint32.constant(FloatingPoint32Value value,
          {String? name}) =>
      FloatingPoint32._(
          Const(value.sign), Const(value.exponent), Const(value.mantissa),
          name: name);

  FloatingPoint32._(super.sign, super.exponent, super.mantissa, {super.name})
      : super.fromComponents(
            explicitJBit: false, subNormalAsZero: false);

  @override
  FloatingPoint32 clone({String? name}) => FloatingPoint32(name: name);

  @override
  FloatingPointValuePopulator<FloatingPoint32Value> valuePopulator() =>
      FloatingPoint32Value.populator();
}
