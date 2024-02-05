// Copyright (C) 2023 Intel Corporation
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
  /// Controls the type of [ParallelPrefix] tree used in the adder.
  final ChoiceConfigKnob<
          ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))>
      prefixTreeKnob = ChoiceConfigKnob(
          [Ripple.new, Sklansky.new, KoggeStone.new, BrentKung.new],

  /// Controls the width of the data.
  final IntConfigKnob dataWidthKnob = IntConfigKnob(value: 8);

  @override
  Module createModule() => ParallelPrefixAdder(
      Logic(name: 'a', width: dataWidthKnob.value),
      Logic(name: 'b', width: dataWidthKnob.value),
      prefixTreeKnob.value);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Tree type': prefixTreeKnob,
    'Data width': dataWidthKnob,
  });

  @override
  final String name = 'Parallel Prefix Adder';
}
