// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_multiplier.dart
// Configurator for Multipliers.
//
// 2024 August 7
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [Multiplier]s.
class MultiplierConfigurator extends Configurator {
  /// The core selector for which [Multiplier] to instantiate.
  final multiplierSelectKnob = MultiplierSelectKnob(
      allowSigned: true, allowPipelining: true, name: 'Multiplier Selection');

  @override
  Module createModule() => multiplierSelectKnob.selectedMultiplier()(
        clk: multiplierSelectKnob.pipelinedKnob.value ? Logic() : null,
        Logic(
            name: 'a', width: multiplierSelectKnob.multiplicandWidthKnob.value),
        Logic(name: 'b', width: multiplierSelectKnob.multiplierWidthKnob.value),
      );

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Select Multiplier Type': multiplierSelectKnob,
      };

  @override
  final String name = 'Multiplier';
}
