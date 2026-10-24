// Copyright (C) 2023-2026 Intel Corporation
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
  @override
  ComponentCategory get category => ComponentCategory.arithmetic;

  @override
  String get subcategory => 'floating-point';

  /// Controls whether to select the simple adder or the dual path.
  final ToggleConfigKnob dualPathAdderKnob = ToggleConfigKnob(value: false);

  /// Adder selection control.
  final adderSelectionKnob = AdderSelectKnob();

  /// Subnormal treatment of inputs and outputs.
  final subNormalAsZeroSelecKnob = SubNormalAsZeroSelecKnob();

  /// Map from Type to Function for Parallel Prefix generator
  static Map<Type, ParallelPrefixGenerator<Logic>> treeGeneratorMap = {
    Ripple: Ripple.new,
    Sklansky: Sklansky.new,
    KoggeStone: KoggeStone.new,
    BrentKung: BrentKung.new,
  };

  /// Controls the type of [ParallelPrefix] tree used in the other functions.
  final prefixTreeKnob = ChoiceConfigKnob(
    treeGeneratorMap.keys.toList(),
    value: KoggeStone,
    choiceLabels: const {
      Ripple: 'Ripple',
      Sklansky: 'Sklansky',
      KoggeStone: 'KoggeStone',
      BrentKung: 'BrentKung',
    },
  );

  /// Controls the width of the exponent.
  final IntConfigKnob exponentWidthKnob = PositiveIntConfigKnob(value: 4);

  /// Controls the width of the mantissa.
  final IntConfigKnob mantissaWidthKnob = PositiveIntConfigKnob(value: 5);

  /// Controls whether the adder is pipelined
  final ToggleConfigKnob pipelinedKnob = ToggleConfigKnob(value: false);

  /// Whether the floating-point format includes an explicit J bit.
  final ToggleConfigKnob explicitJBitKnob = ToggleConfigKnob(value: false);

  /// Optional output format for the sum.
  final OutputWidthSelectKnob outputWidthSelectKnob = OutputWidthSelectKnob();

  /// Whether the dual-path implementation generates a subtraction input.
  final ToggleConfigKnob dualPathSubtractInputKnob =
      ToggleConfigKnob(value: false);

  /// Rounding mode used by the adder.
  final FloatingPointRoundingModeKnob roundingModeKnob =
      FloatingPointRoundingModeKnob();

  @override
  Module createModule() {
    if (dualPathAdderKnob.value && explicitJBitKnob.value) {
      throw RohdHclException(
        'The dual-path floating-point adder does not support explicit J bits.',
      );
    }

    final a = FloatingPoint(
      exponentWidth: exponentWidthKnob.value,
      mantissaWidth: mantissaWidthKnob.value,
      explicitJBit: explicitJBitKnob.value,
      subNormalAsZero: subNormalAsZeroSelecKnob.denormalAsZeroA.value,
    );
    final b = FloatingPoint(
      exponentWidth: exponentWidthKnob.value,
      mantissaWidth: mantissaWidthKnob.value,
      explicitJBit: explicitJBitKnob.value,
      subNormalAsZero: subNormalAsZeroSelecKnob.denormalAsZeroB.value,
    );
    final outSum = outputWidthSelectKnob.differentWidthOutput.value
        ? FloatingPoint(
            exponentWidth: outputWidthSelectKnob.exponentWidthKnob.value,
            mantissaWidth: outputWidthSelectKnob.mantissaWidthKnob.value,
            explicitJBit: outputWidthSelectKnob.explicitJBitKnob.value,
            subNormalAsZero: subNormalAsZeroSelecKnob.flushToZero.value,
          )
        : FloatingPoint(
            exponentWidth: exponentWidthKnob.value,
            mantissaWidth: mantissaWidthKnob.value,
            explicitJBit: explicitJBitKnob.value,
            subNormalAsZero: subNormalAsZeroSelecKnob.flushToZero.value,
          );

    return dualPathAdderKnob.value
        ? FloatingPointAdderDualPath(
            clk: pipelinedKnob.value ? Logic() : null,
            a,
            b,
            outSum: outSum,
            subtract: dualPathSubtractInputKnob.value
                ? Logic(name: 'subtract')
                : null,
            roundingMode: roundingModeKnob.value,
            adderGen: adderSelectionKnob.selectedAdder(),
            ppTree: treeGeneratorMap[prefixTreeKnob.value]!,
            definitionName: 'FloatingPointAdderDualPath',
          )
        : FloatingPointAdderSinglePath(
            clk: pipelinedKnob.value ? Logic() : null,
            a,
            b,
            outSum: outSum,
            roundingMode: roundingModeKnob.value,
            adderGen: adderSelectionKnob.selectedAdder(),
            definitionName: 'FloatingPointAdderSinglePath',
          );
  }

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => UnmodifiableMapView({
        'Dual Path Adder': dualPathAdderKnob,
        'DAZ/FTZ Selection': subNormalAsZeroSelecKnob,
        'Select Internal Adder': adderSelectionKnob,
        'Prefix tree type for incrementers': prefixTreeKnob,
        'Exponent width': exponentWidthKnob,
        'Mantissa width': mantissaWidthKnob,
        'Pipelined': pipelinedKnob,
        'Explicit J bit': explicitJBitKnob,
        'Output Floating Point': outputWidthSelectKnob,
        if (dualPathAdderKnob.value)
          'Generate Subtract Input': dualPathSubtractInputKnob,
        'Rounding mode': roundingModeKnob,
      });

  @override
  final String name = 'Floating-Point Adder';
}
