// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_s_driver.dart
// A driver for AXI-S transactions.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/interfaces.dart';
import 'package:rohd_hcl/src/models/amba4_bfm/axi4_bfm.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A driver for the [Axi4StreamInterface] interface.
class Axi4StreamDriver extends PendingClockedDriver<Axi4StreamPacket> {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// AXI4 Stream Interface.
  final Axi4StreamInterface rIntf;

  /// Creates a new [Axi4StreamDriver].
  Axi4StreamDriver({
    required Component parent,
    required this.sIntf,
    required this.rIntf,
    required super.sequencer,
    super.timeoutCycles = 500,
    super.dropDelayCycles = 30,
    String name = 'axi4StreamDriver',
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
      rIntf.data.put(0);
      rIntf.user?.put(0);
      rIntf.strb.put(0);
      rIntf.keep.put(0);
      rIntf.dest?.put(0);
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
  Future<void> _drivePacket(Axi4StreamPacket packet) async {
    logger.info('Driving stream packet.');
    await _driveStreamPacket(packet);
  }

  Future<void> _driveStreamPacket(Axi4StreamPacket packet) async {
    await sIntf.clk.nextPosedge;
    Simulator.injectAction(() async {
      if (packet.data.width <= rIntf.data.width) {
        rIntf.valid.put(1);
        rIntf.id?.put(packet.id);
        rIntf.user?.put(packet.user);
        rIntf.data.put(packet.data);
        rIntf.strb.put(packet.strb);
        rIntf.keep.put(packet.keep);
        rIntf.dest?.put(packet.dest);
        rIntf.last.put(1);

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
          final endS = min(packet.strb!.width, (i + 1) * rIntf.strbWidth);
          rIntf.strb.put(packet.strb!.getRange(i * rIntf.strb.width, endS));
          final endK = min(packet.keep!.width, (i + 1) * rIntf.strbWidth);
          rIntf.strb.put(packet.keep!.getRange(i * rIntf.keep.width, endK));
          rIntf.dest?.put(packet.dest);
          rIntf.last.put(i == it - 1);

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
