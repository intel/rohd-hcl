// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// apb_tracker.dart
// A monitor that watches the APB interface.
//
// 2023 June 12
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A tracker for the [ApbInterface].
class ApbTracker extends Tracker<ApbPacket> {
  /// Tracker field for simulation time.
  static const timeField = TrackerField('time', columnWidth: 12);

  /// Tracker field for select.
  static const selectField = TrackerField('select', columnWidth: 4);

  /// Tracker field for type (R/W).
  static const typeField = TrackerField('type', columnWidth: 1);

  /// Tracker field for address.
  static const addrField = TrackerField('addr', columnWidth: 12);

  /// Tracker field for data.
  static const dataField = TrackerField('data', columnWidth: 12);

  /// Tracker field for strobe.
  static const strobeField = TrackerField('strobe', columnWidth: 4);

  /// Tracker field for errors.
  static const slverrField = TrackerField('slverr', columnWidth: 1);

  /// Creates a new tracker for [ApbInterface].
  ApbTracker({
    required ApbInterface intf,
    String name = 'apbTracker',
    super.dumpJson,
    super.dumpTable,
    super.outputFolder,
  }) : super(name, [
          timeField,
          typeField,
          addrField,
          dataField,
          strobeField,
          if (intf.includeSlvErr) slverrField,
        ]);
}
