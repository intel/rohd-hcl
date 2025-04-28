// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_fixed_to_float.dart
// Configurator for a FixedToFloat converter.
//
// 2024 October 24
// Author: Soner Yaldiz <soner.yaldiz@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [FixedToFloat].
class FixedToFloatConfigurator extends Configurator {
  /// A knob controlling the input sign.
  final ToggleConfigKnob signKnob = ToggleConfigKnob(value: true);

  /// A knob controlling leading digit prediction.
  final ToggleConfigKnob leadingDigitPredictionKnob =
      ToggleConfigKnob(value: false);

  /// Width of integer part.
  final IntConfigKnob mKnob = IntConfigKnob(value: 8);

  /// Width of fractional part.
  final IntConfigKnob nKnob = IntConfigKnob(value: 23);

  /// Width of exponent, must be greater than 0.
  final IntConfigKnob exponentWidthKnob = IntConfigKnob(value: 8);

  /// Width of mantissa, must be greater than 0.
  final IntConfigKnob mantissaWidthKnob = IntConfigKnob(value: 23);

  @override
  final String name = 'Fixed To Float Converter';

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Signed Input': signKnob,
    'Leading Digit Prediction Input': leadingDigitPredictionKnob,
    'Input integer width': mKnob,
    'Input fraction width': nKnob,
    'Output exponent width': exponentWidthKnob,
    'Output mantissa width': mantissaWidthKnob,
  });

  @override
  Module createModule() => FixedToFloat(
      FixedPoint(signed: signKnob.value, m: mKnob.value, n: nKnob.value),
      exponentWidth: exponentWidthKnob.value,
      mantissaWidth: mantissaWidthKnob.value,
      leadingDigitPredict: leadingDigitPredictionKnob.value ? Logic() : null);
}
