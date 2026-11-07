// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_ready_valid_queue.dart
// Configurator for a ready/valid queue.
//
// 2026 November 5
// Author: GitHub Copilot

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Configures a ready/valid queue with a scalar payload.
class ReadyValidQueueConfigurator extends Configurator {
  /// Payload width.
  final IntConfigKnob dataWidthKnob = PositiveIntConfigKnob(value: 8);

  /// Number of retained entries.
  final IntConfigKnob depthKnob = PositiveIntConfigKnob(value: 4);

  /// Whether an empty queue can bypass its input.
  final ToggleConfigKnob fallThroughKnob = ToggleConfigKnob(value: false);

  /// Queue storage architecture.
  final ChoiceConfigKnob<ReadyValidQueueStorage> storageKnob = ChoiceConfigKnob(
    ReadyValidQueueStorage.values,
    value: ReadyValidQueueStorage.registers,
  );

  @override
  ComponentCategory get category => ComponentCategory.flowControl;
  @override
  String get subcategory => 'ready-valid';
  @override
  String get name => 'Ready/Valid Queue';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Data Width': dataWidthKnob,
        'Depth': depthKnob,
        'Fall-Through': fallThroughKnob,
        'Storage': storageKnob,
      };

  @override
  Module createModule() => ReadyValidQueue<Logic>(
        clk: Logic(name: 'clk'),
        reset: Logic(name: 'reset'),
        upstream: ReadyValidInterface(
          Logic(name: 'input', width: dataWidthKnob.value),
        ),
        downstream: ReadyValidInterface(
          Logic(name: 'output', width: dataWidthKnob.value),
        ),
        depth: depthKnob.value,
        policy: fallThroughKnob.value
            ? ReadyValidQueuePolicy.fallThrough
            : ReadyValidQueuePolicy.registered,
        storage: storageKnob.value,
      );
}
