// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_tf32.dart
// Implementation of Floating Point TF32
//
// 2024 April 1
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'package:rohd_hcl/rohd_hcl.dart';

/// TF32 floating point representation.
class FloatingPointTF32 extends FloatingPoint {
  /// Construct a TF32 floating point number.
  FloatingPointTF32({super.name})
      : super(
            mantissaWidth: FloatingPointTF32Value.populator().mantissaWidth,
            exponentWidth: FloatingPointTF32Value.populator().exponentWidth);

  @override
  FloatingPointTF32 clone({String? name}) => FloatingPointTF32(name: name);

  @override
  FloatingPointValuePopulator<FloatingPointTF32Value> valuePopulator() =>
      FloatingPointTF32Value.populator();
}
