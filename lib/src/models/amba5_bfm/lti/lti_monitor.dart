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
          addr: la.addr.value.toInt(),
          trans: la.trans.value.toInt(),
          attr: la.attr.value.toInt(),
          user: la.userMixInEnable
              ? Axi5UserSignalsStruct(user: la.user?.value.toInt())
              : null,
          id: la.idMixInEnable
              ? Axi5IdSignalsStruct(
                  id: la.id?.value.toInt(),
                )
              : null,
          prot: Axi5ProtSignalsStruct(
            nse: la.nse?.value.toBool(),
            priv: la.priv?.value.toBool(),
            inst: la.inst?.value.toBool(),
            pas: la.pas?.value.toInt(),
          ),
          mmu: la.mmuMixInEnable
              ? Axi5MmuSignalsStruct(
                  mmuValid: la.mmuValid!.value.toBool(),
                  mmuSecSid: la.mmuSecSid?.value.toInt(),
                  mmuSid: la.mmuSid?.value.toInt(),
                  mmuSsidV: la.mmuSsidV?.value.toBool(),
                  mmuSsid: la.mmuSsid?.value.toInt(),
                  mmuAtSt: la.mmuAtSt?.value.toBool(),
                  mmuFlow: la.mmuFlow?.value.toInt(),
                  mmuPasUnknown: la.mmuPasUnknown?.value.toBool(),
                  mmuPm: la.mmuPm?.value.toBool(),
                )
              : null,
          debug: la.debugMixInEnable
              ? Axi5DebugSignalsStruct(
                  loop: la.loop?.value.toInt(),
                )
              : null,
          ogV: la.ogv.value.toBool(),
          og: la.og?.value.toInt(),
          tlBlock: la.tlBlock?.value.toInt(),
          ident: la.ident?.value.toInt(),
          vc: la.vc?.value.toInt() ?? 0,
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
          addr: lr.addr.value.toInt(),
          hwattr: lr.hwAttr.value.toInt(),
          attr: lr.attr.value.toInt(),
          user: lr.userMixInEnable
              ? Axi5UserSignalsStruct(user: lr.user?.value.toInt())
              : null,
          id: lr.idMixInEnable
              ? Axi5IdSignalsStruct(
                  id: lr.id?.value.toInt(),
                )
              : null,
          prot: Axi5ProtSignalsStruct(
            nse: lr.nse?.value.toBool(),
            priv: lr.priv?.value.toBool(),
            inst: lr.inst?.value.toBool(),
            pas: lr.pas?.value.toInt(),
          ),
          debug: lr.debugMixInEnable
              ? Axi5DebugSignalsStruct(
                  loop: lr.loop?.value.toInt(),
                )
              : null,
          response: Axi5ResponseSignalsStruct(
            resp: lr.resp?.value.toInt(),
          ),
          mecId: lr.mecId?.value.toInt(),
          mpam: lr.mpam?.value.toInt(),
          ctag: lr.ctag.value.toInt(),
          size: lr.size.value.toInt(),
          vc: lr.vc?.value.toInt() ?? 0,
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
              ? Axi5UserSignalsStruct(user: lc.user?.value.toInt())
              : null,
          tag: lc.ctag.value.toInt(),
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
              ? Axi5UserSignalsStruct(user: lt.user?.value.toInt())
              : null,
          tag: lt.ctag.value.toInt(),
        ));
      }
    });
  }
}
