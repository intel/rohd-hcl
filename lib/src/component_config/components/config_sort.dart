// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_sort.dart
// Configurator for a sorter.
//
// 2023 December 5

import 'package:rohd/rohd.dart';
// ignore: implementation_imports
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [BitonicSort].
class BitonicSortConfigurator extends Configurator {
  /// A knob controlling the number of items to sort.
  final lengthOfListKnob = IntConfigKnob(value: 4);

  /// A knob controlling the width of each element to sort.
  final logicWidthKnob = IntConfigKnob(value: 16);

  /// A knob controlling whether to sort in ascending (or descending) order.
  final isAscendingKnob = ToggleConfigKnob(value: true);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = {
    'Number of Inputs (power of 2)': lengthOfListKnob,
    'Input Width': logicWidthKnob,
    'Sort in Ascending': isAscendingKnob,
  };

  @override
  final name = 'Bitonic Sort';

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

  @override
  // TODO: implement exampleTestVectors
  List<Vector> get exampleTestVectors => throw UnimplementedError();
}
