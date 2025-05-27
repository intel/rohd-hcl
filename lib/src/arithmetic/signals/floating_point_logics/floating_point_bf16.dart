// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_bf16.dart
// Implementation of Floating Point BF16
//
// 2024 April 1
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'package:rohd_hcl/rohd_hcl.dart';

/// Sixteen-bit BF16 floating point representation.
class FloatingPointBF16 extends FloatingPoint {
  /// Construct a BF16 16-bit floating point number.
  FloatingPointBF16({super.name})
      : super(
            mantissaWidth: FloatingPointBF16Value.populator().mantissaWidth,
            exponentWidth: FloatingPointBF16Value.populator().exponentWidth);

  @override
  FloatingPointBF16 clone({String? name, bool explicitJBit = false}) =>
      FloatingPointBF16(name: name);

  @override
  FloatingPointValuePopulator<FloatingPointBF16Value> valuePopulator() =>
      FloatingPointBF16Value.populator();
}
