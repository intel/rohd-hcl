// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// lti_monitor.dart
// Monitors that watch the LTI interfaces.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Monitor for credits on any LTI channel.
class LtiCreditMonitor extends Monitor<LtiCreditPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// LTI Interface.
  final LtiTransportInterface trans;

  /// Creates a new [LtiCreditMonitor] on [trans].
  LtiCreditMonitor({
    required this.sys,
    required this.trans,
    required Component parent,
    String name = 'ltiCreditMonitor',
  }) : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    await sys.resetN.nextPosedge;

    sys.clk.posedge.listen((event) {
      if ((trans.credit?.previousValue!.isValid ?? false) &&
          (trans.credit?.previousValue!.toInt() ?? 0) > 0) {
        add(LtiCreditPacket(credit: trans.credit?.previousValue!.toInt() ?? 0));
      }
    });
  }
}

/// Monitor for the LTI LA channel interface.
class LtiLaChannelMonitor extends Monitor<LtiLaChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// LTI LA Interface.
  final LtiLaChannelInterface la;

  /// Creates a new [LtiLaChannelMonitor] on [la].
  LtiLaChannelMonitor(
      {required this.sys,
      required this.la,
      required Component parent,
      String name = 'ltiLaChannelMonitor'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    await sys.resetN.nextPosedge;

    // TODO: anything to do with crediting here??

    sys.clk.posedge.listen((event) {
      if (la.valid.previousValue!.isValid && la.valid.previousValue!.toBool()) {
        add(LtiLaChannelPacket(
          addr: la.addr.previousValue!.toInt(),
          trans: la.trans.previousValue!.toInt(),
          attr: la.attr.previousValue!.toInt(),
          user: la.userMixInEnable
              ? Axi5UserSignalsStruct(user: la.user?.previousValue!.toInt())
              : null,
          id: la.idMixInEnable
              ? Axi5IdSignalsStruct(
                  id: la.id?.previousValue!.toInt(),
                )
              : null,
          prot: Axi5ProtSignalsStruct(
            nse: la.nse?.previousValue!.toBool(),
            priv: la.priv?.previousValue!.toBool(),
            inst: la.inst?.previousValue!.toBool(),
            pas: la.pas?.previousValue!.toInt(),
          ),
          mmu: la.mmuMixInEnable
              ? Axi5MmuSignalsStruct(
                  mmuValid: la.mmuValid!.previousValue!.toBool(),
                  mmuSecSid: la.mmuSecSid?.previousValue!.toInt(),
                  mmuSid: la.mmuSid?.previousValue!.toInt(),
                  mmuSsidV: la.mmuSsidV?.previousValue!.toBool(),
                  mmuSsid: la.mmuSsid?.previousValue!.toInt(),
                  mmuAtSt: la.mmuAtSt?.previousValue!.toBool(),
                  mmuFlow: la.mmuFlow?.previousValue!.toInt(),
                  mmuPasUnknown: la.mmuPasUnknown?.previousValue!.toBool(),
                  mmuPm: la.mmuPm?.previousValue!.toBool(),
                )
              : null,
          debug: la.debugMixInEnable
              ? Axi5DebugSignalsStruct(
                  loop: la.loop?.previousValue!.toInt(),
                )
              : null,
          ogV: la.ogv.previousValue!.toBool(),
          og: la.og?.previousValue!.toInt(),
          tlBlock: la.tlBlock?.previousValue!.toInt(),
          ident: la.ident?.previousValue!.toInt(),
          vc: la.vc?.previousValue!.toInt() ?? 0,
        ));
      }
    });
  }
}

/// Monitor for the LTI LR channel interface.
class LtiLrChannelMonitor extends Monitor<LtiLrChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// LTI LR Interface.
  final LtiLrChannelInterface lr;

  /// Creates a new [LtiLrChannelMonitor] on [lr].
  LtiLrChannelMonitor({
    required this.sys,
    required this.lr,
    required Component parent,
    String name = 'ltiLrChannelMonitor',
  }) : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    await sys.resetN.nextPosedge;

    // TODO: anything to do with crediting here??

    sys.clk.posedge.listen((event) {
      if (lr.valid.previousValue!.isValid && lr.valid.previousValue!.toBool()) {
        add(LtiLrChannelPacket(
          addr: lr.addr.previousValue!.toInt(),
          hwattr: lr.hwAttr.previousValue!.toInt(),
          attr: lr.attr.previousValue!.toInt(),
          user: lr.userMixInEnable
              ? Axi5UserSignalsStruct(user: lr.user?.previousValue!.toInt())
              : null,
          id: lr.idMixInEnable
              ? Axi5IdSignalsStruct(
                  id: lr.id?.previousValue!.toInt(),
                )
              : null,
          prot: Axi5ProtSignalsStruct(
            nse: lr.nse?.previousValue!.toBool(),
            priv: lr.priv?.previousValue!.toBool(),
            inst: lr.inst?.previousValue!.toBool(),
            pas: lr.pas?.previousValue!.toInt(),
          ),
          debug: lr.debugMixInEnable
              ? Axi5DebugSignalsStruct(
                  loop: lr.loop?.previousValue!.toInt(),
                )
              : null,
          response: Axi5ResponseSignalsStruct(
            resp: lr.resp?.previousValue!.toInt(),
          ),
          mecId: lr.mecId?.previousValue!.toInt(),
          mpam: lr.mpam?.previousValue!.toInt(),
          ctag: lr.ctag.previousValue!.toInt(),
          size: lr.size.previousValue!.toInt(),
          vc: lr.vc?.previousValue!.toInt() ?? 0,
        ));
      }
    });
  }
}

/// Monitor for the LTI LC channel interface.
class LtiLcChannelMonitor extends Monitor<LtiLcChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// LTI LC Interface.
  final LtiLcChannelInterface lc;

  /// Creates a new [LtiLcChannelMonitor] on [lc].
  LtiLcChannelMonitor({
    required this.sys,
    required this.lc,
    required Component parent,
    String name = 'ltiLcChannelMonitor',
  }) : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    await sys.resetN.nextPosedge;

    // TODO: anything to do with crediting here??

    sys.clk.posedge.listen((event) {
      if (lc.valid.previousValue!.isValid && lc.valid.previousValue!.toBool()) {
        add(LtiLcChannelPacket(
          user: lc.userMixInEnable
              ? Axi5UserSignalsStruct(user: lc.user?.previousValue!.toInt())
              : null,
          tag: lc.ctag.previousValue!.toInt(),
        ));
      }
    });
  }
}

/// Monitor for the LTI LT channel interface.
class LtiLtChannelMonitor extends Monitor<LtiLtChannelPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// LTI LT Interface.
  final LtiLtChannelInterface lt;

  /// Creates a new [LtiLtChannelMonitor] on [lt].
  LtiLtChannelMonitor({
    required this.sys,
    required this.lt,
    required Component parent,
    String name = 'ltiLtChannelMonitor',
  }) : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    await sys.resetN.nextPosedge;

    // TODO: anything to do with crediting here??

    sys.clk.posedge.listen((event) {
      if (lt.valid.previousValue!.isValid && lt.valid.previousValue!.toBool()) {
        add(LtiLtChannelPacket(
          user: lt.userMixInEnable
              ? Axi5UserSignalsStruct(user: lt.user?.previousValue!.toInt())
              : null,
          tag: lt.ctag.previousValue!.toInt(),
        ));
      }
    });
  }
}
