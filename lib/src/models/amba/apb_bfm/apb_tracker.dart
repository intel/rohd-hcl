// Copyright (C) 2023-2024 Intel Corporation
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
  static const timeField = 'time';

  /// Tracker field for select.
  static const selectField = 'select';

  /// Tracker field for type (R/W).
  static const typeField = 'type';

  /// Tracker field for address.
  static const addrField = 'addr';

  /// Tracker field for data.
  static const dataField = 'data';

  /// Tracker field for strobe.
  static const strobeField = 'strobe';

  /// Tracker field for errors.
  static const slverrField = 'slverr';

  /// Creates a new tracker for [ApbInterface].
  ///
  /// If the [selectColumnWidth] is set to 0, the field will be omitted.
  ApbTracker({
    required ApbInterface intf,
    String name = 'apbTracker',
    super.dumpJson,
    super.dumpTable,
    super.outputFolder,
    int timeColumnWidth = 12,
    int selectColumnWidth = 4,
    int addrColumnWidth = 12,
    int dataColumnWidth = 12,
  }) : super(name, [
          TrackerField(timeField, columnWidth: timeColumnWidth),
          if (selectColumnWidth > 0)
            TrackerField(selectField, columnWidth: selectColumnWidth),
          const TrackerField(typeField, columnWidth: 1),
          TrackerField(addrField, columnWidth: addrColumnWidth),
          TrackerField(dataField, columnWidth: dataColumnWidth),
          const TrackerField(strobeField, columnWidth: 4),
          if (intf.includeSlvErr)
            const TrackerField(slverrField, columnWidth: 1),
        ]);
}
