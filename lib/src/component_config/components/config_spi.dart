// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_spi.dart
// Configurator for documented SPI gaskets.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Available SPI gasket roles.
enum SpiRole {
  /// Drive an SPI interface as the main controller.
  main,

  /// Consume an SPI interface as a subordinate device.
  sub,
}

/// A [Configurator] for [SpiMain] and [SpiSub].
class SpiConfigurator extends Configurator {
  /// Number of serial bits per transaction.
  final IntConfigKnob dataLengthKnob = IntConfigKnob(value: 8);

  /// Gasket role.
  final ChoiceConfigKnob<SpiRole> roleKnob = ChoiceConfigKnob(
    SpiRole.values,
    value: SpiRole.main,
    choiceLabels: const {
      SpiRole.main: 'Main',
      SpiRole.sub: 'Sub',
    },
  );

  /// Whether a subordinate exposes a bus-in input for MISO transmission.
  final ToggleConfigKnob subBusInKnob = ToggleConfigKnob(value: true);

  /// Whether a subordinate exposes reset and done signals.
  final ToggleConfigKnob subResetKnob = ToggleConfigKnob(value: true);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Data Length': dataLengthKnob,
    'Role': roleKnob,
    if (roleKnob.value == SpiRole.sub) 'Subordinate Bus Input': subBusInKnob,
    if (roleKnob.value == SpiRole.sub) 'Subordinate Reset': subResetKnob,
  });

  @override
  Module createModule() {
    final intf = SpiInterface(dataLength: dataLengthKnob.value);
    return roleKnob.value == SpiRole.main
        ? SpiMain(
            intf,
            clk: Logic(),
            reset: Logic(),
            start: Logic(),
            busIn: Logic(width: dataLengthKnob.value),
          )
        : SpiSub(
            intf: intf,
            busIn:
                subBusInKnob.value ? Logic(width: dataLengthKnob.value) : null,
            reset: subResetKnob.value ? Logic() : null,
          );
  }

  @override
  String get name => 'SPI Gasket';
}
