// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_floating_point_adder.dart
// Configurator for a Floating-Point Adder.
//
// 2024 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [FloatingPointAdderRound]s.
class FloatingPointAdderRoundConfigurator extends Configurator {
  /// Map from Type to Function for Adder generator
  static Map<Type, Adder Function(Logic, Logic)> adderGeneratorMap = {
    Ripple: (a, b) => ParallelPrefixAdder(a, b, ppGen: Ripple.new),
    Sklansky: (a, b) => ParallelPrefixAdder(a, b, ppGen: Sklansky.new),
    KoggeStone: ParallelPrefixAdder.new,
    BrentKung: (a, b) => ParallelPrefixAdder(a, b, ppGen: BrentKung.new)
  };

  /// Map from Type to Function for Parallel Prefix generator
  static Map<Type,
          ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))>
      treeGeneratorMap = {
    Ripple: Ripple.new,
    Sklansky: Sklansky.new,
    KoggeStone: KoggeStone.new,
    BrentKung: BrentKung.new
  };

  /// Controls the type of [ParallelPrefix] tree used in internal adders.
  final adderTreeKnob =
      ChoiceConfigKnob(adderGeneratorMap.keys.toList(), value: KoggeStone);

  /// Controls the type of [ParallelPrefix] tree used in the other functions.
  final prefixTreeKnob =
      ChoiceConfigKnob(treeGeneratorMap.keys.toList(), value: KoggeStone);

  /// Controls the width of the exponent.
  final IntConfigKnob exponentWidthKnob = IntConfigKnob(value: 4);

  /// Controls the width of the mantissa.
  final IntConfigKnob mantissaWidthKnob = IntConfigKnob(value: 5);

  /// Controls whether the adder is pipelined
  final ToggleConfigKnob pipelinedKnob = ToggleConfigKnob(value: false);

  @override
  Module createModule() => FloatingPointAdderRound(
      clk: pipelinedKnob.value ? Logic() : null,
      FloatingPoint(
        exponentWidth: exponentWidthKnob.value,
        mantissaWidth: mantissaWidthKnob.value,
      ),
      FloatingPoint(
          exponentWidth: exponentWidthKnob.value,
          mantissaWidth: mantissaWidthKnob.value),
      adderGen: adderGeneratorMap[adderTreeKnob.value]!,
      ppTree: treeGeneratorMap[prefixTreeKnob.value]!);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Prefix tree type': prefixTreeKnob,
    'Adder tree type': adderTreeKnob,
    'Exponent width': exponentWidthKnob,
    'Mantissa width': mantissaWidthKnob,
    'Pipelined': pipelinedKnob,
  });

  @override
  final String name = 'Floating-Point Rounding Adder';
}
