// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_carry_save_multiplier.dart
// Configurator for a CarrySaveMultiplier.
//
// 2023 December 5

import 'package:rohd/rohd.dart';
// ignore: implementation_imports
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [CarrySaveMultiplier].
class CarrySaveMultiplierConfigurator extends Configurator {
  /// A knob controlling the width of the inputs to a [CarrySaveMultiplier].
  final IntConfigKnob logicWidthKnob = IntConfigKnob(value: 8);

  @override
  final name = 'Carry Save Multiplier';

  @override
  CarrySaveMultiplier createModule() => CarrySaveMultiplier(
        Logic(width: logicWidthKnob.value),
        Logic(width: logicWidthKnob.value),
        clk: Logic(),
        reset: Logic(),
      );

  @override
  // TODO: implement exampleTestVectors
  List<Vector> get exampleTestVectors => throw UnimplementedError();

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = {
    'Width': logicWidthKnob,
  };
}
