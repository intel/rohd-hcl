// Copyright (C) 2025-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_fixed_sqrt.dart
// Configurator for a fixed-point square root module.
//
// 2025 April 29
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [FixedPointSqrt].
class FixedPointSqrtConfigurator extends Configurator {
  @override
  ComponentCategory get category => ComponentCategory.arithmetic;

  @override
  String get subcategory => 'division-and-roots';

  /// Controls the size of the integer 'm'.
  final IntConfigKnob integerWidthKnob = NonNegativeIntConfigKnob(value: 8);

  /// Controls the size of the fraction 'n'.
  final IntConfigKnob fractionWidthKnob = NonNegativeIntConfigKnob(value: 4);

  @override
  Module createModule() {
    final inp = FixedPoint(
        signed: false,
        integerWidth: integerWidthKnob.value,
        fractionWidth: fractionWidthKnob.value);
    return FixedPointSqrt(inp);
  }

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Integer Width': integerWidthKnob,
        'Fraction Width': fractionWidthKnob,
      };

  @override
  String get name => 'Fixed-point Square Root';
}
