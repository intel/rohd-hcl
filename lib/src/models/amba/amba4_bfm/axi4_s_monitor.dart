// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_s_monitor.dart
// A monitor that watches the AXI-S interface.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A monitor for [Axi4StreamMonitor]s.
class Axi4StreamMonitor extends Monitor<Axi4StreamPacket> {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// AXI4 Stream Interface.
  final Axi4StreamInterface rIntf;

  final List<LogicValue> _dataBuf = [];
  final List<LogicValue> _strbBuf = [];
  final List<LogicValue> _keepBuf = [];

  /// Creates a new [Axi4StreamMonitor] on [rIntf].
  Axi4StreamMonitor(
      {required this.sIntf,
      required this.rIntf,
      required Component parent,
      String name = 'axi4StreamMonitor'})
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
        final lastCheck = rIntf.last.previousValue!.isValid &&
            rIntf.last.previousValue!.toBool();
        final curr = rIntf.data.value;
        final currS = rIntf.strb.value;
        final currK = rIntf.keep.value;
        _dataBuf.add(curr);
        _strbBuf.add(currS);
        _keepBuf.add(currK);
        if (lastCheck) {
          add(
            Axi4StreamPacket(
                data: _dataBuf.rswizzle(),
                strb: _strbBuf.rswizzle(),
                keep: _keepBuf.rswizzle(),
                id: rIntf.id?.previousValue,
                user: rIntf.user?.previousValue,
                dest: rIntf.dest?.previousValue),
          );
          _dataBuf.clear();
          _strbBuf.clear();
          _keepBuf.clear();
        }
      }
    });
  }
}
