// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_request_monitor.dart
// A monitor that watches the AXI4 interfaces.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A monitor for [Axi4RequestChannelInterface]s.
class Axi4RequestChannelMonitor extends Monitor<Axi4RequestPacket> {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// AXI4 Read Interface.
  final Axi4RequestChannelInterface rIntf;

  /// Creates a new [Axi4RequestChannelMonitor] on [rIntf].
  Axi4RequestChannelMonitor(
      {required this.sIntf,
      required this.rIntf,
      required Component parent,
      String name = 'axi4RequestChannelMonitor'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    await sIntf.resetN.nextPosedge;

    sIntf.clk.posedge.listen((event) {
      if (rIntf.valid.previousValue!.isValid &&
          rIntf.ready.previousValue!.isValid &&
          rIntf.valid.previousValue!.toBool() &&
          rIntf.ready.previousValue!.toBool()) {
        final isAce = rIntf is Ace4RequestChannel;
        add(
          Axi4RequestPacket(
            addr: rIntf.addr.previousValue!,
            prot: rIntf.prot.previousValue!,
            id: rIntf.id?.previousValue,
            len: rIntf.len?.previousValue,
            size: rIntf.size?.previousValue,
            burst: rIntf.burst?.previousValue,
            lock: rIntf.lock?.previousValue,
            cache: rIntf.cache?.previousValue,
            qos: rIntf.qos?.previousValue,
            region: rIntf.region?.previousValue,
            user: rIntf.user?.previousValue,
            domain: (isAce
                ? (rIntf as Ace4RequestChannel).domain?.previousValue
                : null),
            bar: (isAce
                ? (rIntf as Ace4RequestChannel).bar?.previousValue
                : null),
          ),
        );
      }
    });
  }
}
