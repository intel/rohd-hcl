// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_carry_save_multiplier.dart
// Configurator for a CarrySaveMultiplier.
//
// 2023 December 5

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [CarrySaveMultiplier].
class CarrySaveMultiplierConfigurator extends Configurator {
  /// A knob controlling the width of the inputs to a [CarrySaveMultiplier].
  final IntConfigKnob logicWidthKnob = IntConfigKnob(value: 8);

  /// A knob controling the sign of a [CarrySaveMultiplier]
  final signChoiceKnob = ChoiceConfigKnob([false, true], value: false);

  @override
  final String name = 'Carry Save Multiplier';

  @override
  CarrySaveMultiplier createModule() => CarrySaveMultiplier(
      Logic(width: logicWidthKnob.value), Logic(width: logicWidthKnob.value),
      clk: Logic(), reset: Logic(), signed: true);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Width': logicWidthKnob,
    'Sign': signChoiceKnob,
  });
}
