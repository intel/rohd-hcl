// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_thermometer.dart
// Configurators for thermometer-code conversion.
//
// 2026 November 8
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Configures a binary-to-thermometer encoder.
class BinaryToThermometerConfigurator extends Configurator {
  /// Width of the binary input.
  final IntConfigKnob binaryWidthKnob = PositiveIntConfigKnob(value: 4);

  /// Width of the thermometer output.
  final IntConfigKnob thermometerWidthKnob = PositiveIntConfigKnob(value: 8);

  @override
  ComponentCategory get category => ComponentCategory.encodings;

  @override
  String get subcategory => 'thermometer';

  @override
  String get name => 'Binary to Thermometer';

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Binary Width': binaryWidthKnob,
        'Thermometer Width': thermometerWidthKnob,
      };

  @override
  Module createModule() => BinaryToThermometer(
        Logic(name: 'binary', width: binaryWidthKnob.value),
        outputWidth: thermometerWidthKnob.value,
      );
}

/// Configures a thermometer-to-binary decoder.
class ThermometerToBinaryConfigurator extends Configurator {
  /// Width of the thermometer input.
  final IntConfigKnob thermometerWidthKnob = PositiveIntConfigKnob(value: 8);

  @override
  ComponentCategory get category => ComponentCategory.encodings;

  @override
  String get subcategory => 'thermometer';

  @override
  String get name => 'Thermometer to Binary';

  @override
  Map<String, ConfigKnob<dynamic>> get knobs =>
      {'Thermometer Width': thermometerWidthKnob};

  @override
  Module createModule() => ThermometerToBinary(
        Logic(name: 'thermometer', width: thermometerWidthKnob.value),
      );
}
