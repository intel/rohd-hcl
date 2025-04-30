// Copyright (C) 2023-2025 Intel Corporation
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
  /// Map from Type to Function for Adder generator
  static Map<Type, Adder Function(Logic, Logic, {Logic? carryIn})>
      adderGeneratorMap = {
    Ripple: (a, b, {carryIn}) => ParallelPrefixAdder(a, b, ppGen: Ripple.new),
    Sklansky: (a, b, {carryIn}) =>
        ParallelPrefixAdder(a, b, ppGen: Sklansky.new),
    KoggeStone: ParallelPrefixAdder.new,
    BrentKung: (a, b, {carryIn}) =>
        ParallelPrefixAdder(a, b, ppGen: BrentKung.new),
    NativeAdder: (a, b, {carryIn}) => NativeAdder(a, b, carryIn: carryIn)
  };

  /// Controls the Booth encoding radix of the multiplier.!
  final radixKnob = ChoiceConfigKnob<int>(
    [2, 4, 8, 16],
    value: 4,
  );

  /// Controls the type of [Adder] used for internal adders.
  final adderTypeKnob =
      ChoiceConfigKnob(adderGeneratorMap.keys.toList(), value: NativeAdder);

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

  /// Controls whether the adder is pipelined
  final ToggleConfigKnob use42CompressorsKnob = ToggleConfigKnob(value: false);

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
      adderGen: adderGeneratorMap[adderTypeKnob.value]!,
      use42Compressors: use42CompressorsKnob.value);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Adder type': adderTypeKnob,
    'Radix': radixKnob,
    'Multiplicand width': multiplicandWidthKnob,
    'Multiplicand sign': signMultiplicandValueKnob,
    'Multiplier width': multiplierWidthKnob,
    'Multiplier sign': signMultiplierValueKnob,
    'Pipelined': pipelinedKnob,
    'Use 4:2 Compressors': use42CompressorsKnob,
  });

  @override
  final String name = 'Comp. Tree Multiplier';
}
