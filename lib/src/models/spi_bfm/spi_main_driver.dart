// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_main_driver.dart
// A driver for SPI Main.
//
// 2024 September 23
// Author: Roberto Torres <roberto.torres@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A driver for the main side of the [SpiInterface].
///
/// Driven packets will update the returned data into the same packet.
class SpiMainDriver extends PendingClockedDriver<SpiPacket> {
  /// The interface to drive.
  final SpiInterface intf;

  /// Creates a new [SpiMainDriver].
  SpiMainDriver({
    required Component parent,
    required this.intf,
    required super.clk,
    required super.sequencer,
    super.dropDelayCycles = 30,
    String name = 'spiMainDriver',
  }) : super(name, parent) {
    intf.sclk <= ~clk & clkenable;
    clkenable.inject(0);
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      intf.csb.put(1);
      intf.mosi.put(0);
    });

    while (!Simulator.simulationHasEnded) {
      if (pendingSeqItems.isNotEmpty) {
        await _drivePacket(pendingSeqItems.removeFirst());
      } else {
        await clk.nextNegedge;
        Simulator.injectAction(() {
          intf.csb.put(1);
          clkenable.inject(0);
          intf.mosi.put(0);
        });
      }
    }
  }

  /// Clock enable signal.
  Logic clkenable = Logic(name: 'clkenable');

  /// Drives a packet onto the interface.
  Future<void> _drivePacket(SpiPacket packet) async {
    intf.csb.inject(0);

    // Loop through the bits of the packet
    for (var i = 1; i <= packet.data.width; i++) {
      intf.mosi.inject(packet.data[-i]);
      await clk.nextNegedge;
      clkenable.inject(1);

      // Wait for the next clock cycle
      await clk.nextPosedge;
    }
  }
}
