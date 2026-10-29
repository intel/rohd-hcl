// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_async_fifo.dart
// Configurator for asynchronous FIFOs.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [AsyncFifo].
class AsyncFifoConfigurator extends Configurator {
  /// Width of the FIFO data input and output.
  final IntConfigKnob dataWidthKnob = IntConfigKnob(value: 8);

  /// Number of FIFO entries. This must be a power of two.
  final IntConfigKnob depthKnob = IntConfigKnob(value: 8);

  /// Number of synchronizer stages between the clock domains.
  final IntConfigKnob syncStagesKnob = IntConfigKnob(value: 2);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Data Width': dataWidthKnob,
    'Depth': depthKnob,
    'Synchronization Stages': syncStagesKnob,
  });

  @override
  Module createModule() => AsyncFifo(
        writeClk: Logic(),
        readClk: Logic(),
        writeReset: Logic(),
        readReset: Logic(),
        writeEnable: Logic(),
        writeData: Logic(width: dataWidthKnob.value),
        readEnable: Logic(),
        depth: depthKnob.value,
        syncStages: syncStagesKnob.value,
      );

  @override
  String get name => 'Asynchronous FIFO';
}
