// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_sub_driver.dart
// A driver for SPI Sub.
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
class SpiSubDriver extends PendingDriver<SpiPacket> {
  /// The interface to drive.
  final SpiInterface intf;

  /// Creates a new [SpiSubDriver].
  SpiSubDriver({
    required Component parent,
    required this.intf,
    required super.sequencer,
    String name = 'spiSubDriver',
  }) : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      intf.miso.inject('z'); //high impedance
    });

    while (!Simulator.simulationHasEnded) {
      if (pendingSeqItems.isNotEmpty) {
        await _drivePacket(pendingSeqItems.removeFirst());
      } else {
        Simulator.injectAction(() {
          intf.miso.put('z');
        });
      }
    }
  }
  // maybe not necessary
  // Simulator.injectAction(() {
  //  intf.miso.put(0);
  //});

  /// Drives a packet onto the interface.
  Future<void> _drivePacket(SpiPacket packet) async {
    // Loop through the bits of the packet
    for (var i = 0; i < packet.data.width; i++) {
      intf.sclk.posedge.listen((_) {
        Simulator.injectAction(() {
          intf.miso.put(packet.data[i]);
        });
      });
    }
    // Wait for the next clock cycle
  }

  // wait for miso to be ready?
}
