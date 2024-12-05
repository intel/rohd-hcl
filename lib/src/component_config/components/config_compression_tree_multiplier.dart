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

  /// A knob controlling the sign of the multiplicand
  final ChoiceConfigKnob<dynamic> signMultiplicandValueKnob =
      ChoiceConfigKnob(['unsigned', 'signed', 'selected'], value: 'unsigned');

  /// A knob controlling the sign of the multiplier
  final ChoiceConfigKnob<dynamic> signMultiplierValueKnob =
      ChoiceConfigKnob(['unsigned', 'signed', 'selected'], value: 'unsigned');

  /// Controls whether the adder is pipelined
  final ToggleConfigKnob pipelinedKnob = ToggleConfigKnob(value: false);

  @override
  Module createModule() => CompressionTreeMultiplier(
      clk: pipelinedKnob.value ? Logic() : null,
      Logic(name: 'a', width: multiplicandWidthKnob.value),
      Logic(name: 'b', width: multiplierWidthKnob.value),
      radixKnob.value,
      signedMultiplicand: signMultiplicandValueKnob.value == 'signed',
      signedMultiplier: signMultiplierValueKnob.value == 'signed',
      selectSignedMultiplicand:
          signMultiplicandValueKnob.value == 'selected' ? Logic() : null,
      selectSignedMultiplier:
          signMultiplierValueKnob.value == 'selected' ? Logic() : null,
      ppTree: generatorMap[prefixTreeKnob.value]!);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Tree type': prefixTreeKnob,
    'Radix': radixKnob,
    'Multiplicand width': multiplicandWidthKnob,
    'Multiplicand sign': signMultiplicandValueKnob,
    'Multiplier width': multiplierWidthKnob,
    'Multiplier sign': signMultiplierValueKnob,
    'Pipelined': pipelinedKnob,
  });

  @override
  final String name = 'Comp. Tree Multiplier';
}
