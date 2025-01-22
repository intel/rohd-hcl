// Copyright (C) 2024-2025 Intel Corporation
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

/// Direction of the packet.
enum SpiDirection { main, sub }

/// A packet for the [SpiInterface].
class SpiPacket extends SequenceItem implements Trackable {
  /// The data in the packet.
  final LogicValue data;

  /// Direction of the packet.
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
        return direction?.name;
      case SpiTracker.dataField:
        return data.toString();
    }

    return null;
  }
}
