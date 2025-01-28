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

/// A driver for the [Axi4ReadInterface] and [Axi4WriteInterface] interfaces.
///
/// Driving from the perspective of the Main agent.
class Axi4MainDriver extends PendingClockedDriver<Axi4RequestPacket> {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// AXI4 Read Interface.
  final Axi4ReadInterface rIntf;

  /// AXI4 Write Interface.
  final Axi4WriteInterface wIntf;

  /// Creates a new [Axi4MainDriver].
  Axi4MainDriver({
    required Component parent,
    required this.sIntf,
    required this.rIntf,
    required this.wIntf,
    required super.sequencer,
    super.timeoutCycles = 500,
    super.dropDelayCycles = 30,
    String name = 'axi4MainDriver',
  }) : super(
          name,
          parent,
          clk: sIntf.clk,
        );

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      rIntf.arValid.put(0);
      rIntf.arId?.put(0);
      rIntf.arAddr.put(0);
      rIntf.arLen?.put(0);
      rIntf.arSize?.put(0);
      rIntf.arBurst?.put(0);
      rIntf.arLock?.put(0);
      rIntf.arCache?.put(0);
      rIntf.arProt.put(0);
      rIntf.arQos?.put(0);
      rIntf.arRegion?.put(0);
      rIntf.arUser?.put(0);
      rIntf.rReady.put(0);
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
    print('Driving packet at time ${Simulator.time}');
    if (packet is Axi4ReadRequestPacket) {
      await _driveReadPacket(packet);
    } else if (packet is Axi4WriteRequestPacket) {
      await _driveWritePacket(packet);
    } else {
      await sIntf.clk.nextPosedge;
    }
  }

  // TODO: need a more robust way of driving the "ready" signals...
  //  RREADY for read data responses
  //  BREADY for write responses
  // specifically, when should they toggle on/off?
  //  ON => either always or when the associated request is driven?
  //  OFF => either never or when there are no more outstanding requests of the given type?
  // should we enable the ability to backpressure??

  Future<void> _driveReadPacket(Axi4ReadRequestPacket packet) async {
    await sIntf.clk.nextPosedge;
    Simulator.injectAction(() {
      rIntf.arValid.put(1);
      rIntf.arId?.put(packet.id);
      rIntf.arAddr.put(packet.addr);
      rIntf.arLen?.put(packet.len);
      rIntf.arSize?.put(packet.size);
      rIntf.arBurst?.put(packet.burst);
      rIntf.arLock?.put(packet.lock);
      rIntf.arCache?.put(packet.cache);
      rIntf.arProt.put(packet.prot);
      rIntf.arQos?.put(packet.qos);
      rIntf.arRegion?.put(packet.region);
      rIntf.arUser?.put(packet.user);
      rIntf.rReady.put(1);
    });

    // need to hold the request until receiver is ready
    await sIntf.clk.nextPosedge;
    if (!rIntf.arReady.value.toBool()) {
      await rIntf.arReady.nextPosedge;
    }

    // now we can release the request
    Simulator.injectAction(() {
      rIntf.arValid.put(0);
    });

    // TODO: wait for the response to complete??
  }

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
    if (!wIntf.awReady.value.toBool()) {
      await wIntf.awReady.nextPosedge;
    }

    // now we can release the request
    Simulator.injectAction(() {
      wIntf.awValid.put(0);
    });

    // next send the data for the write
    for (var i = 0; i < packet.data.length; i++) {
      if (!wIntf.wReady.value.toBool()) {
        await wIntf.wReady.nextPosedge;
      }
      Simulator.injectAction(() {
        wIntf.wValid.put(1);
        wIntf.wData.put(packet.data[i]);
        wIntf.wStrb.put(packet.strobe[i]);
        wIntf.wLast.put(i == packet.data.length - 1 ? 1 : 0);
        wIntf.wUser?.put(packet.wUser);
      });
      await sIntf.clk.nextPosedge;
    }

    // now we can stop the write data
    Simulator.injectAction(() {
      wIntf.wValid.put(0);
    });

    // TODO: wait for the response to complete??
  }
}
