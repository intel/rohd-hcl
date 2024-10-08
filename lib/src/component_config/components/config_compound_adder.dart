// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// compound_adder.dart
// Configurator for a CompoundAdder.
//
// 2024 Cotober 1

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [CompoundAdder].
class CompoundAdderConfigurator extends Configurator {
  /// Map from Type to Adder generator
  static Map<Type, CompoundAdder Function(Logic a, Logic b)> generatorMap = {
    TrivialCompoundAdder: TrivialCompoundAdder.new,
    CarrySelectCompoundAdder: CarrySelectCompoundAdder.new
  };

  /// A knob controlling the width of the inputs to the adder.
  final IntConfigKnob logicWidthKnob = IntConfigKnob(value: 16);

  /// Controls the type of [CompoundAdder].
  final moduleTypeKnob = ChoiceConfigKnob(generatorMap.keys.toList(),
      value: CarrySelectCompoundAdder);
  @override
  final String name = 'Compound Adder';

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Width': logicWidthKnob,
    'Adder Type': moduleTypeKnob
  });

  @override
  Module createModule() => generatorMap[moduleTypeKnob.value]!(
        Logic(width: logicWidthKnob.value),
        Logic(width: logicWidthKnob.value),
      );
}
