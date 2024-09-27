// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_monitor.dart
// A monitor that watches the SPI interface.
//
// 2024 September 23
// Author: Roberto Torres <roberto.torres@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A monitor for [SpiInterface]s.
class SpiMonitor extends Monitor<SpiPacket> {
  /// The interface to watch.
  final SpiInterface intf;

  /// Creates a new [SpiMonitor] for [intf].
  SpiMonitor(
      {required this.intf,
      required Component parent,
      String name = 'spiMonitor'})
      : super(name, parent);
}
