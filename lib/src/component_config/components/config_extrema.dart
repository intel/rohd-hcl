// Copyright (C) 2024-2026 Intel Corporation
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
  @override
  ComponentCategory get category => ComponentCategory.dataflow;

  @override
  String get subcategory => 'selection';

  /// A knob controlling the number of logics to compare.
  final IntConfigKnob signalsKnob = IntConfigKnob(value: 4);

  /// A knob controlling the width of each element to sort.
  final IntConfigKnob logicWidthKnob = IntConfigKnob(value: 8);

  /// A knob controlling whether to find Max or Min.
  final ToggleConfigKnob maxKnob = ToggleConfigKnob(value: true);

  /// Maximum number of candidates compared by a balanced reduction node.
  final IntConfigKnob radixKnob = IntConfigKnob(value: 2);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Length of list (number of elements)': signalsKnob,
    'Element width (for all elements)': logicWidthKnob,
    'Find maximum (uncheck for minimum)': maxKnob,
    'Radix': radixKnob,
  });

  @override
  Module createModule() {
    final signals = List.generate(
        signalsKnob.value, (index) => Logic(width: logicWidthKnob.value));

    return Extrema(
      signals,
      max: maxKnob.value,
      radix: radixKnob.value,
    );
  }

  @override
  final String name = 'Extrema';
}
