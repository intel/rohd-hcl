// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_rippler_carry_adder.dart
// Configurator for a RippleCarryAdder.
//
// 2023 December 5

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [RippleCarryAdder].
class RippleCarryAdderConfigurator extends Configurator {
  /// A knob controlling the width of the inputs to the adder.
  final IntConfigKnob logicWidthKnob = IntConfigKnob(value: 16);

  @override
  final String name = 'Ripple Carry Adder';

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Width': logicWidthKnob,
  });

  @override
  Module createModule() => RippleCarryAdder(
      Logic(width: logicWidthKnob.value), Logic(width: logicWidthKnob.value),
      carryIn: Logic());
}
