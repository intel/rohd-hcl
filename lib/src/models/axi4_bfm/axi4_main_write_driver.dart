// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_main_driver.dart
// A driver for AXI4 requests.
//
// 2025 January
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/interfaces.dart';
import 'package:rohd_hcl/src/models/axi4_bfm/axi4_bfm.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A driver for the [Axi4WriteInterface] interface.
///
/// Driving from the perspective of the Main agent.
class Axi4WriteMainDriver extends PendingClockedDriver<Axi4WriteRequestPacket> {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// AXI4 Write Interface.
  final Axi4WriteInterface wIntf;

  /// Creates a new [Axi4WriteMainDriver].
  Axi4WriteMainDriver({
    required Component parent,
    required this.sIntf,
    required this.wIntf,
    required super.sequencer,
    super.timeoutCycles = 500,
    super.dropDelayCycles = 30,
    String name = 'axi4WriteMainDriver',
  }) : super(
          name,
          parent,
          clk: sIntf.clk,
        );

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      wIntf.awValid.put(0);
      wIntf.awId?.put(0);
      wIntf.awAddr.put(0);
      wIntf.awLen?.put(0);
      wIntf.awSize?.put(0);
      wIntf.awBurst?.put(0);
      wIntf.awLock?.put(0);
      wIntf.awCache?.put(0);
      wIntf.awProt.put(0);
      wIntf.awQos?.put(0);
      wIntf.awRegion?.put(0);
      wIntf.awUser?.put(0);
      wIntf.wValid.put(0);
      wIntf.wData.put(0);
      wIntf.wStrb.put(0);
      wIntf.wLast.put(0);
      wIntf.bReady.put(0);
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
  Future<void> _drivePacket(Axi4RequestPacket packet) async {
    if (packet is Axi4WriteRequestPacket) {
      logger.info('Driving write packet.');
      await _driveWritePacket(packet);
    } else {
      await sIntf.clk.nextPosedge;
    }
  }

  // TODO(kimmeljo): need a more robust way of driving
  // the "ready" signals BREADY for write responses
  // specifically, when should they toggle on/off?
  //  ON => either always or when the associated request is driven?
  //  OFF => either never or when there are no more
  //         outstanding requests of the given type?
  // should we enable the ability to backpressure??

  Future<void> _driveWritePacket(Axi4WriteRequestPacket packet) async {
    await sIntf.clk.nextPosedge;
    Simulator.injectAction(() {
      wIntf.awValid.put(1);
      wIntf.awId?.put(packet.id);
      wIntf.awAddr.put(packet.addr);
      wIntf.awLen?.put(packet.len);
      wIntf.awSize?.put(packet.size);
      wIntf.awBurst?.put(packet.burst);
      wIntf.awLock?.put(packet.lock);
      wIntf.awCache?.put(packet.cache);
      wIntf.awProt.put(packet.prot);
      wIntf.awQos?.put(packet.qos);
      wIntf.awRegion?.put(packet.region);
      wIntf.awUser?.put(packet.user);
      wIntf.bReady.put(1);
    });

    // need to hold the request until receiver is ready
    await sIntf.clk.nextPosedge;
    if (!wIntf.awReady.previousValue!.toBool()) {
      await wIntf.awReady.nextPosedge;
    }

    // now we can release the request
    Simulator.injectAction(() {
      wIntf.awValid.put(0);
    });

    // next send the data for the write
    for (var i = 0; i < packet.data.length; i++) {
      if (!wIntf.wReady.previousValue!.toBool()) {
        await wIntf.wReady.nextPosedge;
      }
      Simulator.injectAction(() {
        final isLast = i == packet.data.length - 1;
        wIntf.wValid.put(1);
        wIntf.wData.put(packet.data[i]);
        wIntf.wStrb.put(packet.strobe[i]);
        wIntf.wLast.put(isLast ? 1 : 0);
        wIntf.wUser?.put(packet.wUser);
        if (isLast) {
          packet.complete();
        }
      });
      await sIntf.clk.nextPosedge;
    }

    // now we can stop the write data
    // in the future, we may want to wait for the response to complete
    Simulator.injectAction(() {
      wIntf.wValid.put(0);
    });
  }
}
