// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_rotate.dart
// Configurator for variable and fixed rotations.
//
// 2023 December 5
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for rotation.
class RotateConfigurator extends Configurator {
  @override
  ComponentCategory get category => ComponentCategory.bitOperations;

  @override
  String get subcategory => 'shifting';

  /// A knob controlling the direction of rotation.
  final directionKnob = ChoiceConfigKnob<RotateDirection>(
    RotateDirection.values,
    value: RotateDirection.right,
  );

  /// A knob controlling the width of the input to be rotated.
  final IntConfigKnob originalWidthKnob = PositiveIntConfigKnob(value: 16);

  /// A knob controlling the width of the control for rotation amount.
  final IntConfigKnob rotateWidthKnob = PositiveIntConfigKnob(value: 8);

  /// A knob controlling the maximum amount to rotate by to support.
  final IntConfigKnob maxAmountKnob = PositiveIntConfigKnob(value: 8);

  /// Whether the rotation amount is fixed at elaboration time.
  final ToggleConfigKnob fixedKnob = ToggleConfigKnob(value: false);

  /// Fixed rotation amount.
  final IntConfigKnob fixedAmountKnob = NonNegativeIntConfigKnob(value: 1);

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => UnmodifiableMapView({
        'Direction': directionKnob,
        'Original Width': originalWidthKnob,
        if (!fixedKnob.value) ...{
          'Rotate Amount Width': rotateWidthKnob,
          'Max Rotate Amount': maxAmountKnob,
        },
        'Fixed Rotation': fixedKnob,
        if (fixedKnob.value) 'Fixed Rotate Amount': fixedAmountKnob,
      });

  @override
  final String name = 'Rotate';

  @override
  Module createModule() {
    final val = directionKnob.value;
    if (fixedKnob.value) {
      final original = Logic(width: originalWidthKnob.value);
      return val == RotateDirection.left
          ? RotateLeftFixed(original, fixedAmountKnob.value)
          : RotateRightFixed(original, fixedAmountKnob.value);
    }
    final rotateConstructor =
        val == RotateDirection.left ? RotateLeft.new : RotateRight.new;
    return rotateConstructor(Logic(width: originalWidthKnob.value),
        Logic(width: rotateWidthKnob.value),
        maxAmount: maxAmountKnob.value,
        definitionName:
            'Rotate${val == RotateDirection.left ? "Left" : "Right"}');
  }
}
