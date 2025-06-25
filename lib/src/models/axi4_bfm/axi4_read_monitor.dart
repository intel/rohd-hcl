// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_monitor.dart
// A monitor that watches the AXI4 interfaces.
//
// 2025 January
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A monitor for [Axi4ReadInterface]s.
class Axi4ReadMonitor extends Monitor<Axi4ReadRequestPacket> {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// AXI4 Read Interface.
  final Axi4ReadInterface rIntf;

  final List<Axi4ReadRequestPacket> _pendingReadRequests = [];
  final List<List<LogicValue>> _pendingReadResponseData = [];

  /// Creates a new [Axi4ReadMonitor] on [rIntf].
  Axi4ReadMonitor(
      {required this.sIntf,
      required this.rIntf,
      required Component parent,
      String name = 'axi4ReadMonitor'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    await sIntf.resetN.nextPosedge;

    // handle reset
    sIntf.resetN.negedge.listen((event) {
      _pendingReadRequests.clear();
      _pendingReadResponseData.clear();
    });

    sIntf.clk.posedge.listen((event) {
      // read request monitoring
      if (rIntf.arValid.previousValue!.isValid &&
          rIntf.arReady.previousValue!.isValid &&
          rIntf.arValid.previousValue!.toBool() &&
          rIntf.arReady.previousValue!.toBool()) {
        _pendingReadRequests.add(
          Axi4ReadRequestPacket(
            addr: rIntf.arAddr.previousValue!,
            prot: rIntf.arProt.previousValue!,
            id: rIntf.arId?.previousValue,
            len: rIntf.arLen?.previousValue,
            size: rIntf.arSize?.previousValue,
            burst: rIntf.arBurst?.previousValue,
            lock: rIntf.arLock?.previousValue,
            cache: rIntf.arCache?.previousValue,
            qos: rIntf.arQos?.previousValue,
            region: rIntf.arRegion?.previousValue,
            user: rIntf.arUser?.previousValue,
          ),
        );
        _pendingReadResponseData.add([]);
      }

      // read response data monitoring
      if (rIntf.rValid.previousValue!.isValid &&
          rIntf.rReady.previousValue!.isValid &&
          rIntf.rValid.previousValue!.toBool() &&
          rIntf.rReady.previousValue!.toBool()) {
        var targIdx = 0;
        if (rIntf.rId != null) {
          targIdx = _pendingReadRequests.indexWhere((element) =>
              element.id!.toInt() == rIntf.rId!.previousValue!.toInt());
        }
        if (targIdx >= 0 && _pendingReadRequests.length > targIdx) {
          _pendingReadResponseData[targIdx].add(rIntf.rData.previousValue!);
          if (rIntf.rLast?.value.toBool() ?? true) {
            add(_pendingReadRequests[targIdx]
              ..complete(
                data: _pendingReadResponseData[targIdx],
                resp: rIntf.rResp?.previousValue,
                user: rIntf.rUser?.previousValue,
              ));
            _pendingReadRequests.removeAt(targIdx);
            _pendingReadResponseData.removeAt(targIdx);
          }
        }
      }
    });
  }
}
