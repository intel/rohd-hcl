// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_serialization.dart
// Configurator for Serializer and Deserializer.
//
// 2024 April 29
// Author: desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [Serializer] and [Deserializer].
class SerializationConfigurator extends Configurator {
  /// Controls whether we are serializing or deserializing.
  final ChoiceConfigKnob<Type> directionKnob =
      ChoiceConfigKnob([Serializer, Deserializer], value: Serializer);

  /// Controls the width of the input.
  final IntConfigKnob inputWidthKnob = IntConfigKnob(value: 8);

  /// Controls the length of the input.
  final IntConfigKnob inputLengthKnob = IntConfigKnob(value: 16);

  /// When available, controls whether to generate an error signal.
  final ToggleConfigKnob enableKnob = ToggleConfigKnob(value: false);

  @override
  Module createModule() {
    final deserializeIn = Logic(width: inputWidthKnob.value);
    final clk = Logic(name: 'clk');
    final reset = Logic(name: 'reset');
    final enable = Logic(name: 'enable');
    return directionKnob.value == Serializer
        ? Serializer(LogicArray([inputLengthKnob.value], inputWidthKnob.value),
            enable: enableKnob.value ? enable : null, clk: clk, reset: reset)
        : Deserializer(deserializeIn, inputLengthKnob.value,
            enable: enableKnob.value ? enable : null, clk: clk, reset: reset);
  }

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Serialize/Deserialize': directionKnob,
        if (directionKnob.value == Serializer) 'Input length': inputLengthKnob,
        'Input width': inputWidthKnob,
        'enable': enableKnob,
      };

  @override
  String get name => 'Serialization';
}
