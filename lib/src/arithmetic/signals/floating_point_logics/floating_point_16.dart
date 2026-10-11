// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_16.dart
// Implementation of Floating Point 16
//
// 2024 April 1
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Sixteen-bit floating point representation.
class FloatingPoint16 extends FloatingPoint {
  /// Construct a 16-bit floating point number.
  FloatingPoint16({super.name})
      : super(
            mantissaWidth: FloatingPoint16Value.populator().mantissaWidth,
            exponentWidth: FloatingPoint16Value.populator().exponentWidth);

  /// Constructs a binary16 constant from [value].
  factory FloatingPoint16.constant(FloatingPoint16Value value,
          {String? name}) =>
      FloatingPoint16._(
          Const(value.sign), Const(value.exponent), Const(value.mantissa),
          name: name);

  FloatingPoint16._(super.sign, super.exponent, super.mantissa, {super.name})
      : super.fromComponents(explicitJBit: false, subNormalAsZero: false);

  @override
  FloatingPoint16 clone({String? name}) => FloatingPoint16(name: name);

  @override
  FloatingPointValuePopulator<FloatingPoint16Value> valuePopulator() =>
      FloatingPoint16Value.populator();
}
