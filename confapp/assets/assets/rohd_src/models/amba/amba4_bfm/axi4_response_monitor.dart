// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_response_monitor.dart
// A monitor that watches the AXI4 interfaces.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A monitor for [Axi4BaseBChannelInterface]s.
class Axi4ResponseChannelMonitor extends Monitor<Axi4ResponsePacket> {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// AXI4 Response Interface.
  final Axi4BaseBChannelInterface rIntf;

  /// Creates a new [Axi4ResponseChannelMonitor] on [rIntf].
  Axi4ResponseChannelMonitor(
      {required this.sIntf,
      required this.rIntf,
      required Component parent,
      String name = 'axi4ResponseChannelMonitor'})
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
        add(Axi4ResponsePacket(
          id: rIntf.id?.previousValue,
          user: rIntf.user?.previousValue,
          resp: rIntf.resp?.value,
        ));
      }
    });
  }
}
