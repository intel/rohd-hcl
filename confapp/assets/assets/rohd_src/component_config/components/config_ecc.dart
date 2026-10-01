// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_ecc.dart
// Configurator for ECC.
//
// 2024 January 18
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [HammingEccReceiver] and [HammingEccTransmitter].
class EccConfigurator extends Configurator {
  /// A knob controlling the [HammingType].
  final ChoiceConfigKnob<HammingType> typeKnob =
      ChoiceConfigKnob(HammingType.values, value: HammingType.sec);

  /// A knob controlling the data width.
  final IntConfigKnob dataWidthKnob = IntConfigKnob(value: 4);

  @override
  Module createModule() => HammingEccReceiver(
        HammingEccTransmitter(
          Logic(width: dataWidthKnob.value),
          hammingType: typeKnob.value,
        ).transmission,
        hammingType: typeKnob.value,
      );

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = {
    'Data Width': dataWidthKnob,
    'Hamming Type': typeKnob,
  };

  @override
  final String name = 'ECC';
}
