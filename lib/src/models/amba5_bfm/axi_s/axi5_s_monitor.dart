// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi5_s_monitor.dart
// A monitor that watches the AXI-S interface.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A monitor for [Axi5StreamMonitor]s.
class Axi5StreamMonitor extends Monitor<Axi5StreamPacket> {
  /// AXI5 System Interface.
  final Axi5SystemInterface sys;

  /// AXI5 Stream Interface.
  final Axi5StreamInterface strm;

  /// Creates a new [Axi5StreamMonitor] on [strm].
  Axi5StreamMonitor(
      {required this.sys,
      required this.strm,
      required Component parent,
      String name = 'axi5StreamMonitor'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    await sys.resetN.nextPosedge;

    sys.clk.posedge.listen((event) {
      if (strm.valid.previousValue!.isValid &&
          strm.ready!.previousValue!.isValid &&
          strm.valid.previousValue!.toBool() &&
          strm.ready!.previousValue!.toBool()) {
        add(
          Axi5StreamPacket(
              data: strm.data?.previousValue!.toBigInt() ?? BigInt.from(0),
              strb: strm.strb?.previousValue!.toInt(),
              keep: strm.keep?.previousValue!.toInt(),
              id: strm.id?.previousValue!.toInt(),
              user: strm.user?.previousValue!.toInt(),
              dest: strm.dest?.previousValue!.toInt(),
              last: strm.last?.previousValue!.toBool(),
              wakeup: strm.wakeup?.previousValue!.toBool()),
        );
      }
    });
  }
}
