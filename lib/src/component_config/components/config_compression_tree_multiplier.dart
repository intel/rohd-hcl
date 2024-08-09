// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_compression_tree_multiplier.dart
// Configurator for a Compression Tree Multiplier.
//
// 2024 August 7
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [CompressionTreeMultiplier]s.
class CompressionTreeMultiplierConfigurator extends Configurator {
  /// Map from Type to Function for Parallel Prefix generator
  static Map<Type,
          ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))>
      generatorMap = {
    Ripple: Ripple.new,
    Sklansky: Sklansky.new,
    KoggeStone: KoggeStone.new,
    BrentKung: BrentKung.new
  };

  /// Controls the type of [ParallelPrefix] tree used in the adder.
  final prefixTreeKnob =
      ChoiceConfigKnob(generatorMap.keys.toList(), value: KoggeStone);

  /// Controls the Booth encoding radix of the multiplier.!
  final radixKnob = ChoiceConfigKnob<int>(
    [2, 4, 8, 16],
    value: 4,
  );

  /// Controls the width of the multiplicand.!
  final IntConfigKnob multiplicandWidthKnob = IntConfigKnob(value: 5);

  /// Controls the width of the multiplier.!
  final IntConfigKnob multiplierWidthKnob = IntConfigKnob(value: 5);

  @override
  Module createModule() => CompressionTreeMultiplier(
      Logic(name: 'a', width: multiplicandWidthKnob.value),
      Logic(name: 'b', width: multiplierWidthKnob.value),
      radixKnob.value,
      generatorMap[prefixTreeKnob.value]!);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Tree type': prefixTreeKnob,
    'Radix': radixKnob,
    'Multiplicand width': multiplicandWidthKnob,
    'Multiplier width': multiplierWidthKnob,
  });

  @override
  final String name = 'Comp. Tree Multiplier';
}
