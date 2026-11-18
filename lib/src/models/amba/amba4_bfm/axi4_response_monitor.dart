// Copyright (C) 2024-2026 Intel Corporation
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

/// Common monitor for AXI and ACE response channels.
class Axi4ResponseChannelMonitorBase<T extends Axi4ResponseChannelInterface>
    extends Monitor<Axi4ResponsePacket> {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// Response interface.
  final T rIntf;

  /// Creates a response monitor on [rIntf].
  Axi4ResponseChannelMonitorBase(
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
          resp: rIntf.resp?.previousValue,
        ));
      }
    });
  }
}

/// A monitor for AXI4 write responses.
class Axi4ResponseChannelMonitor
    extends Axi4ResponseChannelMonitorBase<Axi4BaseBChannelInterface> {
  /// Creates a write response monitor.
  Axi4ResponseChannelMonitor({
    required super.sIntf,
    required super.rIntf,
    required super.parent,
    super.name,
  });
}

/// A monitor for ACE4 snoop responses in either signal layout.
class Ace4SnoopResponseChannelMonitor
    extends Axi4ResponseChannelMonitorBase<Ace4CrChannelInterface> {
  /// Creates a snoop response monitor.
  Ace4SnoopResponseChannelMonitor({
    required super.sIntf,
    required super.rIntf,
    required super.parent,
    super.name = 'ace4SnoopResponseChannelMonitor',
  });
}
