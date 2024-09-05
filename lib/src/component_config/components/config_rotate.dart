// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_rotate.dart
// Configurator for a RippleCarryAdder.
//
// 2023 December 5

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for rotation.
class RotateConfigurator extends Configurator {
  /// A knob controlling the direction of rotation.
  final directionKnob = ChoiceConfigKnob<RotateDirection>(
    RotateDirection.values,
    value: RotateDirection.right,
  );

  /// A knob controlling the width of the input to be rotated.
  final IntConfigKnob originalWidthKnob = IntConfigKnob(value: 16);

  /// A knob controlling the width of the control for rotation amount.
  final IntConfigKnob rotateWidthKnob = IntConfigKnob(value: 8);

  /// A knob controlling the maximum amount to rotate by to support.
  final IntConfigKnob maxAmountKnob = IntConfigKnob(value: 8);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Direction': directionKnob,
    'Original Width': originalWidthKnob,
    'Rotate Amount Width': rotateWidthKnob,
    'Max Rotate Amount': maxAmountKnob,
  });

  @override
  final String name = 'Rotate';

  @override
  Module createModule() {
    final rotateConstructor = directionKnob.value == RotateDirection.left
        ? RotateLeft.new
        : RotateRight.new;
    return rotateConstructor(
      Logic(width: originalWidthKnob.value),
      Logic(width: rotateWidthKnob.value),
      maxAmount: maxAmountKnob.value,
    );
  }
}
