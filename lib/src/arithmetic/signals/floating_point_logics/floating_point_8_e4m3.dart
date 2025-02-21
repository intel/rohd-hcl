// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_8_e4m3.dart
// Implementation of Floating Point 8 E4M3
//
// 2024 April 1
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'package:rohd_hcl/rohd_hcl.dart';

/// Eight-bit floating point representation for deep learning: E4M3.
class FloatingPoint8E4M3 extends FloatingPoint {
  /// Construct an 8-bit floating point number E4M3.
  FloatingPoint8E4M3({super.name})
      : super(
            mantissaWidth: FloatingPoint8E4M3Value.populator().mantissaWidth,
            exponentWidth: FloatingPoint8E4M3Value.populator().exponentWidth);
  @override
  FloatingPoint8E4M3 clone({String? name}) => FloatingPoint8E4M3(name: name);

  @override
  FloatingPointValuePopulator<FloatingPoint8E4M3Value> valuePopulator() =>
      FloatingPoint8E4M3Value.populator();
}
