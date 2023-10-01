// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// apb_monitor.dart
// A monitor that watches the APB interface.
//
// 2023 June 12
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A monitor for [ApbInterface]s.
class ApbMonitor extends Monitor<ApbPacket> {
  /// The interface to monitor.
  final ApbInterface intf;

  /// Creates a new [ApbMonitor] on [intf].
  ApbMonitor(
      {required this.intf,
      required Component parent,
      String name = 'apbMonitor'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    await intf.resetN.nextPosedge;

    intf.clk.posedge.listen((event) {
      for (var i = 0; i < intf.numSelects; i++) {
        if (intf.sel[i].previousValue!.toBool() &&
            intf.enable.previousValue!.toBool() &&
            intf.ready.previousValue!.toBool()) {
          if (intf.write.previousValue!.toBool()) {
            add(
              ApbWritePacket(
                addr: intf.addr.previousValue!,
                data: intf.wData.previousValue!,
                strobe: intf.strb.previousValue,
                selectIndex: i,
              )..complete(
                  slvErr: intf.slvErr?.previousValue,
                ),
            );
          } else {
            add(
              ApbReadPacket(
                addr: intf.addr.previousValue!,
                selectIndex: i,
              )..complete(
                  data: intf.rData.previousValue,
                  slvErr: intf.slvErr?.previousValue,
                ),
            );
          }
        }
      }
    });
  }
}
