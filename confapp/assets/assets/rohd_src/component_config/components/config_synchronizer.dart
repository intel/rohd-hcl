// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_synchronizer.dart
// Configurator for a control-signal synchronizer.
//
// 2026 November 4
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Configures a control-signal clock-domain synchronizer.
class SynchronizerConfigurator extends Configurator {
  /// Width of the control signal.
  final IntConfigKnob widthKnob = PositiveIntConfigKnob(value: 1);

  /// Number of synchronization stages.
  final IntConfigKnob stagesKnob = IntConfigKnob(value: 2, minValue: 2);

  /// Whether to include a synchronous reset.
  final ToggleConfigKnob resetKnob = ToggleConfigKnob(value: false);

  @override
  ComponentCategory get category => ComponentCategory.clocking;
  @override
  String get subcategory => 'cdc';
  @override
  String get name => 'Synchronizer';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Width': widthKnob,
        'Stages': stagesKnob,
        'Include Reset': resetKnob,
      };
  @override
  Module createModule() => Synchronizer(
        Logic(name: 'clk'),
        dataIn: Logic(name: 'dataIn', width: widthKnob.value),
        stages: stagesKnob.value,
        reset: resetKnob.value ? Logic(name: 'reset') : null,
      );
}
