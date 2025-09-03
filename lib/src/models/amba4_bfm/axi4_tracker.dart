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

/// A tracker for the AXI4 request channels (AR, AW).
class Axi4RequestTracker extends Tracker<Axi4RequestPacket> {
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

  /// Tracker field for DOMAIN.
  static const domainField = 'DOMAIN';

  /// Tracker field for BAR.
  static const barField = 'BAR';

  /// Constructor.
  Axi4RequestTracker({
    String name = 'Axi4RequestTracker',
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
    int domainColumnWidth = 0,
    int barColumnWidth = 0,
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
          if (domainColumnWidth > 0)
            TrackerField(domainField, columnWidth: domainColumnWidth),
          if (barColumnWidth > 0)
            TrackerField(barField, columnWidth: barColumnWidth),
        ]);
}

/// A tracker for the AXI4 data channels (R, W).
class Axi4DataTracker extends Tracker<Axi4DataPacket> {
  /// Tracker field for simulation time.
  static const timeField = 'time';

  /// Tracker field for type (R/W).
  static const typeField = 'type';

  /// Tracker field for ID.
  static const idField = 'ID';

  /// Tracker field for USER.
  static const userField = 'USER';

  /// Tracker field for RESP.
  static const respField = 'RESP';

  /// Tracker field for DATA.
  static const dataField = 'DATA';

  /// Tracker field for STRB.
  static const strbField = 'STRB';

  /// Constructor.
  Axi4DataTracker({
    String name = 'Axi4DataTracker',
    super.dumpJson,
    super.dumpTable,
    super.outputFolder,
    int timeColumnWidth = 12,
    int idColumnWidth = 0,
    int userColumnWidth = 0,
    int respColumnWidth = 12,
    int dataColumnWidth = 64,
    int strbColumnWidth = 0,
  }) : super(name, [
          TrackerField(timeField, columnWidth: timeColumnWidth),
          const TrackerField(typeField, columnWidth: 1),
          if (idColumnWidth > 0)
            TrackerField(idField, columnWidth: idColumnWidth),
          if (userColumnWidth > 0)
            TrackerField(userField, columnWidth: userColumnWidth),
          if (respColumnWidth > 0)
            TrackerField(respField, columnWidth: respColumnWidth),
          TrackerField(dataField, columnWidth: dataColumnWidth),
          if (strbColumnWidth > 0)
            TrackerField(strbField, columnWidth: strbColumnWidth)
        ]);
}

/// A tracker for the AXI4 response channels (B).
class Axi4ResponseTracker extends Tracker<Axi4ResponsePacket> {
  /// Tracker field for simulation time.
  static const timeField = 'time';

  /// Tracker field for ID.
  static const idField = 'ID';

  /// Tracker field for USER.
  static const userField = 'USER';

  /// Tracker field for RESP.
  static const respField = 'RESP';

  /// Constructor.
  Axi4ResponseTracker({
    String name = 'Axi4ResponseTracker',
    super.dumpJson,
    super.dumpTable,
    super.outputFolder,
    int timeColumnWidth = 12,
    int idColumnWidth = 0,
    int userColumnWidth = 0,
    int respColumnWidth = 12,
  }) : super(name, [
          TrackerField(timeField, columnWidth: timeColumnWidth),
          if (idColumnWidth > 0)
            TrackerField(idField, columnWidth: idColumnWidth),
          if (userColumnWidth > 0)
            TrackerField(userField, columnWidth: userColumnWidth),
          if (respColumnWidth > 0)
            TrackerField(respField, columnWidth: respColumnWidth),
        ]);
}
