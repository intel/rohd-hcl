// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_packet.dart
// Packet the SPI interface.
//
// 2024 September 23
// Author: Roberto Torres <roberto.torres@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A packet for the [SpiInterface].
class SpiPacket extends SequenceItem implements Trackable {
  /// The data in the packet.
  final LogicValue data;

  /// Creates a new packet.
  SpiPacket({required this.data});

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case SpiTracker.timeField:
        return Simulator.time.toString();
      case SpiTracker.dataField:
        return data.toString();
    }

    return trackerString(field);
  }
}

// add switch for mosi vs miso