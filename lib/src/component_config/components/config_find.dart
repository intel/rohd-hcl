// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_find.dart
// Configurator for a Find module.
//
// 2024 February 7
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [Find].
class FindConfigurator extends Configurator {
  /// A knob controlling the width of the bus.
  final IntConfigKnob busWidthKnob = IntConfigKnob(value: 8);

  /// A knob controlling whether it should count ones or zeros.
  final ToggleConfigKnob countOneKnob = ToggleConfigKnob(value: true);

  /// A knob controlling the generation of an error signal.
  final ToggleConfigKnob generateErrorKnob = ToggleConfigKnob(value: false);

  /// A knob controlling whether it should have `n` as an input.
  final ToggleConfigKnob includeNKnob = ToggleConfigKnob(value: false);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Bus Width': busWidthKnob,
    'Count Ones': countOneKnob,
    'Generate Error': generateErrorKnob,
    'Include N': includeNKnob,
  });

  @override
  Module createModule() => Find(
        Logic(width: busWidthKnob.value),
        countOne: countOneKnob.value,
        generateError: generateErrorKnob.value,
        n: includeNKnob.value
            ? Logic(width: log2Ceil(busWidthKnob.value))
            : null,
      );

  @override
  final String name = 'Find';
}
