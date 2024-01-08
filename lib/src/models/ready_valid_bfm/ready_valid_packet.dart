// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_packet.dart
// A monitor for ready/valid protocol.
//
// 2024 January 5
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A packet to be transmitted over a ready/valid interface.
class ReadyValidPacket extends SequenceItem implements Trackable {
  /// The data associated with this packet.
  final LogicValue data;

  /// Constructs a new packet with associated [data].
  ReadyValidPacket(this.data);

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case ReadyValidTracker.timeField:
        return Simulator.time.toString();
      case ReadyValidTracker.dataField:
        return data.toString();
    }

    return null;
  }
}
