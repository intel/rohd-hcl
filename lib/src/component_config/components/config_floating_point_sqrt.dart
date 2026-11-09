// Copyright (C) 2025-2026 Intel Corporation
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
  @override
  ComponentCategory get category => ComponentCategory.arithmetic;

  @override
  String get subcategory => 'floating-point';

  /// Controls the size of the exponent.
  final IntConfigKnob exponentWidthKnob = PositiveIntConfigKnob(value: 4);

  /// Controls the size of the mantissa.
  final IntConfigKnob mantissaWidthKnob = PositiveIntConfigKnob(value: 8);

  /// Rounding mode used by the square root.
  final FloatingPointRoundingModeKnob roundingModeKnob =
      FloatingPointRoundingModeKnob();

  @override
  Module createModule() {
    final inp = FloatingPoint(
      exponentWidth: exponentWidthKnob.value,
      mantissaWidth: mantissaWidthKnob.value,
    );
    return FloatingPointSqrtSimple(
      inp,
      roundingMode: roundingModeKnob.value,
      definitionName: 'FloatingPointSqrtSimple',
    );
  }

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Exponent Width': exponentWidthKnob,
        'Mantissa Width': mantissaWidthKnob,
        'Rounding mode': roundingModeKnob,
      };

  @override
  String get name => 'Floating-point Square Root';
}
