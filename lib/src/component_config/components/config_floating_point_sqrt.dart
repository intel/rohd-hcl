// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_floating_point_sqrt.dart
// Configurator for a floating-point square root module.
//
// 2025 April 30
// Author: desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [FloatingPointSqrt].
class FloatingPointSqrtConfigurator extends Configurator {
  /// Controls the size of the exponent.
  final IntConfigKnob exponentWidthKnob = IntConfigKnob(value: 4);

  /// Controls the size of the mantissa.
  final IntConfigKnob mantissaWidthKnob = IntConfigKnob(value: 8);

  @override
  Module createModule() {
    final inp = FloatingPoint(
        exponentWidth: exponentWidthKnob.value,
        mantissaWidth: mantissaWidthKnob.value);
    return FloatingPointSqrtSimple(inp);
  }

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Exponent Width': exponentWidthKnob,
        'Mantissa Width': mantissaWidthKnob,
      };

  @override
  String get name => 'Floating-point Square Root';
}
