// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_response_driver.dart
// A driver for AXI4 responses.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/interfaces.dart';
import 'package:rohd_hcl/src/models/amba4_bfm/axi4_bfm.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A driver for the [Axi4BaseBChannelInterface] interface.
///
/// Driving from the perspective of the Main agent.
class Axi4ResponseChannelDriver
    extends PendingClockedDriver<Axi4ResponsePacket> {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// AXI4 B Interface.
  final Axi4BaseBChannelInterface rIntf;

  /// Creates a new [Axi4RequestChannelDriver].
  Axi4ResponseChannelDriver({
    required Component parent,
    required this.sIntf,
    required this.rIntf,
    required super.sequencer,
    super.timeoutCycles = 500,
    super.dropDelayCycles = 30,
    String name = 'axi4ResponseChannelInterface',
  }) : super(
          name,
          parent,
          clk: sIntf.clk,
        );

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      rIntf.valid.put(0);
      rIntf.id?.put(0);
      rIntf.resp?.put(0);
      rIntf.user?.put(0);
    });

    // wait for reset to complete before driving anything
    await sIntf.resetN.nextPosedge;

    while (!Simulator.simulationHasEnded) {
      if (pendingSeqItems.isNotEmpty) {
        await _drivePacket(pendingSeqItems.removeFirst());
      } else {
        await sIntf.clk.nextPosedge;
      }
    }
  }

  /// Drives a packet onto the interface.
  Future<void> _drivePacket(Axi4ResponsePacket packet) async {
    logger.info('Driving response packet.');
    await _driveRequestPacket(packet);
  }

  Future<void> _driveRequestPacket(Axi4ResponsePacket packet) async {
    await sIntf.clk.nextPosedge;
    Simulator.injectAction(() {
      rIntf.valid.put(1);
      rIntf.id?.put(packet.id);
      rIntf.resp?.put(packet.resp);
      rIntf.user?.put(packet.user);
    });

    // need to hold the request until receiver is ready
    await sIntf.clk.nextPosedge;
    if (!rIntf.ready.previousValue!.toBool()) {
      await rIntf.ready.nextPosedge;
    }

    // now we can release the request
    // in the future, we may want to wait for the response to complete
    Simulator.injectAction(() {
      rIntf.valid.put(0);
      packet.complete();
    });
  }
}
