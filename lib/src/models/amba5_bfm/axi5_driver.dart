// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi5_driver.dart
// Drivers for AXI5 channel interfaces.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A driver for the ready signal on any [Axi5TransportInterface] interface.
class Axi5ReadyDriver extends Component {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// AXI5 Interface.
  final Axi5TransportInterface trans;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Creates a new [Axi5ReadyDriver].
  Axi5ReadyDriver({
    required Component parent,
    required this.sys,
    required this.trans,
    this.readyFrequency = 1.0,
    String name = 'axi5ReadyDriver',
  }) : super(
          name,
          parent,
        );

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      trans.ready!.put(0);
    });

    // wait for reset to complete before driving anything
    await sys.resetN.nextPosedge;

    while (!Simulator.simulationHasEnded) {
      final next = Test.random!.nextDouble() < readyFrequency;
      trans.ready!.put(next);
      await sys.clk.nextPosedge;
    }
  }
}

/// A driver for the [Axi5ArChannelInterface] interface.
///
/// Driving from the perspective of the Main agent.
class Axi5ArChannelDriver extends PendingClockedDriver<Axi5ArChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// AXI5 AR Interface.
  final Axi5ArChannelInterface ar;

  /// Creates a new [Axi5ArChannelDriver].
  Axi5ArChannelDriver({
    required Component parent,
    required this.sys,
    required this.ar,
    required super.sequencer,
    super.timeoutCycles = 500,
    super.dropDelayCycles = 30,
    String name = 'axi5ArChannelDriver',
  }) : super(
          name,
          parent,
          clk: sys.clk,
        );

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      ar.valid.put(0);
      ar.addr.put(0);
      ar.len?.put(0);
      ar.size?.put(0);
      ar.burst?.put(0);
      ar.qos?.put(0);
      ar.id?.put(0);
      ar.idUnq?.put(0);
      ar.prot?.put(0);
      ar.nse?.put(0);
      ar.priv?.put(0);
      ar.inst?.put(0);
      ar.pas?.put(0);
      ar.cache?.put(0);
      ar.region?.put(0);
      ar.mecId?.put(0);
      ar.trace?.put(0);
      ar.loop?.put(0);
      ar.mmuValid?.put(0);
      ar.mmuSecSid?.put(0);
      ar.mmuSid?.put(0);
      ar.mmuSsidV?.put(0);
      ar.mmuSsid?.put(0);
      ar.mmuAtSt?.put(0);
      ar.mmuFlow?.put(0);
      ar.mmuPasUnknown?.put(0);
      ar.mmuPm?.put(0);
      ar.nsaId?.put(0);
      ar.pbha?.put(0);
      ar.subSysId?.put(0);
      ar.actV?.put(0);
      ar.act?.put(0);
      ar.lock?.put(0);
      ar.atOp?.put(0);
      ar.mpam?.put(0);
      ar.tagOp?.put(0);
      ar.chunkEn?.put(0);
      ar.chunkV?.put(0);
      ar.chunkNum?.put(0);
      ar.chunkStrb?.put(0);
      ar.snoop?.put(0);
      ar.user?.put(0);
    });

    // wait for reset to complete before driving anything
    await sys.resetN.nextPosedge;

    while (!Simulator.simulationHasEnded) {
      if (pendingSeqItems.isNotEmpty) {
        await _drivePacket(pendingSeqItems.removeFirst());
      } else {
        await sys.clk.nextPosedge;
      }
    }
  }

  /// Drives a packet onto the interface.
  Future<void> _drivePacket(Axi5ArChannelPacket packet) async {
    logger.info('Driving AR packet.');
    await _driveRequestPacket(packet);
  }

  Future<void> _driveRequestPacket(Axi5ArChannelPacket packet) async {
    await sys.clk.nextPosedge;
    Simulator.injectAction(() {
      ar.valid.put(1);
      ar.addr.put(packet.request.addr);
      ar.len?.put(packet.request.len);
      ar.size?.put(packet.request.size);
      ar.burst?.put(packet.request.burst);
      ar.qos?.put(packet.request.qos);
      ar.id?.put(packet.id?.id);
      ar.idUnq?.put(packet.id?.idUnq);
      ar.prot?.put(packet.prot.prot);
      ar.nse?.put(packet.prot.nse);
      ar.priv?.put(packet.prot.priv);
      ar.inst?.put(packet.prot.inst);
      ar.pas?.put(packet.prot.pas);
      ar.cache?.put(packet.memAttr.cache);
      ar.region?.put(packet.memAttr.region);
      ar.mecId?.put(packet.memAttr.mecId);
      ar.trace?.put(packet.debug?.trace);
      ar.loop?.put(packet.debug?.loop);
      ar.mmuValid?.put(packet.mmu?.mmuValid);
      ar.mmuSecSid?.put(packet.mmu?.mmuSecSid);
      ar.mmuSid?.put(packet.mmu?.mmuSid);
      ar.mmuSsidV?.put(packet.mmu?.mmuSsidV);
      ar.mmuSsid?.put(packet.mmu?.mmuSsid);
      ar.mmuAtSt?.put(packet.mmu?.mmuAtSt);
      ar.mmuFlow?.put(packet.mmu?.mmuFlow);
      ar.mmuPasUnknown?.put(packet.mmu?.mmuPasUnknown);
      ar.mmuPm?.put(packet.mmu?.mmuPm);
      ar.nsaId?.put(packet.qual?.nsaId);
      ar.pbha?.put(packet.qual?.pbha);
      ar.subSysId?.put(packet.qual?.subSysId);
      ar.actV?.put(packet.qual?.actV);
      ar.act?.put(packet.qual?.act);
      ar.lock?.put(packet.atomic?.lock);
      ar.atOp?.put(packet.atomic?.atOp);
      ar.mpam?.put(packet.tag?.mpam);
      ar.tagOp?.put(packet.tag?.tagOp);
      ar.chunkEn?.put(packet.chunk?.chunkEn);
      ar.chunkV?.put(packet.chunk?.chunkV);
      ar.chunkNum?.put(packet.chunk?.chunkNum);
      ar.chunkStrb?.put(packet.chunk?.chunkStrb);
      ar.snoop?.put(packet.opcode?.snoop);
      ar.user?.put(packet.user?.user);
    });

    // TODO: handle credited!

    // need to hold the request until receiver is ready
    await sys.clk.nextPosedge;
    if (!ar.ready!.previousValue!.toBool()) {
      await ar.ready!.nextPosedge;
    }

    // now we can release the request
    // in the future, we may want to wait for the response to complete
    Simulator.injectAction(() {
      ar.valid.put(0);
      packet.complete();
    });
  }
}

/// A driver for the [Axi5AwChannelInterface] interface.
///
/// Driving from the perspective of the Main agent.
class Axi5AwChannelDriver extends PendingClockedDriver<Axi5AwChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// AXI5 AW Interface.
  final Axi5AwChannelInterface aw;

  /// Creates a new [Axi5AwChannelDriver].
  Axi5AwChannelDriver({
    required Component parent,
    required this.sys,
    required this.aw,
    required super.sequencer,
    super.timeoutCycles = 500,
    super.dropDelayCycles = 30,
    String name = 'axi5AwChannelDriver',
  }) : super(
          name,
          parent,
          clk: sys.clk,
        );

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      aw.valid.put(0);
      aw.addr.put(0);
      aw.len?.put(0);
      aw.size?.put(0);
      aw.burst?.put(0);
      aw.qos?.put(0);
      aw.id?.put(0);
      aw.idUnq?.put(0);
      aw.prot?.put(0);
      aw.nse?.put(0);
      aw.priv?.put(0);
      aw.inst?.put(0);
      aw.pas?.put(0);
      aw.cache?.put(0);
      aw.region?.put(0);
      aw.mecId?.put(0);
      aw.trace?.put(0);
      aw.loop?.put(0);
      aw.mmuValid?.put(0);
      aw.mmuSecSid?.put(0);
      aw.mmuSid?.put(0);
      aw.mmuSsidV?.put(0);
      aw.mmuSsid?.put(0);
      aw.mmuAtSt?.put(0);
      aw.mmuFlow?.put(0);
      aw.mmuPasUnknown?.put(0);
      aw.mmuPm?.put(0);
      aw.nsaId?.put(0);
      aw.pbha?.put(0);
      aw.subSysId?.put(0);
      aw.actV?.put(0);
      aw.act?.put(0);
      aw.lock?.put(0);
      aw.atOp?.put(0);
      aw.mpam?.put(0);
      aw.tagOp?.put(0);
      aw.snoop?.put(0);
      aw.user?.put(0);
      aw.domain?.put(0);
      aw.stashNid?.put(0);
      aw.stashNidEn?.put(0);
      aw.stashLPid?.put(0);
      aw.stashLPidEn?.put(0);
      aw.cmo?.put(0);
    });

    // wait for reset to complete before driving anything
    await sys.resetN.nextPosedge;

    while (!Simulator.simulationHasEnded) {
      if (pendingSeqItems.isNotEmpty) {
        await _drivePacket(pendingSeqItems.removeFirst());
      } else {
        await sys.clk.nextPosedge;
      }
    }
  }

  /// Drives a packet onto the interface.
  Future<void> _drivePacket(Axi5AwChannelPacket packet) async {
    logger.info('Driving AW packet.');
    await _driveRequestPacket(packet);
  }

  Future<void> _driveRequestPacket(Axi5AwChannelPacket packet) async {
    await sys.clk.nextPosedge;
    Simulator.injectAction(() {
      aw.valid.put(1);
      aw.addr.put(packet.request.addr);
      aw.len?.put(packet.request.len);
      aw.size?.put(packet.request.size);
      aw.burst?.put(packet.request.burst);
      aw.qos?.put(packet.request.qos);
      aw.id?.put(packet.id?.id);
      aw.idUnq?.put(packet.id?.idUnq);
      aw.prot?.put(packet.prot.prot);
      aw.nse?.put(packet.prot.nse);
      aw.priv?.put(packet.prot.priv);
      aw.inst?.put(packet.prot.inst);
      aw.pas?.put(packet.prot.pas);
      aw.cache?.put(packet.memAttr.cache);
      aw.region?.put(packet.memAttr.region);
      aw.mecId?.put(packet.memAttr.mecId);
      aw.trace?.put(packet.debug?.trace);
      aw.loop?.put(packet.debug?.loop);
      aw.mmuValid?.put(packet.mmu?.mmuValid);
      aw.mmuSecSid?.put(packet.mmu?.mmuSecSid);
      aw.mmuSid?.put(packet.mmu?.mmuSid);
      aw.mmuSsidV?.put(packet.mmu?.mmuSsidV);
      aw.mmuSsid?.put(packet.mmu?.mmuSsid);
      aw.mmuAtSt?.put(packet.mmu?.mmuAtSt);
      aw.mmuFlow?.put(packet.mmu?.mmuFlow);
      aw.mmuPasUnknown?.put(packet.mmu?.mmuPasUnknown);
      aw.mmuPm?.put(packet.mmu?.mmuPm);
      aw.nsaId?.put(packet.qual?.nsaId);
      aw.pbha?.put(packet.qual?.pbha);
      aw.subSysId?.put(packet.qual?.subSysId);
      aw.actV?.put(packet.qual?.actV);
      aw.act?.put(packet.qual?.act);
      aw.lock?.put(packet.atomic?.lock);
      aw.atOp?.put(packet.atomic?.atOp);
      aw.mpam?.put(packet.tag?.mpam);
      aw.tagOp?.put(packet.tag?.tagOp);
      aw.snoop?.put(packet.opcode?.snoop);
      aw.user?.put(packet.user?.user);
      aw.domain?.put(packet.stash?.domain);
      aw.stashNid?.put(packet.stash?.stashNid);
      aw.stashNidEn?.put(packet.stash?.stashNidEn);
      aw.stashLPid?.put(packet.stash?.stashLPid);
      aw.stashLPidEn?.put(packet.stash?.stashLPidEn);
      aw.cmo?.put(packet.stash?.cmo);
    });

    // TODO: handle credited!

    // need to hold the request until receiver is ready
    await sys.clk.nextPosedge;
    if (!aw.ready!.previousValue!.toBool()) {
      await aw.ready!.nextPosedge;
    }

    // now we can release the request
    // in the future, we may want to wait for the response to complete
    Simulator.injectAction(() {
      aw.valid.put(0);
      packet.complete();
    });
  }
}

// TODO: handle multi beat data return

/// A driver for the [Axi5RChannelInterface] interface.
///
/// Driving from the perspective of the Main agent.
class Axi5RChannelDriver extends PendingClockedDriver<Axi5RChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// AXI5 R Interface.
  final Axi5RChannelInterface r;

  /// Creates a new [Axi5RChannelDriver].
  Axi5RChannelDriver({
    required Component parent,
    required this.sys,
    required this.r,
    required super.sequencer,
    super.timeoutCycles = 500,
    super.dropDelayCycles = 30,
    String name = 'axi5RChannelDriver',
  }) : super(
          name,
          parent,
          clk: sys.clk,
        );

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      r.valid.put(0);
      r.data.put(0);
      r.last?.put(0);
      r.strb?.put(0);
      r.poison?.put(0);
      r.id?.put(0);
      r.idUnq?.put(0);
      r.tag?.put(0);
      r.tagUpdate?.put(0);
      r.tagMatch?.put(0);
      r.comp?.put(0);
      r.persist?.put(0);
      r.trace?.put(0);
      r.loop?.put(0);
      r.resp?.put(0);
      r.busy?.put(0);
      r.chunkEn?.put(0);
      r.chunkV?.put(0);
      r.chunkNum?.put(0);
      r.chunkStrb?.put(0);
      r.user?.put(0);
    });

    // wait for reset to complete before driving anything
    await sys.resetN.nextPosedge;

    while (!Simulator.simulationHasEnded) {
      if (pendingSeqItems.isNotEmpty) {
        await _drivePacket(pendingSeqItems.removeFirst());
      } else {
        await sys.clk.nextPosedge;
      }
    }
  }

  /// Drives a packet onto the interface.
  Future<void> _drivePacket(Axi5RChannelPacket packet) async {
    logger.info('Driving R packet.');
    await _driveRequestPacket(packet);
  }

  Future<void> _driveRequestPacket(Axi5RChannelPacket packet) async {
    await sys.clk.nextPosedge;
    Simulator.injectAction(() {
      r.valid.put(1);
      r.data.put(packet.data.isNotEmpty ? packet.data[0].data : null);
      r.last?.put(packet.data.isNotEmpty ? packet.data[0].last : null);
      r.strb?.put(packet.data.isNotEmpty ? packet.data[0].strb : null);
      r.poison?.put(packet.data.isNotEmpty ? packet.data[0].poison : null);
      r.id?.put(packet.id?.id);
      r.idUnq?.put(packet.id?.idUnq);
      r.tag?.put(packet.tag?.tag);
      r.tagUpdate?.put(packet.tag?.tagUpdate);
      r.tagMatch?.put(packet.tag?.tagMatch);
      r.comp?.put(packet.tag?.comp);
      r.persist?.put(packet.tag?.persist);
      r.trace?.put(packet.debug?.trace);
      r.loop?.put(packet.debug?.loop);
      r.resp?.put(packet.response?.resp);
      r.busy?.put(packet.response?.busy);
      r.chunkEn?.put(packet.chunk?.chunkEn);
      r.chunkV?.put(packet.chunk?.chunkV);
      r.chunkNum?.put(packet.chunk?.chunkNum);
      r.chunkStrb?.put(packet.chunk?.chunkStrb);
      r.user?.put(packet.user?.user);
    });

    // TODO: handle credited!

    // need to hold the request until receiver is ready
    await sys.clk.nextPosedge;
    if (!r.ready!.previousValue!.toBool()) {
      await r.ready!.nextPosedge;
    }

    // now we can release the request
    // in the future, we may want to wait for the response to complete
    Simulator.injectAction(() {
      r.valid.put(0);
      packet.complete();
    });
  }
}

// TODO: handle multi beat data return

/// A driver for the [Axi5WChannelInterface] interface.
///
/// Driving from the perspective of the Main agent.
class Axi5WChannelDriver extends PendingClockedDriver<Axi5WChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// AXI5 W Interface.
  final Axi5WChannelInterface w;

  /// Creates a new [Axi5WChannelDriver].
  Axi5WChannelDriver({
    required Component parent,
    required this.sys,
    required this.w,
    required super.sequencer,
    super.timeoutCycles = 500,
    super.dropDelayCycles = 30,
    String name = 'axi5WChannelDriver',
  }) : super(
          name,
          parent,
          clk: sys.clk,
        );

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      w.valid.put(0);
      w.data.put(0);
      w.last?.put(0);
      w.strb?.put(0);
      w.poison?.put(0);
      w.tag?.put(0);
      w.tagUpdate?.put(0);
      w.tagMatch?.put(0);
      w.trace?.put(0);
      w.loop?.put(0);
      w.user?.put(0);
    });

    // wait for reset to complete before driving anything
    await sys.resetN.nextPosedge;

    while (!Simulator.simulationHasEnded) {
      if (pendingSeqItems.isNotEmpty) {
        await _drivePacket(pendingSeqItems.removeFirst());
      } else {
        await sys.clk.nextPosedge;
      }
    }
  }

  /// Drives a packet onto the interface.
  Future<void> _drivePacket(Axi5WChannelPacket packet) async {
    logger.info('Driving W packet.');
    await _driveRequestPacket(packet);
  }

  Future<void> _driveRequestPacket(Axi5WChannelPacket packet) async {
    await sys.clk.nextPosedge;
    Simulator.injectAction(() {
      w.valid.put(1);
      w.data.put(packet.data.isNotEmpty ? packet.data[0].data : null);
      w.last?.put(packet.data.isNotEmpty ? packet.data[0].last : null);
      w.strb?.put(packet.data.isNotEmpty ? packet.data[0].strb : null);
      w.poison?.put(packet.data.isNotEmpty ? packet.data[0].poison : null);
      w.tag?.put(packet.tag?.tag);
      w.tagUpdate?.put(packet.tag?.tagUpdate);
      w.tagMatch?.put(packet.tag?.tagMatch);
      w.trace?.put(packet.debug?.trace);
      w.loop?.put(packet.debug?.loop);
      w.user?.put(packet.user?.user);
    });

    // TODO: handle credited!

    // need to hold the request until receiver is ready
    await sys.clk.nextPosedge;
    if (!w.ready!.previousValue!.toBool()) {
      await w.ready!.nextPosedge;
    }

    // now we can release the request
    // in the future, we may want to wait for the response to complete
    Simulator.injectAction(() {
      w.valid.put(0);
      packet.complete();
    });
  }
}

/// A driver for the [Axi5BChannelInterface] interface.
///
/// Driving from the perspective of the Main agent.
class Axi5BChannelDriver extends PendingClockedDriver<Axi5BChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// AXI5 B Interface.
  final Axi5BChannelInterface b;

  /// Creates a new [Axi5BChannelDriver].
  Axi5BChannelDriver({
    required Component parent,
    required this.sys,
    required this.b,
    required super.sequencer,
    super.timeoutCycles = 500,
    super.dropDelayCycles = 30,
    String name = 'axi5BChannelDriver',
  }) : super(
          name,
          parent,
          clk: sys.clk,
        );

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      b.valid.put(0);
      b.id?.put(0);
      b.idUnq?.put(0);
      b.tag?.put(0);
      b.tagUpdate?.put(0);
      b.tagMatch?.put(0);
      b.comp?.put(0);
      b.persist?.put(0);
      b.trace?.put(0);
      b.loop?.put(0);
      b.resp?.put(0);
      b.busy?.put(0);
      b.user?.put(0);
    });

    // wait for reset to complete before driving anything
    await sys.resetN.nextPosedge;

    while (!Simulator.simulationHasEnded) {
      if (pendingSeqItems.isNotEmpty) {
        await _drivePacket(pendingSeqItems.removeFirst());
      } else {
        await sys.clk.nextPosedge;
      }
    }
  }

  /// Drives a packet onto the interface.
  Future<void> _drivePacket(Axi5BChannelPacket packet) async {
    logger.info('Driving B packet.');
    await _driveResponsePacket(packet);
  }

  Future<void> _driveResponsePacket(Axi5BChannelPacket packet) async {
    await sys.clk.nextPosedge;
    Simulator.injectAction(() {
      b.valid.put(1);
      b.id?.put(packet.id?.id);
      b.idUnq?.put(packet.id?.idUnq);
      b.tag?.put(packet.tag?.tag);
      b.tagUpdate?.put(packet.tag?.tagUpdate);
      b.tagMatch?.put(packet.tag?.tagMatch);
      b.comp?.put(packet.tag?.comp);
      b.persist?.put(packet.tag?.persist);
      b.trace?.put(packet.debug?.trace);
      b.loop?.put(packet.debug?.loop);
      b.resp!.put(packet.response.resp ?? 0);
      b.busy!.put(packet.response.busy ?? 0);
      b.user?.put(packet.user?.user);
    });

    // TODO: handle credited!

    // need to hold the response until receiver is ready
    await sys.clk.nextPosedge;
    if (!b.ready!.previousValue!.toBool()) {
      await b.ready!.nextPosedge;
    }

    // now we can release the response
    // in the future, we may want to wait for the transaction to complete
    Simulator.injectAction(() {
      b.valid.put(0);
      packet.complete();
    });
  }
}

/// A driver for the [Axi5AcChannelInterface] interface.
///
/// Driving from the perspective of the Main agent.
class Axi5AcChannelDriver extends PendingClockedDriver<Axi5AcChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// AXI5 AC Interface.
  final Axi5AcChannelInterface ac;

  /// Creates a new [Axi5AcChannelDriver].
  Axi5AcChannelDriver({
    required Component parent,
    required this.sys,
    required this.ac,
    required super.sequencer,
    super.timeoutCycles = 500,
    super.dropDelayCycles = 30,
    String name = 'axi5AcChannelDriver',
  }) : super(
          name,
          parent,
          clk: sys.clk,
        );

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      ac.valid.put(0);
      ac.addr?.put(0);
      ac.vmidExt?.put(0);
      ac.trace?.put(0);
      ac.loop?.put(0);
    });

    // wait for reset to complete before driving anything
    await sys.resetN.nextPosedge;

    while (!Simulator.simulationHasEnded) {
      if (pendingSeqItems.isNotEmpty) {
        await _drivePacket(pendingSeqItems.removeFirst());
      } else {
        await sys.clk.nextPosedge;
      }
    }
  }

  /// Drives a packet onto the interface.
  Future<void> _drivePacket(Axi5AcChannelPacket packet) async {
    logger.info('Driving AC packet.');
    await _driveAcPacket(packet);
  }

  Future<void> _driveAcPacket(Axi5AcChannelPacket packet) async {
    await sys.clk.nextPosedge;
    Simulator.injectAction(() {
      ac.valid.put(1);
      ac.addr?.put(packet.addr);
      ac.vmidExt?.put(packet.vmidExt);
      ac.trace?.put(packet.debug?.trace);
      ac.loop?.put(packet.debug?.loop);
    });

    // need to hold the request until receiver is ready
    await sys.clk.nextPosedge;
    if (!ac.ready!.previousValue!.toBool()) {
      await ac.ready!.nextPosedge;
    }

    // now we can release the request
    Simulator.injectAction(() {
      ac.valid.put(0);
      packet.complete();
    });
  }
}

/// A driver for the [Axi5CrChannelInterface] interface.
///
/// Driving from the perspective of the Main agent.
class Axi5CrChannelDriver extends PendingClockedDriver<Axi5CrChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// AXI5 CR Interface.
  final Axi5CrChannelInterface cr;

  /// Creates a new [Axi5CrChannelDriver].
  Axi5CrChannelDriver({
    required Component parent,
    required this.sys,
    required this.cr,
    required super.sequencer,
    super.timeoutCycles = 500,
    super.dropDelayCycles = 30,
    String name = 'axi5CrChannelDriver',
  }) : super(
          name,
          parent,
          clk: sys.clk,
        );

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      cr.valid.put(0);
      cr.trace?.put(0);
      cr.loop?.put(0);
    });

    // wait for reset to complete before driving anything
    await sys.resetN.nextPosedge;

    while (!Simulator.simulationHasEnded) {
      if (pendingSeqItems.isNotEmpty) {
        await _drivePacket(pendingSeqItems.removeFirst());
      } else {
        await sys.clk.nextPosedge;
      }
    }
  }

  /// Drives a packet onto the interface.
  Future<void> _drivePacket(Axi5CrChannelPacket packet) async {
    logger.info('Driving CR packet.');
    await _driveCrPacket(packet);
  }

  Future<void> _driveCrPacket(Axi5CrChannelPacket packet) async {
    await sys.clk.nextPosedge;
    Simulator.injectAction(() {
      cr.valid.put(1);
      cr.trace?.put(packet.debug?.trace);
      cr.loop?.put(packet.debug?.loop);
    });

    // need to hold the request until receiver is ready
    await sys.clk.nextPosedge;
    if (!cr.ready!.previousValue!.toBool()) {
      await cr.ready!.nextPosedge;
    }

    // now we can release the request
    Simulator.injectAction(() {
      cr.valid.put(0);
      packet.complete();
    });
  }
}
