// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_data_monitor.dart
// A monitor that watches the AXI4 interfaces.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A monitor for [Axi4DataChannelInterface]s.
class Axi4DataChannelMonitor extends Monitor<Axi4DataPacket> {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// AXI4 Read Interface.
  final Axi4DataChannelInterface rIntf;

  final List<LogicValue> _dataBuf = [];
  final List<LogicValue> _strbBuf = [];

  /// Capture if this is monitoring a write data interface.
  /// If so, it will have a strobe signal.
  late final bool isWr;

  /// Capture if this is monitoring a read data interface.
  /// If so, it will have a response code signal.
  late final bool isRd;

  /// Creates a new [Axi4DataChannelMonitor] on [rIntf].
  Axi4DataChannelMonitor(
      {required this.sIntf,
      required this.rIntf,
      required Component parent,
      String name = 'axi4DataChannelMonitor'})
      : super(name, parent) {
    isWr = rIntf is Axi4BaseWChannelInterface;
    isRd = rIntf is Axi4BaseRChannelInterface;
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    await sIntf.resetN.nextPosedge;

    sIntf.clk.posedge.listen((event) {
      if (rIntf.valid.previousValue!.isValid &&
          rIntf.ready.previousValue!.isValid &&
          rIntf.valid.previousValue!.toBool() &&
          rIntf.ready.previousValue!.toBool()) {
        final lastCheck = rIntf.last == null ||
            rIntf.last!.previousValue!.isValid &&
                rIntf.last!.previousValue!.toBool();
        final curr = rIntf.data.value;
        final currS =
            (isWr ? (rIntf as Axi4BaseWChannelInterface).strb.value : null);
        _dataBuf.add(curr);
        if (isWr) {
          _strbBuf.add(currS!);
        }
        if (lastCheck) {
          add(
            Axi4DataPacket(
                data: _dataBuf.rswizzle(),
                strb: (isWr ? _strbBuf.rswizzle() : null),
                id: rIntf.id?.previousValue,
                user: rIntf.user?.previousValue,
                resp: (isRd
                    ? (rIntf as Axi4BaseRChannelInterface).resp?.value
                    : null)),
          );
          _dataBuf.clear();
          if (isWr) {
            _strbBuf.clear();
          }
        }
      }
    });
  }
}
