// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_rotate.dart
// Configurator for a RippleCarryAdder.
//
// 2023 December 5
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [BinaryToOneHot] and [OneHotToBinary].
class OneHotConfigurator extends Configurator {
  /// Controls whether toggling from binary to one-hot or
  /// from one-hot to binary.
  final ChoiceConfigKnob<Type> directionKnob =
      ChoiceConfigKnob([BinaryToOneHot, OneHotToBinary], value: OneHotToBinary);

  /// Controls the width of the input.
  final IntConfigKnob inputWidthKnob = IntConfigKnob(value: 4);

  /// When available, controls whether to generate an error signal.
  final ToggleConfigKnob generateErrorKnob = ToggleConfigKnob(value: false);

  @override
  Module createModule() {
    final inp = Logic(width: inputWidthKnob.value);
    return directionKnob.value == BinaryToOneHot
        ? BinaryToOneHot(inp)
        : OneHotToBinary(inp, generateError: generateErrorKnob.value);
  }

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Direction': directionKnob,
        'Input width': inputWidthKnob,
        if (directionKnob.value == OneHotToBinary)
          'Generate error': generateErrorKnob,
      };

  @override
  String get name => 'One-hot Converter';
}
