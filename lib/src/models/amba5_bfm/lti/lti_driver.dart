// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// lti_driver.dart
// Drivers for LTI channel interfaces.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Driver for the LTI LA channel interface.
class LtiLaChannelDriver extends PendingClockedDriver<LtiLaChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// LTI LA Interface.
  final LtiLaChannelInterface la;

  /// Creates a new [LtiLaChannelDriver].
  LtiLaChannelDriver({
    required Component parent,
    required this.sys,
    required this.la,
    required super.sequencer,
    super.timeoutCycles = 500,
    super.dropDelayCycles = 30,
    String name = 'ltiLaChannelDriver',
  }) : super(
          name,
          parent,
          clk: sys.clk,
        );

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      la.valid.put(0);
      la.addr.put(0);
      la.trans.put(0);
      la.attr.put(0);
      la.ogv.put(0);
      la.user?.put(0);
      la.id?.put(0);
      la.nse?.put(0);
      la.priv?.put(0);
      la.inst?.put(0);
      la.pas?.put(0);
      la.og?.put(0);
      la.tlBlock?.put(0);
      la.ident?.put(0);
      la.mmuValid?.put(0);
      la.mmuSecSid?.put(0);
      la.mmuSid?.put(0);
      la.mmuSsidV?.put(0);
      la.mmuSsid?.put(0);
      la.mmuAtSt?.put(0);
      la.mmuFlow?.put(0);
      la.mmuPasUnknown?.put(0);
      la.mmuPm?.put(0);
      la.loop?.put(0);
      la.vc?.put(0);
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
  Future<void> _drivePacket(LtiLaChannelPacket packet) async {
    logger.info('Driving LA packet.');
    await _driveRequestPacket(packet);
  }

  Future<void> _driveRequestPacket(LtiLaChannelPacket packet) async {
    await sys.clk.nextPosedge;
    Simulator.injectAction(() {
      la.valid.put(1);
      la.addr.put(packet.addr);
      la.trans.put(packet.trans);
      la.attr.put(packet.attr);
      la.ogv.put(packet.ogV);
      la.user?.put(packet.user?.user ?? 0);
      la.id?.put(packet.id?.id ?? 0);
      la.nse?.put(packet.prot?.nse ?? 0);
      la.priv?.put(packet.prot?.priv ?? 0);
      la.inst?.put(packet.prot?.inst ?? 0);
      la.pas?.put(packet.prot?.pas ?? 0);
      la.loop?.put(packet.debug?.loop ?? 0);
      la.og?.put(packet.og ?? 0);
      la.tlBlock?.put(packet.tlBlock ?? 0);
      la.ident?.put(packet.ident ?? 0);
      la.mmuValid?.put(packet.mmu?.mmuValid ?? 0);
      la.mmuSecSid?.put(packet.mmu?.mmuSecSid ?? 0);
      la.mmuSid?.put(packet.mmu?.mmuSid ?? 0);
      la.mmuSsidV?.put(packet.mmu?.mmuSsidV ?? 0);
      la.mmuSsid?.put(packet.mmu?.mmuSsid ?? 0);
      la.mmuAtSt?.put(packet.mmu?.mmuAtSt ?? 0);
      la.mmuFlow?.put(packet.mmu?.mmuFlow ?? 0);
      la.mmuPasUnknown?.put(packet.mmu?.mmuPasUnknown ?? 0);
      la.mmuPm?.put(packet.mmu?.mmuPm ?? 0);
      la.vc?.put(packet.vc);
    });

    // TODO: anything to wait on???
    await sys.clk.nextPosedge;

    // now we can release the request
    // in the future, we may want to wait for the response to complete
    Simulator.injectAction(() {
      la.valid.put(0);
      packet.complete();
    });
  }
}

/// Driver for the LTI LR channel interface.
class LtiLrChannelDriver extends PendingClockedDriver<LtiLrChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// LTI LR Interface.
  final LtiLrChannelInterface lr;

  /// Creates a new [LtiLrChannelDriver].
  LtiLrChannelDriver({
    required Component parent,
    required this.sys,
    required this.lr,
    required super.sequencer,
    super.timeoutCycles = 500,
    super.dropDelayCycles = 30,
    String name = 'ltiLrChannelDriver',
  }) : super(
          name,
          parent,
          clk: sys.clk,
        );

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      lr.valid.put(0);
      lr.addr.put(0);
      lr.hwAttr.put(0);
      lr.attr.put(0);
      lr.user?.put(0);
      lr.id?.put(0);
      lr.nse?.put(0);
      lr.priv?.put(0);
      lr.inst?.put(0);
      lr.pas?.put(0);
      lr.trace?.put(0);
      lr.loop?.put(0);
      lr.resp?.put(0);
      lr.busy?.put(0);
      lr.mecId?.put(0);
      lr.mpam?.put(0);
      lr.ctag.put(0);
      lr.size.put(0);
      lr.vc?.put(0);
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
  Future<void> _drivePacket(LtiLrChannelPacket packet) async {
    logger.info('Driving LR packet.');
    await _driveRequestPacket(packet);
  }

  Future<void> _driveRequestPacket(LtiLrChannelPacket packet) async {
    await sys.clk.nextPosedge;
    Simulator.injectAction(() {
      lr.valid.put(1);
      lr.addr.put(packet.addr);
      lr.hwAttr.put(packet.hwattr);
      lr.attr.put(packet.attr);
      lr.user?.put(packet.user?.user ?? 0);
      lr.id?.put(packet.id?.id ?? 0);
      lr.nse?.put(packet.prot?.nse ?? 0);
      lr.priv?.put(packet.prot?.priv ?? 0);
      lr.inst?.put(packet.prot?.inst ?? 0);
      lr.pas?.put(packet.prot?.pas ?? 0);
      lr.trace?.put(packet.debug?.trace ?? 0);
      lr.loop?.put(packet.debug?.loop ?? 0);
      lr.resp?.put(packet.response?.resp ?? 0);
      lr.busy?.put(packet.response?.busy ?? 0);
      lr.mecId?.put(packet.mecId ?? 0);
      lr.mpam?.put(packet.mpam ?? 0);
      lr.ctag.put(packet.ctag ?? 0);
      lr.size.put(packet.size);
      lr.vc?.put(packet.vc);
    });

    // TODO: anything to wait on???
    await sys.clk.nextPosedge;

    Simulator.injectAction(() {
      lr.valid.put(0);
      packet.complete();
    });
  }
}

/// Driver for the LTI LC channel interface.
class LtiLcChannelDriver extends PendingClockedDriver<LtiLcChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// LTI LC Interface.
  final LtiLcChannelInterface lc;

  /// Creates a new [LtiLcChannelDriver].
  LtiLcChannelDriver({
    required Component parent,
    required this.sys,
    required this.lc,
    required super.sequencer,
    super.timeoutCycles = 500,
    super.dropDelayCycles = 30,
    String name = 'ltiLcChannelDriver',
  }) : super(
          name,
          parent,
          clk: sys.clk,
        );

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      lc.valid.put(0);
      lc.user?.put(0);
      lc.ctag.put(0);
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
  Future<void> _drivePacket(LtiLcChannelPacket packet) async {
    logger.info('Driving LC packet.');
    await _driveRequestPacket(packet);
  }

  Future<void> _driveRequestPacket(LtiLcChannelPacket packet) async {
    await sys.clk.nextPosedge;
    Simulator.injectAction(() {
      lc.valid.put(1);
      lc.user?.put(packet.user?.user ?? 0);
      lc.ctag.put(packet.tag);
    });

    // TODO: anything to wait on???
    await sys.clk.nextPosedge;

    Simulator.injectAction(() {
      lc.valid.put(0);
      packet.complete();
    });
  }
}

/// Driver for the LTI LT channel interface.
class LtiLtChannelDriver extends PendingClockedDriver<LtiLtChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// LTI LT Interface.
  final LtiLtChannelInterface lt;

  /// Creates a new [LtiLtChannelDriver].
  LtiLtChannelDriver({
    required Component parent,
    required this.sys,
    required this.lt,
    required super.sequencer,
    super.timeoutCycles = 500,
    super.dropDelayCycles = 30,
    String name = 'ltiLtChannelDriver',
  }) : super(
          name,
          parent,
          clk: sys.clk,
        );

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      lt.valid.put(0);
      lt.user?.put(0);
      lt.ctag.put(0);
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
  Future<void> _drivePacket(LtiLtChannelPacket packet) async {
    logger.info('Driving LT packet.');
    await _driveRequestPacket(packet);
  }

  Future<void> _driveRequestPacket(LtiLtChannelPacket packet) async {
    await sys.clk.nextPosedge;
    Simulator.injectAction(() {
      lt.valid.put(1);
      lt.user?.put(packet.user?.user ?? 0);
      lt.ctag.put(packet.tag);
    });

    // TODO: anything to wait on???
    await sys.clk.nextPosedge;

    Simulator.injectAction(() {
      lt.valid.put(0);
      packet.complete();
    });
  }
}

/// A driver for credit returns on any [LtiTransportInterface] interface.
class LtiCreditDriver extends PendingClockedDriver<LtiCreditPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// LTI Interface.
  final LtiTransportInterface trans;

  /// Creates a new [LtiCreditDriver].
  LtiCreditDriver({
    required Component parent,
    required this.sys,
    required this.trans,
    required super.sequencer,
    super.timeoutCycles = 500,
    super.dropDelayCycles = 30,
    String name = 'ltiCreditDriver',
  }) : super(
          name,
          parent,
          clk: sys.clk,
        );

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      trans.credit!.put(0);
    });

    // wait for reset to complete before driving anything
    await sys.resetN.nextPosedge;

    // push the credit value onto the interface for exactly 1 cycle
    while (!Simulator.simulationHasEnded) {
      if (pendingSeqItems.isNotEmpty) {
        final crd = pendingSeqItems.removeFirst();
        await sys.clk.nextPosedge;
        Simulator.injectAction(() {
          trans.credit!.put(crd.credit);
        });
        await sys.clk.nextPosedge;
        Simulator.injectAction(() {
          trans.credit!.put(0);
        });
      } else {
        await sys.clk.nextPosedge;
      }
    }
  }
}
