// Copyright (C) 2024-2026 Intel Corporation
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
import 'package:rohd_hcl/src/models/amba/amba4_bfm/axi4_bfm.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Common response driver for AXI and ACE response channels.
class Axi4ResponseChannelDriverBase<T extends Axi4ResponseChannelInterface>
    extends PendingClockedDriver<Axi4ResponsePacket> {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// Response interface.
  final T rIntf;

  /// Creates a response channel driver.
  Axi4ResponseChannelDriverBase({
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
      if (rIntf is Ace4CrChannelInterface) {
        (rIntf as Ace4CrChannelInterface).last?.put(0);
      }
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
      if (rIntf is Ace4CrChannelInterface) {
        (rIntf as Ace4CrChannelInterface).last?.put(1);
      }
    });

    // need to hold the request until receiver is ready
    await sIntf.clk.nextPosedge;
    while (!rIntf.ready.previousValue!.toBool()) {
      await sIntf.clk.nextPosedge;
    }

    // now we can release the request
    // in the future, we may want to wait for the response to complete
    Simulator.injectAction(() {
      rIntf.valid.put(0);
      packet.complete();
    });
  }
}

/// A driver for an AXI4 write response channel.
class Axi4ResponseChannelDriver
    extends Axi4ResponseChannelDriverBase<Axi4BaseBChannelInterface> {
  /// Creates a write response channel driver.
  Axi4ResponseChannelDriver({
    required super.parent,
    required super.sIntf,
    required super.rIntf,
    required super.sequencer,
    super.timeoutCycles,
    super.dropDelayCycles,
    super.name,
  });
}

/// Drives single-beat ACE4 snoop responses in either signal layout.
class Ace4SnoopResponseChannelDriver
    extends Axi4ResponseChannelDriverBase<Ace4CrChannelInterface> {
  /// Creates a snoop response driver.
  Ace4SnoopResponseChannelDriver({
    required super.parent,
    required super.sIntf,
    required super.rIntf,
    required super.sequencer,
    super.timeoutCycles,
    super.dropDelayCycles,
    super.name = 'ace4SnoopResponseChannelDriver',
  });
}
