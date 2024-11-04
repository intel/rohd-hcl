// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_float_to_fixed.dart
// Configurator for a FloatToFixed converter.
//
// 2024 November 1
// Author: Soner Yaldiz <soner.yaldiz@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [FloatToFixed].
class FloatToFixedConfigurator extends Configurator {
  /// Width of exponent, must be greater than 0.
  final IntConfigKnob exponentWidthKnob = IntConfigKnob(value: 8);

  /// Width of mantissa, must be greater than 0.
  final IntConfigKnob mantissaWidthKnob = IntConfigKnob(value: 23);

  @override
  final String name = 'Float To Fixed Converter';

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Input exponent width': exponentWidthKnob,
    'Input mantissa width': mantissaWidthKnob,
  });

  @override
  Module createModule() => FloatToFixed(FloatingPoint(
      exponentWidth: exponentWidthKnob.value,
      mantissaWidth: mantissaWidthKnob.value));
}
