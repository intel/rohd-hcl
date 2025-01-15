// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_tracker.dart
// Monitors that watch the AXI4 interfaces.
//
// 2025 January
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A tracker for the [Axi4ReadInterface] or [Axi4WriteInterface].
class Axi4Tracker extends Tracker<Axi4Packet> {
  /// Tracker field for simulation time.
  static const timeField = 'time';

  /// Tracker field for type (R/W).
  static const typeField = 'type';

  /// Tracker field for ID.
  static const idField = 'ID';

  /// Tracker field for ADDR.
  static const addrField = 'ADDR';

  /// Tracker field for LEN.
  static const lenField = 'LEN';

  /// Tracker field for SIZE.
  static const sizeField = 'SIZE';

  /// Tracker field for BURST.
  static const burstField = 'BURST';

  /// Tracker field for LOCK.
  static const lockField = 'LOCK';

  /// Tracker field for CACHE.
  static const cacheField = 'CACHE';

  /// Tracker field for QOS.
  static const qosField = 'QOS';

  /// Tracker field for REGION.
  static const regionField = 'REGION';

  /// Tracker field for USER.
  static const userField = 'USER';

  /// Tracker field for RESP.
  static const respField = 'RESP';

  /// Tracker field for RUSER.
  static const rUserField = 'RUSER';

  /// Tracker field for DATA.
  static const dataField = 'DATA';

  /// Tracker field for STRB.
  static const strbField = 'STRB';

  /// Creates a new tracker for [Axi4ReadInterface].
  ///
  /// If the [selectColumnWidth] is set to 0, the field will be omitted.
  Axi4Tracker({
    required Axi4ReadInterface intf,
    String name = 'Axi4ReadTracker',
    super.dumpJson,
    super.dumpTable,
    super.outputFolder,
    int timeColumnWidth = 12,
    // TODO: Add more fields

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
