// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_edge_detector.dart
// Configurator for a EdgeDetector.
//
// 2024 January 29
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A [Configurator] for [EdgeDetector].
class EdgeDetectorConfigurator extends Configurator {
  /// A knob controlling the type of edge detector.
  final ChoiceConfigKnob<Edge> edgeTypeKnob =
      ChoiceConfigKnob(Edge.values, value: Edge.pos);

  /// A knob controlling whether there is a reset.
  final ToggleConfigKnob hasResetKnob = ToggleConfigKnob(value: true);

  /// A knob controlling the reset value.
  final ChoiceConfigKnob<dynamic> resetValueKnob =
      ChoiceConfigKnob([0, 1, 'Input'], value: 0);

  @override
  Module createModule() => EdgeDetector(
        Logic(),
        clk: Logic(),
        reset: hasResetKnob.value ? Logic() : null,
        resetValue: hasResetKnob.value
            ? resetValueKnob.value == 'Input'
                ? Logic()
                : resetValueKnob.value
            : null,
      );

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Edge Type': edgeTypeKnob,
    'Has Reset': hasResetKnob,
    if (hasResetKnob.value) 'Reset Value': resetValueKnob,
  });

  @override
  final String name = 'Edge Detector';
}
