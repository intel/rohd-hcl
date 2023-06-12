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
  static const timeField = TrackerField('time', columnWidth: 12);
  static const selectField = TrackerField('select', columnWidth: 4);
  static const typeField = TrackerField('type', columnWidth: 1);
  static const addrField = TrackerField('addr', columnWidth: 12);
  static const dataField = TrackerField('data', columnWidth: 12);
  static const strobeField = TrackerField('strobe', columnWidth: 4);
  static const slverrField = TrackerField('slverr', columnWidth: 1);

  /// Creates a new tracker for [ApbInterface].
  ApbTracker({String name = 'apbTracker'})
      : super(name, [
          timeField,
          typeField,
          addrField,
          dataField,
          strobeField,
          slverrField,
        ]);
}
