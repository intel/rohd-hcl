// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_rf.dart
// Configurator for a RegisterFile.
//
// 2023 December 6
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [RegisterFile]s.
class RegisterFileConfigurator extends Configurator {
  /// Controls the number of entries in the RF.
  final IntConfigKnob numEntriesKnob = IntConfigKnob(value: 8);

  /// Controls the width of the data.
  final IntConfigKnob dataWidthKnob = IntConfigKnob(value: 16);

  /// Controls the width of the address.
  final IntConfigKnob addrWidthKnob = IntConfigKnob(value: 4);

  /// Controls whether write data is masked.
  final ToggleConfigKnob maskedWritesKnob = ToggleConfigKnob(value: false);

  /// Controls the number of write ports.
  final IntConfigKnob numWritePortsKnobs = IntConfigKnob(value: 1);

  /// Controls the number of read ports.
  final IntConfigKnob numReadPortsKnobs = IntConfigKnob(value: 1);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Number of entries': numEntriesKnob,
    'Data width': dataWidthKnob,
    'Address width': addrWidthKnob,
    'Number of read ports': numReadPortsKnobs,
    'Number of write ports': numWritePortsKnobs,
    'Masked write data': maskedWritesKnob,
  });

  @override
  Module createModule() => RegisterFile(
        Logic(),
        Logic(),
        List.generate(
            numWritePortsKnobs.value,
            (index) => maskedWritesKnob.value
                ? MaskedDataPortInterface(
                    dataWidthKnob.value, addrWidthKnob.value)
                : DataPortInterface(dataWidthKnob.value, addrWidthKnob.value)),
        List.generate(
            numReadPortsKnobs.value,
            (index) =>
                DataPortInterface(dataWidthKnob.value, addrWidthKnob.value)),
        numEntries: numEntriesKnob.value,
      );

  @override
  final String name = 'Register File';
}
