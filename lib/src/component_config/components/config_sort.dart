// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_sort.dart
// Configurator for a sorter.
//
// 2023 December 5

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [BitonicSort].
class BitonicSortConfigurator extends Configurator {
  /// A knob controlling the number of items to sort.
  final IntConfigKnob lengthOfListKnob = IntConfigKnob(value: 4);

  /// A knob controlling the width of each element to sort.
  final IntConfigKnob logicWidthKnob = IntConfigKnob(value: 16);

  /// A knob controlling whether to sort in ascending (or descending) order.
  final ToggleConfigKnob isAscendingKnob = ToggleConfigKnob(value: true);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Number of Inputs (power of 2)': lengthOfListKnob,
    'Input Width': logicWidthKnob,
    'Sort in Ascending': isAscendingKnob,
  });

  @override
  final String name = 'Bitonic Sort';

  @override
  Module createModule() {
    final listToSort = List.generate(
      lengthOfListKnob.value,
      (index) => Logic(width: logicWidthKnob.value),
    );

    return BitonicSort(
      Logic(),
      Logic(),
      isAscending: isAscendingKnob.value,
      toSort: listToSort,
    );
  }
}
