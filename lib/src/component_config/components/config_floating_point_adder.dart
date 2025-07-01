// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_floating_point_adder.dart
// Configurator for Floating-Point adders.
//
// 2024 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Set of knobs for subnormal treatment.
class SubNormalAsZeroSelecKnob extends GroupOfKnobs {
  /// Treat input 'a' as zero when subnormal.
  final ToggleConfigKnob denormalAsZeroA = ToggleConfigKnob(value: false);

  /// Treat input 'b' as zero when subnormal.
  final ToggleConfigKnob denormalAsZeroB = ToggleConfigKnob(value: false);

  /// If addition output is subnormal, flush to zero.
  final ToggleConfigKnob flushToZero = ToggleConfigKnob(value: false);

  /// Creates a new knob for setting up subnormal treatment.
  SubNormalAsZeroSelecKnob({super.name = 'DAZ/FTZ Selection'}) : super({});

  /// Create the knobs for adder selection.
  @override
  Map<String, ConfigKnob<dynamic>> get subKnobs => {
        'A DenormalAsZero': denormalAsZeroA,
        'B DenormalAsZero': denormalAsZeroB,
        'OUT FlushToZero': flushToZero,
      };
}

/// A [Configurator] for [FloatingPointAdder]s.
class FloatingPointAdderConfigurator extends Configurator {
  /// Controls whether to select the simple adder or the dual path.
  final ToggleConfigKnob dualPathAdderKnob = ToggleConfigKnob(value: false);

  /// Adder selection control.
  final adderSelectionKnob = AdderSelectKnob();

  /// Subnormal treatment of inputs and outputs.
  final subNormalAsZeroSelecKnob = SubNormalAsZeroSelecKnob();

  /// Map from Type to Function for Parallel Prefix generator
  static Map<
          Type,
          ParallelPrefix Function(
              List<Logic> inps, Logic Function(Logic term1, Logic term2) op)>
      treeGeneratorMap = {
    Ripple: Ripple.new,
    Sklansky: Sklansky.new,
    KoggeStone: KoggeStone.new,
    BrentKung: BrentKung.new
  };

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
  Module createModule() => dualPathAdderKnob.value
      ? FloatingPointAdderDualPath(
          clk: pipelinedKnob.value ? Logic() : null,
          FloatingPoint(
              exponentWidth: exponentWidthKnob.value,
              mantissaWidth: mantissaWidthKnob.value,
              subNormalAsZero: subNormalAsZeroSelecKnob.denormalAsZeroA.value),
          FloatingPoint(
              exponentWidth: exponentWidthKnob.value,
              mantissaWidth: mantissaWidthKnob.value,
              subNormalAsZero: subNormalAsZeroSelecKnob.denormalAsZeroB.value),
          adderGen: adderSelectionKnob.selectedAdder(),
          ppTree: treeGeneratorMap[prefixTreeKnob.value]!)
      : FloatingPointAdderSinglePath(
          clk: pipelinedKnob.value ? Logic() : null,
          FloatingPoint(
            exponentWidth: exponentWidthKnob.value,
            mantissaWidth: mantissaWidthKnob.value,
          ),
          FloatingPoint(
              exponentWidth: exponentWidthKnob.value,
              mantissaWidth: mantissaWidthKnob.value,
              subNormalAsZero: subNormalAsZeroSelecKnob.flushToZero.value),
          adderGen: adderSelectionKnob.selectedAdder());

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Dual Path Adder': dualPathAdderKnob,
    'DAZ/FTZ Selection': subNormalAsZeroSelecKnob,
    'Select Internal Adder': adderSelectionKnob,
    'Prefix tree type for incrementers': prefixTreeKnob,
    'Exponent width': exponentWidthKnob,
    'Mantissa width': mantissaWidthKnob,
    'Pipelined': pipelinedKnob,
  });

  @override
  final String name = 'Floating-Point Adder';
}
