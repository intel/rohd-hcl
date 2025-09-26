// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_data_driver.dart
// A driver for AXI4 data.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/interfaces.dart';
import 'package:rohd_hcl/src/models/amba4_bfm/axi4_bfm.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A driver for the [Axi4DataChannelInterface] interface.
class Axi4DataChannelDriver extends PendingClockedDriver<Axi4DataPacket> {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// AXI4 Data Interface.
  final Axi4DataChannelInterface rIntf;

  /// Capture if this is monitoring a write data interface.
  /// If so, it will have a strobe signal.
  late final bool isWr;

  /// Capture if this is monitoring a read data interface.
  /// If so, it will have a response code signal.
  late final bool isRd;

  /// Creates a new [Axi4RequestChannelDriver].
  Axi4DataChannelDriver({
    required Component parent,
    required this.sIntf,
    required this.rIntf,
    required super.sequencer,
    super.timeoutCycles = 500,
    super.dropDelayCycles = 30,
    String name = 'axi4DataChannelInterface',
  }) : super(
          name,
          parent,
          clk: sIntf.clk,
        ) {
    isWr = rIntf is Axi4BaseWChannelInterface;
    isRd = rIntf is Axi4BaseRChannelInterface;
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      rIntf.valid.put(0);
      rIntf.id?.put(0);
      rIntf.data.put(0);
      rIntf.user?.put(0);
      if (isWr) {
        (rIntf as Axi4BaseWChannelInterface).strb.put(0);
      }
      if (isRd) {
        (rIntf as Axi4BaseRChannelInterface).resp?.put(0);
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
  Future<void> _drivePacket(Axi4DataPacket packet) async {
    logger.info('Driving data packet.');
    await _driveRequestPacket(packet);
  }

  Future<void> _driveRequestPacket(Axi4DataPacket packet) async {
    await sIntf.clk.nextPosedge;
    Simulator.injectAction(() async {
      if (packet.data.width <= rIntf.data.width) {
        rIntf.valid.put(1);
        rIntf.id?.put(packet.id);
        rIntf.user?.put(packet.user);
        rIntf.data.put(packet.data);
        rIntf.last?.put(1);
        if (isWr) {
          (rIntf as Axi4BaseWChannelInterface).strb.put(packet.strb);
        }
        if (isRd) {
          (rIntf as Axi4BaseRChannelInterface).resp?.put(packet.resp);
        }

        // need to hold the request until receiver is ready
        await sIntf.clk.nextPosedge;
        if (!rIntf.ready.previousValue!.toBool()) {
          await rIntf.ready.nextPosedge;
        }
      } else {
        final it = (packet.data.width / rIntf.data.width).ceil();
        for (var i = 0; i < it; i++) {
          final end = min(packet.data.width, (i + 1) * rIntf.data.width);
          rIntf.valid.put(1);
          rIntf.id?.put(packet.id);
          rIntf.user?.put(packet.user);
          rIntf.data.put(packet.data.getRange(i * rIntf.data.width, end));
          rIntf.last?.put(i == it - 1);
          if (rIntf is Axi4BaseWChannelInterface) {
            final endS = min(packet.strb!.width,
                (i + 1) * (rIntf as Axi4BaseWChannelInterface).strb.width);
            (rIntf as Axi4BaseWChannelInterface).strb.put(packet.strb!.getRange(
                i * (rIntf as Axi4BaseWChannelInterface).strb.width, endS));
          }
          if (isRd) {
            (rIntf as Axi4BaseRChannelInterface).resp?.put(packet.resp);
          }

          // need to hold the request until receiver is ready
          await sIntf.clk.nextPosedge;
          if (!rIntf.ready.previousValue!.toBool()) {
            await rIntf.ready.nextPosedge;
          }
          await sIntf.clk.nextPosedge;
        }
      }
    });

    // now we can release the request
    // in the future, we may want to wait for the response to complete
    Simulator.injectAction(() {
      rIntf.valid.put(0);
      packet.complete();
    });
  }
}
