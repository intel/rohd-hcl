// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_priority_encoder.dart
// Configurator for documented priority encoders.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [PriorityEncoder] implementations.
class PriorityEncoderConfigurator extends Configurator {
  /// Width of the input bit vector.
  final IntConfigKnob widthKnob = IntConfigKnob(value: 8);

  /// Whether to generate the valid output.
  final ToggleConfigKnob generateValidKnob = ToggleConfigKnob(value: true);

  /// Priority-encoder implementation to instantiate.
  final PriorityEncoderSelectKnob implementationKnob =
      PriorityEncoderSelectKnob();

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Width': widthKnob,
    'Generate Valid': generateValidKnob,
    'Implementation': implementationKnob,
  });

  @override
  Module createModule() => implementationKnob.selectedPriorityEncoder()(
        Logic(width: widthKnob.value),
        generateValid: generateValidKnob.value,
        name: 'priority_encoder',
      );

  @override
  String get name => 'Priority Encoder';
}
