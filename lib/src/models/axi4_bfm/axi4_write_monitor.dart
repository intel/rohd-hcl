// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_monitor.dart
// A monitor that watches the AXI4 interfaces.
//
// 2025 January
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A monitor for [Axi4WriteInterface]s.
class Axi4WriteMonitor extends Monitor<Axi4WriteRequestPacket> {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// AXI4 Write Interface.
  final Axi4WriteInterface wIntf;

  final List<Axi4WriteRequestPacket> _pendingWriteRequests = [];

  /// Creates a new [Axi4WriteMonitor] on [wIntf].
  Axi4WriteMonitor(
      {required this.sIntf,
      required this.wIntf,
      required Component parent,
      String name = 'axi4WriteMonitor'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    await sIntf.resetN.nextPosedge;

    // handle reset
    sIntf.resetN.negedge.listen((event) {
      _pendingWriteRequests.clear();
    });

    sIntf.clk.posedge.listen((event) {
      // write request monitoring
      if (wIntf.awValid.previousValue!.isValid &&
          wIntf.awReady.previousValue!.isValid &&
          wIntf.awValid.previousValue!.toBool() &&
          wIntf.awReady.previousValue!.toBool()) {
        _pendingWriteRequests.add(
          Axi4WriteRequestPacket(
              addr: wIntf.awAddr.previousValue!,
              prot: wIntf.awProt.previousValue!,
              id: wIntf.awId?.previousValue,
              len: wIntf.awLen?.previousValue,
              size: wIntf.awSize?.previousValue,
              burst: wIntf.awBurst?.previousValue,
              lock: wIntf.awLock?.previousValue,
              cache: wIntf.awCache?.previousValue,
              qos: wIntf.awQos?.previousValue,
              region: wIntf.awRegion?.previousValue,
              user: wIntf.awUser?.previousValue,
              data: [],
              strobe: []),
        );
      }

      // write data monitoring
      // NOTE: not dealing with WLAST here b/c it is implicit in how the interface behaves
      if (wIntf.wValid.previousValue!.isValid &&
          wIntf.wReady.previousValue!.isValid &&
          wIntf.wValid.previousValue!.toBool() &&
          wIntf.wReady.previousValue!.toBool()) {
        final targIdx = _pendingWriteRequests.length - 1;
        _pendingWriteRequests[targIdx].data.add(wIntf.wData.previousValue!);
        _pendingWriteRequests[targIdx].strobe.add(wIntf.wStrb.previousValue!);
        _pendingWriteRequests[targIdx].wUser = wIntf.wUser?.previousValue;
      }

      // write response monitoring
      if (wIntf.bValid.previousValue!.isValid &&
          wIntf.bReady.previousValue!.isValid &&
          wIntf.bValid.previousValue!.toBool() &&
          wIntf.bReady.previousValue!.toBool()) {
        var targIdx = 0;
        if (wIntf.bId != null) {
          targIdx = _pendingWriteRequests.indexWhere((element) =>
              element.id!.toInt() == wIntf.bId!.previousValue!.toInt());
        }
        if (targIdx >= 0 && _pendingWriteRequests.length > targIdx) {
          add(_pendingWriteRequests[targIdx]
            ..complete(
              resp: wIntf.bResp?.previousValue,
              user: wIntf.bUser?.previousValue,
            ));
          _pendingWriteRequests.removeAt(targIdx);
        }
      }
    });
  }
}
