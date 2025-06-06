// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// adder_select_knob.dart
// An adder selection knob for use in arithmetic component configuration.
//
// 2025 April 24
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A knob for selecting an adder to use in a component.
class AdderSelectKnob extends GroupOfKnobs {
  /// Map from [ParallelPrefix] Tree Type to Function for [ParallelPrefixAdder]
  /// generator.
  static Map<
      Type,
      ParallelPrefixAdder Function(Logic, Logic,
          {Logic? carryIn, String name})> adderGeneratorMap = {
    Ripple: (a, b, {carryIn, String name = 'default'}) =>
        ParallelPrefixAdder(a, b, ppGen: Ripple.new),
    Sklansky: (a, b, {carryIn, String name = 'default'}) =>
        ParallelPrefixAdder(a, b, ppGen: Sklansky.new),
    KoggeStone: ParallelPrefixAdder.new,
    BrentKung: (a, b, {carryIn, String name = 'default'}) =>
        ParallelPrefixAdder(a, b, ppGen: BrentKung.new),
  };

  /// Controls the type of [ParallelPrefixAdder] used for internal adders.
  final parallelPrefixTypeKnob =
      ChoiceConfigKnob(adderGeneratorMap.keys.toList(), value: BrentKung);

  /// Whether to instantiate a [ParallelPrefixAdder] (or use a [NativeAdder]).
  final ToggleConfigKnob parallelPrefixAdderKnob =
      ToggleConfigKnob(value: false);

  /// Final value of the Adder Function that is selected.
  Adder Function(Logic, Logic, {Logic? carryIn, String name}) selectedAdder() {
    if (parallelPrefixAdderKnob.value) {
      return adderGeneratorMap[parallelPrefixTypeKnob.value]! as Adder
          Function(Logic, Logic, {Logic? carryIn, String name});
    } else {
      return NativeAdder.new;
    }
  }

  /// Creates a new knob for selecting an adder.
  AdderSelectKnob({super.name = 'Adder Select'}) : super({});

  /// Create the knobs for adder selection.
  @override
  Map<String, ConfigKnob<dynamic>> get subKnobs => {
        'Parallel Prefix Adder': parallelPrefixAdderKnob,
        if (parallelPrefixAdderKnob.value)
          'Parallel Prefix Type': parallelPrefixTypeKnob,
      };
}
