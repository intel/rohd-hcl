// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_compound_adder.dart
// Configurator for a CompoundAdder.
//
// 2024 Cotober 1

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [CompoundAdder].
class CompoundAdderConfigurator extends Configurator {
  /// Adder selection control.
  final adderSelectionKnob = AdderSelectKnob();

  /// A knob controlling the width of the inputs to the adder.
  final IntConfigKnob logicWidthKnob = IntConfigKnob(value: 8);

  /// A knob controlling the sub-adder block width.
  final IntConfigKnob blockWidthKnob = IntConfigKnob(value: 4);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Select Internal Adder': adderSelectionKnob,
    'Width': logicWidthKnob,
    'Block Width': blockWidthKnob,
  });

  @override
  Module createModule() => CarrySelectCompoundAdder(
      Logic(width: logicWidthKnob.value), Logic(width: logicWidthKnob.value),
      widthGen: blockWidthKnob.value > 0
          ? CarrySelectCompoundAdder.splitSelectAdderAlgorithmNBit(
              blockWidthKnob.value)
          : CarrySelectCompoundAdder.splitSelectAdderAlgorithmSingleBlock,
      adderGen: (a, b, {carryIn, subtract, name = 'default_adder'}) =>
          adderSelectionKnob.selectedAdder()(a, b,
              carryIn: carryIn, name: name));

  @override
  final String name = 'Compound Adder';
}
