// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_request_driver.dart
// A driver for AXI4 requests.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/interfaces.dart';
import 'package:rohd_hcl/src/models/amba/amba4_bfm/axi4_bfm.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A driver for the [Axi4RequestChannelInterface] interface.
///
/// Driving from the perspective of the Main agent.
class Axi4RequestChannelDriver extends PendingClockedDriver<Axi4RequestPacket> {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// AXI4 Request Interface.
  final Axi4RequestChannelInterface rIntf;

  /// Creates a new [Axi4RequestChannelDriver].
  Axi4RequestChannelDriver({
    required Component parent,
    required this.sIntf,
    required this.rIntf,
    required super.sequencer,
    super.timeoutCycles = 500,
    super.dropDelayCycles = 30,
    String name = 'axi4RequestChannelDriver',
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
      rIntf.addr.put(0);
      rIntf.len?.put(0);
      rIntf.size?.put(0);
      rIntf.burst?.put(0);
      rIntf.lock?.put(0);
      rIntf.cache?.put(0);
      rIntf.prot.put(0);
      rIntf.qos?.put(0);
      rIntf.region?.put(0);
      rIntf.user?.put(0);
      if (rIntf is Ace4RequestChannel) {
        (rIntf as Ace4RequestChannel).domain?.put(0);
        (rIntf as Ace4RequestChannel).bar?.put(0);
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
  Future<void> _drivePacket(Axi4RequestPacket packet) async {
    logger.info('Driving request packet.');
    await _driveRequestPacket(packet);
  }

  Future<void> _driveRequestPacket(Axi4RequestPacket packet) async {
    await sIntf.clk.nextPosedge;
    Simulator.injectAction(() {
      rIntf.valid.put(1);
      rIntf.id?.put(packet.id);
      rIntf.addr.put(packet.addr);
      rIntf.len?.put(packet.len);
      rIntf.size?.put(packet.size);
      rIntf.burst?.put(packet.burst);
      rIntf.lock?.put(packet.lock);
      rIntf.cache?.put(packet.cache);
      rIntf.prot.put(packet.prot);
      rIntf.qos?.put(packet.qos);
      rIntf.region?.put(packet.region);
      rIntf.user?.put(packet.user);
      if (rIntf is Ace4RequestChannel) {
        (rIntf as Ace4RequestChannel).domain?.put(packet.domain);
        (rIntf as Ace4RequestChannel).bar?.put(packet.bar);
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

/// A driver for the ready signal on any [Axi4ChannelInterface] interface.
class Axi4ReadyDriver extends Component {
  /// AXI4 System Interface.
  final Axi4SystemInterface sys;

  /// AXI4 Interface.
  final Axi4ChannelInterface chan;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// ready disabled
  bool _disabled = false;

  /// Creates a new [Axi4ReadyDriver].
  Axi4ReadyDriver({
    required Component parent,
    required this.sys,
    required this.chan,
    this.readyFrequency = 1.0,
    String name = 'axi4ReadyDriver',
  }) : super(
          name,
          parent,
        );

  /// mechanism to turn off the ready.
  void disable() => _disabled = true;

  /// mechanism to turn on the ready.
  void enable() => _disabled = false;

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      chan.ready.put(0);
    });

    // wait for reset to complete before driving anything
    await sys.resetN.nextPosedge;

    while (!Simulator.simulationHasEnded) {
      if (_disabled) {
        chan.ready.put(0);
      } else {
        final next = Test.random!.nextDouble() < readyFrequency;
        chan.ready.put(next);
      }

      await sys.clk.nextPosedge;
    }
  }
}
