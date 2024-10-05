// Copyright (C) 2024 Intel Corporation
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
  }) : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      intf.cs.put(1);
      intf.sclk.put(0);
      intf.mosi.put(0);
    });

    while (!Simulator.simulationHasEnded) {
      if (pendingSeqItems.isNotEmpty) {
        await _drivePacket(pendingSeqItems.removeFirst());
      } else {
        await clk.nextPosedge;
        Simulator.injectAction(() {
          intf.cs.put(1);
          intf.sclk.put(0);
          intf.mosi.put(0);
        });
      }
    }
  }

  /// Drives a packet onto the interface.
  Future<void> _drivePacket(SpiPacket packet) async {
    intf.cs.inject(0);

    // will be extended to multiple CS

    // Loop through the bits of the packet
    for (var i = 0; i < packet.data.width; i++) {
      logger.info('Driving main packet, index: $i');
      intf.mosi.inject(packet.data[i]);
      await clk.nextPosedge;
      intf.sclk.inject(1);

      // Wait for the next clock cycle
      await clk.nextNegedge;
      intf.sclk.inject(0);
    }
  }
}
