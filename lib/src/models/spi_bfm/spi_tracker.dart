// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_tracker.dart
// A monitor that watches the SPI interface.
//
// 2024 September 23
// Author: Roberto Torres <roberto.torres@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A tracker for [SpiInterface].
class SpiTracker extends Tracker<SpiPacket> {
  /// The interface to watch.
  final SpiInterface intf;

  /// Tracker field for simulation time.
  static const timeField = 'time';

  /// Tracker field for type from: Main or Sub.
  static const typeField = 'from';

  /// Tracker field for data.
  static const dataField = 'data';

  /// Creates a new tracker for [SpiInterface].
  SpiTracker({
    required this.intf,
    String name = 'spiTracker',
    super.dumpJson,
    super.dumpTable,
    super.outputFolder,
    int timeColumnWidth = 8,
    int dataColumnWidth = 8,
    int typeColumnWidth = 8,
  }) : super(name, [
          TrackerField(timeField, columnWidth: timeColumnWidth),
          TrackerField(typeField, columnWidth: typeColumnWidth),
          TrackerField(dataField, columnWidth: dataColumnWidth),
        ]);
}
