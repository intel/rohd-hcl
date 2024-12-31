// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_monitor.dart
// A monitor that watches the SPI interface.
//
// 2024 September 23
// Author: Roberto Torres <roberto.torres@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A monitor for [SpiInterface]s.
class SpiMonitor extends Monitor<SpiPacket> {
  /// The interface to watch.
  final SpiInterface intf;

  /// The direction to monitor.
  final SpiDirection? direction;

  /// Creates a new [SpiMonitor] for [intf].
  SpiMonitor(
      {required this.intf,
      required Component parent,
      this.direction,
      String name = 'spiMonitor'})
      : super(name, parent);

  /// Run function.
  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final dataListRead = <LogicValue>[];
    final dataListWrite = <LogicValue>[];

    intf.sclk.posedge.listen((event) {
      if (direction == null || direction == SpiDirection.main) {
        dataListWrite.add(intf.mosi.previousValue!);
      }
      if (direction == null || direction == SpiDirection.sub) {
        dataListRead.add(intf.miso.previousValue!);
      }

      if (dataListWrite.length == intf.dataLength) {
        add(SpiPacket(
            data: dataListWrite.rswizzle(), direction: SpiDirection.main));
        dataListWrite.clear();
      }
      if (dataListRead.length == intf.dataLength) {
        add(SpiPacket(
            data: dataListRead.rswizzle(), direction: SpiDirection.sub));
        dataListRead.clear();
      }
    });
  }
}
