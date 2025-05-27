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

import 'package:rohd_hcl/rohd_hcl.dart';

/// Sixteen-bit floating point representation.
class FloatingPoint16 extends FloatingPoint {
  /// Construct a 16-bit floating point number.
  FloatingPoint16({super.name})
      : super(
            mantissaWidth: FloatingPoint16Value.populator().mantissaWidth,
            exponentWidth: FloatingPoint16Value.populator().exponentWidth);

  @override
  FloatingPoint16 clone({String? name, bool explicitJBit = false}) =>
      FloatingPoint16(name: name);

  @override
  FloatingPointValuePopulator<FloatingPoint16Value> valuePopulator() =>
      FloatingPoint16Value.populator();
}
