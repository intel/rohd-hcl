// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_packet.dart
// Packet the SPI interface.
//
// 2024 September 23
// Author: Roberto Torres <roberto.torres@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// s [SpiDirection] [write] f [read] f
enum SpiDirection { write, read }

/// A packet for the [SpiInterface].
class SpiPacket extends SequenceItem implements Trackable {
  ///
  final LogicValue data;

  ///
  final SpiDirection? direction;

  /// Creates a new packet.
  SpiPacket({required this.data, this.direction});

  /// A [Future] that completes once the read has been completed.
  Future<void> get completed => _completer.future;
  final Completer<void> _completer = Completer<void>();

  /// Called by a completer when a transfer is completed.
  void complete() {
    _completer.complete();
  }

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case SpiTracker.timeField:
        return Simulator.time.toString();
      case SpiTracker.typeField:
        return direction?.name.substring(0, 1);
      case SpiTracker.dataField:
        return data.toString();
    }

    return null;
  }
}
