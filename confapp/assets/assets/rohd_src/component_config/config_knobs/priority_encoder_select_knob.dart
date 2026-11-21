// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// priority_encoder_select_knob.dart
// A knob for selecting a priority-encoder implementation.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [ConfigKnob] group for selecting a [PriorityEncoder] implementation.
class PriorityEncoderSelectKnob extends GroupOfKnobs {
  static final Map<
      Type,
      PriorityEncoder Function(
        Logic input, {
        bool generateValid,
        String name,
      })> _generators = {
    RecursivePriorityEncoder: RecursivePriorityEncoder.new,
    RecursiveModulePriorityEncoder: RecursiveModulePriorityEncoder.new,
    ParallelPrefixPriorityEncoder: ParallelPrefixPriorityEncoder.new,
  };

  /// The priority-encoder implementation to instantiate.
  final ChoiceConfigKnob<Type> implementationKnob = ChoiceConfigKnob(
    [
      RecursivePriorityEncoder,
      RecursiveModulePriorityEncoder,
      ParallelPrefixPriorityEncoder,
    ],
    value: RecursiveModulePriorityEncoder,
    choiceLabels: const {
      RecursivePriorityEncoder: 'RecursivePriorityEncoder',
      RecursiveModulePriorityEncoder: 'RecursiveModulePriorityEncoder',
      ParallelPrefixPriorityEncoder: 'ParallelPrefixPriorityEncoder',
    },
  );

  /// Creates a priority-encoder implementation selector.
  PriorityEncoderSelectKnob({super.name = 'Priority Encoder Selection'})
      : super({});

  /// Returns the selected priority-encoder generator.
  PriorityEncoder Function(Logic input, {bool generateValid, String name})
      selectedPriorityEncoder() =>
          _generators[implementationKnob.value] ??
          (throw RohdHclException('Unknown priority-encoder implementation: '
              '${implementationKnob.value}'));

  @override
  Map<String, ConfigKnob<dynamic>> get subKnobs => {
        'Implementation': implementationKnob,
      };
}
