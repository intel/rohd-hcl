// Copyright (C) 2025-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// multiplier_select_knob.dart
// An multipler selection knob for use in arithmetic component configuration.
//
// 2025 April 27
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A knob for selecting a multiplier to use in a component.
class MultiplierSelectKnob extends GroupOfKnobs {
  /// Whether to instantiate a [CompressionTreeMultiplier] (or use a
  /// [NativeMultiplier]).
  final ToggleConfigKnob compressionTreeMultiplierKnob = ToggleConfigKnob(
    value: false,
  );

  /// Controls the Booth encoding radix of the multiplier.
  final radixKnob = ChoiceConfigKnob<int>([2, 4, 8, 16], value: 4);

  /// Adder selection control.
  final adderSelectionKnob = AdderSelectKnob(name: 'Final Adder Type');

  /// Controls the width of the multiplicand.!
  final IntConfigKnob multiplicandWidthKnob = IntConfigKnob(value: 4);

  /// Controls the width of the multiplier.!
  final IntConfigKnob multiplierWidthKnob = IntConfigKnob(value: 4);

  /// A knob controlling the sign of the multiplicand
  final ChoiceConfigKnob<String> signMultiplicandValueKnob = ChoiceConfigKnob([
    'unsigned',
    'signed',
    'selected',
  ], value: 'unsigned');

  /// A knob controlling the sign of the multiplier
  final ChoiceConfigKnob<String> signMultiplierValueKnob = ChoiceConfigKnob([
    'unsigned',
    'signed',
    'selected',
  ], value: 'unsigned');

  /// Controls whether the adder is pipelined
  final ToggleConfigKnob pipelinedKnob = ToggleConfigKnob(value: false);

  /// Option to allow signed operands.
  late final bool allowSigned;

  /// Option to allow pipelining selection.
  late final bool allowPipelining;

  /// Resolves the multiplicand signedness configuration.
  dynamic get signedMultiplicandConfig =>
      _signedConfig(signMultiplicandValueKnob.value, 'signedMultiplicand');

  /// Resolves the multiplier signedness configuration.
  dynamic get signedMultiplierConfig =>
      _signedConfig(signMultiplierValueKnob.value, 'signedMultiplier');

  @override
  Map<String, ConfigKnob<dynamic>> get subKnobs => {
        'Compression Tree Multiplier': compressionTreeMultiplierKnob,
        if (compressionTreeMultiplierKnob.value) 'Radix': radixKnob,
        'Multiplicand width': multiplicandWidthKnob,
        if (allowSigned) 'Multiplicand sign': signMultiplicandValueKnob,
        'Multiplier width': multiplierWidthKnob,
        if (allowSigned) 'Multiplier sign': signMultiplierValueKnob,
        'Final Adder Select': adderSelectionKnob,
        if (allowPipelining & compressionTreeMultiplierKnob.value)
          'Pipelined': pipelinedKnob,
      };

  /// Constructor for [MultiplierSelectKnob] allows for exposing or hiding
  /// some of the configuration knobs.
  /// - [allowSigned] is `false` by default, making the multiplier unsigned.
  /// - [allowPipelining] is `false` by default, making the multiplier
  /// combinational.
  MultiplierSelectKnob({
    required this.allowSigned,
    required this.allowPipelining,
    super.name = 'Multiplier Select',
  }) : super({});

  dynamic _signedConfig(String value, String inputName) => switch (value) {
        'unsigned' => false,
        'signed' => true,
        'selected' => Logic(name: inputName),
        _ => throw RohdHclException('Unknown signedness selection: $value'),
      };

  /// Return the [Multiplier] Functor selected.
  Multiplier Function(
    Logic term1,
    Logic term2, {
    Logic? clk,
    Logic? reset,
    Logic? enable,
    String name,
    String? definitionName,
  }) selectedMultiplier(
      {dynamic signedMultiplicand, dynamic signedMultiplier}) {
    final multiplicandSign = signedMultiplicand ?? signedMultiplicandConfig;
    final multiplierSign = signedMultiplier ?? signedMultiplierConfig;

    if (compressionTreeMultiplierKnob.value) {
      return (
        Logic term1,
        Logic term2, {
        Logic? clk,
        Logic? reset,
        Logic? enable,
        String name = 'comp_tree_multiplier',
        String? definitionName,
      }) =>
          CompressionTreeMultiplier(
            term1,
            term2,
            radix: radixKnob.value,
            adderGen: adderSelectionKnob.selectedAdder(),
            clk: clk,
            reset: reset,
            enable: enable,
            signedMultiplicand: multiplicandSign,
            signedMultiplier: multiplierSign,
            name: name,
            definitionName: definitionName,
          );
    }
    return (
      Logic term1,
      Logic term2, {
      Logic? clk,
      Logic? reset,
      Logic? enable,
      String name = 'native_multiplier',
      String? definitionName,
    }) =>
        NativeMultiplier(
          term1,
          term2,
          clk: clk,
          reset: reset,
          enable: enable,
          signedMultiplicand: multiplicandSign,
          signedMultiplier: multiplierSign,
          name: name,
          definitionName: definitionName,
        );
  }
}
