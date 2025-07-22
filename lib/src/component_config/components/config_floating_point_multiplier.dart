// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_floating_point_multiplier.dart
// Configurator for Floating-Point multipliers.
//
// 2025 January 6
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A knob for selecting a different width output.
class OutputWidthSelectKnob extends GroupOfKnobs {
  /// Whether to change the output [FloatingPoint] type (or just match
  /// the input type).
  final ToggleConfigKnob differentWidthOutput = ToggleConfigKnob(value: false);

  /// Creates a new knob for selecting an adder.
  OutputWidthSelectKnob() : super({}, name: 'Output width selection');

  /// Controls the width of the output exponent.
  final IntConfigKnob exponentWidthKnob = IntConfigKnob(value: 4);

  /// Controls the width of the output mantissa.
  final IntConfigKnob mantissaWidthKnob = IntConfigKnob(value: 5);

  /// Create the knobs for adder selection.
  @override
  Map<String, ConfigKnob<dynamic>> get subKnobs => {
        'Custom Output Floating Point': differentWidthOutput,
        if (differentWidthOutput.value)
          'Output Exponent Width': exponentWidthKnob,
        if (differentWidthOutput.value)
          'Output Mantissa Width': mantissaWidthKnob,
      };
}

/// A [Configurator] for [FloatingPointMultiplierSimple]s.
class FloatingPointMultiplierSimpleConfigurator extends Configurator {
  /// Select the type of mantissa multiplier.
  final multiplierSelectKnob = MultiplierSelectKnob(
      allowSigned: false,
      allowPipelining: true,
      name: 'Mantissa Multiplier Selection');

  /// Controls the width of the exponent.
  final IntConfigKnob exponentWidthKnob = IntConfigKnob(value: 4);

  /// Controls the width of the mantissa.
  final IntConfigKnob mantissaWidthKnob = IntConfigKnob(value: 5);

  /// Control the output width of the [FloatingPointMultiplier]
  final OutputWidthSelectKnob outputWidthSelectKnob = OutputWidthSelectKnob();

  @override
  Module createModule() => FloatingPointMultiplierSimple(
      clk: multiplierSelectKnob.pipelinedKnob.value ? Logic() : null,
      FloatingPoint(
        exponentWidth: exponentWidthKnob.value,
        mantissaWidth: mantissaWidthKnob.value,
      ),
      FloatingPoint(
          exponentWidth: exponentWidthKnob.value,
          mantissaWidth: mantissaWidthKnob.value),
      multGen: multiplierSelectKnob.selectedMultiplier(),
      definitionName: 'FloatingPointMultiplierSimple');

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Exponent width': exponentWidthKnob,
    'Mantissa width': mantissaWidthKnob,
    'Output Floating Point': outputWidthSelectKnob,
    'Mantissa Multiplier': multiplierSelectKnob,
  });

  @override
  final String name = 'Floating-Point Multiplier';
}
