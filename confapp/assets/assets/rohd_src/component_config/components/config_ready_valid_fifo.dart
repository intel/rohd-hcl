// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_ready_valid_fifo.dart
// Configurator for a ready/valid FIFO.
//
// 2026 November 4
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Configures a ready/valid FIFO with a scalar payload.
class ReadyValidFifoConfigurator extends Configurator {
  /// Payload width.
  final IntConfigKnob widthKnob = PositiveIntConfigKnob(value: 8);

  /// FIFO depth.
  final IntConfigKnob depthKnob = PositiveIntConfigKnob(value: 4);

  /// Permit a full FIFO to dequeue and enqueue on the same edge.
  final ToggleConfigKnob replacementKnob = ToggleConfigKnob(value: false);

  @override
  ComponentCategory get category => ComponentCategory.flowControl;
  @override
  String get subcategory => 'ready-valid';
  @override
  String get name => 'Ready/Valid FIFO';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Payload Width': widthKnob,
        'Depth': depthKnob,
        'Allow Same-Cycle Replacement': replacementKnob,
      };
  @override
  // The legacy configurator retains the FIFO's conservative admission policy.
  // ignore: deprecated_member_use_from_same_package
  Module createModule() => ReadyValidFifo<Logic>(
        clk: Logic(name: 'clk'),
        reset: Logic(name: 'reset'),
        upstream: ReadyAndValidInterface(
            Logic(name: 'input', width: widthKnob.value)),
        downstream:
            ReadyValidInterface(Logic(name: 'output', width: widthKnob.value)),
        depth: depthKnob.value,
        allowSameCycleReplacement: replacementKnob.value,
      );
}
