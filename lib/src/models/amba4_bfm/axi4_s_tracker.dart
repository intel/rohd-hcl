// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_s_tracker.dart
// Monitors that watch the AXI-S interfaces.
//
// 2025 January
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A tracker for AXI-S.
class Axi4StreamTracker extends Tracker<Axi4StreamPacket> {
  /// Tracker field for simulation time.
  static const timeField = 'time';

  /// Tracker field for ID.
  static const idField = 'ID';

  /// Tracker field for USER.
  static const userField = 'USER';

  /// Tracker field for DEST.
  static const destField = 'DEST';

  /// Tracker field for DATA.
  static const dataField = 'DATA';

  /// Tracker field for STRB.
  static const strbField = 'STRB';

  /// Tracker field for KEEP.
  static const keepField = 'KEEP';

  /// Constructor.
  Axi4StreamTracker({
    String name = 'Axi4STracker',
    super.dumpJson,
    super.dumpTable,
    super.outputFolder,
    int timeColumnWidth = 12,
    int idColumnWidth = 0,
    int userColumnWidth = 0,
    int destColumnWidth = 0,
    int dataColumnWidth = 64,
    int strbColumnWidth = 0,
    int keepColumnWidth = 0,
  }) : super(name, [
          TrackerField(timeField, columnWidth: timeColumnWidth),
          if (idColumnWidth > 0)
            TrackerField(idField, columnWidth: idColumnWidth),
          if (userColumnWidth > 0)
            TrackerField(userField, columnWidth: userColumnWidth),
          if (destColumnWidth > 0)
            TrackerField(destField, columnWidth: destColumnWidth),
          TrackerField(dataField, columnWidth: dataColumnWidth),
          if (strbColumnWidth > 0)
            TrackerField(strbField, columnWidth: strbColumnWidth),
          if (keepColumnWidth > 0)
            TrackerField(keepField, columnWidth: keepColumnWidth)
        ]);
}
