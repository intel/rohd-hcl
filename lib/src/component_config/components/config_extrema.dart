// Copyright (C) 2024 Intel Corporation
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
  /// A knob controlling the number of logics to compare.
  final IntConfigKnob toCompareKnob = IntConfigKnob(value: 4);

  /// A knob controlling the width of each element to sort.
  final IntConfigKnob logicWidthKnob = IntConfigKnob(value: 8);

  /// A knob controlling whether to find Max or Min.
  final ToggleConfigKnob maxKnob = ToggleConfigKnob(value: true);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Length of list (Number of elements)': toCompareKnob,
    'Width of list (For all elements)': logicWidthKnob,
    'Find max (uncheck for min)': maxKnob,
  });

  @override
  Module createModule() {
    final toCompare = List.generate(
        toCompareKnob.value, (index) => Logic(width: logicWidthKnob.value));

    return Extrema(
      toCompare,
      max: maxKnob.value,
    );
  }

  @override
  final String name = 'Extrema';
}
