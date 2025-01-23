// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_tracker.dart
// Monitors that watch the AXI4 interfaces.
//
// 2025 January
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/models/axi4_bfm/axi4_bfm.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A tracker for the [Axi4ReadInterface] or [Axi4WriteInterface].
class Axi4Tracker extends Tracker<Axi4RequestPacket> {
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

  /// Tracker field for PROT.
  static const protField = 'PROT';

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

  /// Creates a new tracker for [Axi4ReadInterface] and [Axi4WriteInterface].
  ///
  /// If the [selectColumnWidth] is set to 0, the field will be omitted.
  Axi4Tracker({
    required Axi4ReadInterface rIntf,
    required Axi4WriteInterface wIntf,
    String name = 'Axi4Tracker',
    super.dumpJson,
    super.dumpTable,
    super.outputFolder,
    int timeColumnWidth = 12,
    int idColumnWidth = 0,
    int addrColumnWidth = 12,
    int lenColumnWidth = 12,
    int sizeColumnWidth = 0,
    int burstColumnWidth = 0,
    int lockColumnWidth = 0,
    int cacheColumnWidth = 0,
    int protColumnWidth = 4,
    int qosColumnWidth = 0,
    int regionColumnWidth = 0,
    int userColumnWidth = 0,
    int respColumnWidth = 12,
    int ruserColumnWidth = 0,
    int dataColumnWidth = 64,
    int strbColumnWidth = 0,
  }) : super(name, [
          TrackerField(timeField, columnWidth: timeColumnWidth),
          const TrackerField(typeField, columnWidth: 1),
          if (idColumnWidth > 0)
            TrackerField(idField, columnWidth: idColumnWidth),
          TrackerField(addrField, columnWidth: addrColumnWidth),
          if (lenColumnWidth > 0)
            TrackerField(lenField, columnWidth: lenColumnWidth),
          if (sizeColumnWidth > 0)
            TrackerField(sizeField, columnWidth: sizeColumnWidth),
          if (burstColumnWidth > 0)
            TrackerField(burstField, columnWidth: burstColumnWidth),
          if (lockColumnWidth > 0)
            TrackerField(lockField, columnWidth: lockColumnWidth),
          if (cacheColumnWidth > 0)
            TrackerField(cacheField, columnWidth: cacheColumnWidth),
          TrackerField(protField, columnWidth: protColumnWidth),
          if (qosColumnWidth > 0)
            TrackerField(qosField, columnWidth: qosColumnWidth),
          if (regionColumnWidth > 0)
            TrackerField(regionField, columnWidth: regionColumnWidth),
          if (userColumnWidth > 0)
            TrackerField(userField, columnWidth: userColumnWidth),
          if (respColumnWidth > 0)
            TrackerField(respField, columnWidth: respColumnWidth),
          if (ruserColumnWidth > 0)
            TrackerField(rUserField, columnWidth: ruserColumnWidth),
          TrackerField(dataField, columnWidth: dataColumnWidth),
          if (strbColumnWidth > 0)
            TrackerField(strbField, columnWidth: strbColumnWidth),
        ]);
}
