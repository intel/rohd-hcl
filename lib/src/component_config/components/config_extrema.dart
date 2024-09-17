// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_extrema.dart
// Configurator for extrema.
//
// 2024 September 16
// Author: Roberto Torres <roberto.torres@intel.com>
//

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [Extrema].
class ExtremaConfigurator extends Configurator {
  /// A knob controlling whether to find Max or Min.
  final ToggleConfigKnob maxKnob = ToggleConfigKnob(value: true);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'max': maxKnob,
  });

  @override
  Module createModule() => Extrema(
        <Logic>[],
        max: maxKnob.value,
      );

  @override
  final String name = 'Extrema';
}
