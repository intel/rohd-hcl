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

import 'package:rohd_hcl/rohd_hcl.dart';

/// Double floating point representation.
class FloatingPoint64 extends FloatingPoint {
  /// Construct a 64-bit (double-precision) floating point number.
  FloatingPoint64({super.name})
      : super(
            exponentWidth: FloatingPoint64Value.populator().exponentWidth,
            mantissaWidth: FloatingPoint64Value.populator().mantissaWidth);

  @override
  FloatingPoint64 clone({String? name, bool explicitJBit = false}) =>
      FloatingPoint64(name: name);

  @override
  FloatingPointValuePopulator<FloatingPoint64Value> valuePopulator() =>
      FloatingPoint64Value.populator();
}
