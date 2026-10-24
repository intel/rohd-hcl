// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_parity.dart
// Configurator for parity transmitter and receiver modules.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Available parity module directions.
enum ParityDirection {
  /// Add a parity bit to data for transmission.
  transmitter,

  /// Check a received transmission and report parity errors.
  receiver,
}

/// A [Configurator] for parity transmitters and receivers.
class ParityConfigurator extends Configurator {
  @override
  ComponentCategory get category => ComponentCategory.errorControl;

  @override
  String get subcategory => 'protection';

  /// Width of the data input or received transmission.
  final IntConfigKnob widthKnob = PositiveIntConfigKnob(value: 8);

  /// Parity module direction.
  final ChoiceConfigKnob<ParityDirection> directionKnob = ChoiceConfigKnob(
    ParityDirection.values,
    value: ParityDirection.transmitter,
    choiceLabels: const {
      ParityDirection.transmitter: 'Transmitter',
      ParityDirection.receiver: 'Receiver',
    },
  );

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Width': widthKnob,
    'Direction': directionKnob,
  });

  @override
  Module createModule() => directionKnob.value == ParityDirection.transmitter
      ? ParityTransmitter(Logic(width: widthKnob.value))
      : ParityReceiver(Logic(width: widthKnob.value));

  @override
  String get name => 'Parity';
}
