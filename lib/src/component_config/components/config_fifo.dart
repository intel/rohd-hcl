// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_fifo.dart
// Configurator for a FIFO module.
//
// 2023 December 6
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [Fifo].
class FifoConfigurator extends Configurator {
  /// A knob controlling the data width of the FIFO.
  final IntConfigKnob dataWidthKnob = IntConfigKnob(value: 8);

  /// A knob controlling the depth of the FIFO.
  final IntConfigKnob depthKnob = IntConfigKnob(value: 4);

  /// A knob controlling the generation of an error signal.
  final ToggleConfigKnob generateErrorKnob = ToggleConfigKnob(value: false);

  /// A knob controlling the generation of bypass functionality.
  final ToggleConfigKnob generateBypassKnob = ToggleConfigKnob(value: false);

  /// A knob controlling the generation of an occupancy signal.
  final ToggleConfigKnob generateOccupancyKnob = ToggleConfigKnob(value: false);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Data Width': dataWidthKnob,
    'Depth': depthKnob,
    'Generate Error': generateErrorKnob,
    'Generate Bypass': generateBypassKnob,
    'Generate Occupancy': generateOccupancyKnob,
  });

  @override
  Module createModule() => Fifo(
        Logic(),
        Logic(),
        writeEnable: Logic(),
        writeData: Logic(width: dataWidthKnob.value),
        readEnable: Logic(),
        depth: depthKnob.value,
        generateBypass: generateBypassKnob.value,
        generateError: generateErrorKnob.value,
        generateOccupancy: generateOccupancyKnob.value,
      );

  @override
  final String name = 'FIFO';
}
