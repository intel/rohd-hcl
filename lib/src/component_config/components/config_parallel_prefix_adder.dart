// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_parallel-prefix_adder.dart
// Configurator for a Parallel Prefix Adder.
//
// 2024 February 5
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [ParallelPrefixAdder]s.
class ParallelPrefixAdderConfigurator extends Configurator {
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

  /// Controls the width of the data.!
  final IntConfigKnob dataWidthKnob = IntConfigKnob(value: 4);

  @override
  Module createModule() => ParallelPrefixAdder(
      Logic(name: 'a', width: dataWidthKnob.value),
      Logic(name: 'b', width: dataWidthKnob.value),
      ppGen: generatorMap[prefixTreeKnob.value]!);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Tree type': prefixTreeKnob,
    'Data width': dataWidthKnob,
  });

  @override
  final String name = 'Parallel Prefix Adder';
}
