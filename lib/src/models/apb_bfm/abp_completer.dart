// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// apb_completer.dart
// A completer model for APB.
//
// 2023 June 12
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A model for the completer side of an [ApbInterface].
class ApbCompleter extends Component {
  /// The interface to drive.
  final ApbInterface intf;

  //TODO: slverr

  /// The index that this is listening to on the [intf].
  final int selectIndex;

  /// A place where the completer should save and retrieve data.
  ///
  /// The [ApbCompleter] will reset [storage] whenever the `resetN` signal is
  /// dropped.
  final MemoryStorage storage;

  /// A function which delays the response for the given `request`.
  ///
  /// If none is provided, then the delay will always be `0`.
  final int Function(ApbPacket request)? responseDelay;

  /// Creates a new model [ApbCompleter].
  ApbCompleter(
      {required this.intf,
      required this.storage,
      required Component parent,
      this.selectIndex = 0,
      this.responseDelay,
      String name = 'apbCompleter'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    intf.resetN.negedge.listen((event) {
      storage.reset();
    });

    intf.ready.put(0);

    // wait for reset to complete
    await intf.resetN.nextPosedge;

    while (!Simulator.simulationHasEnded) {
      await _receive();
    }
  }

  /// Receives one packet (or returns if not selected).
  Future<void> _receive() async {
    await intf.enable.nextPosedge;

    if (!intf.sel[selectIndex].value.toBool()) {
      // we're not selected, wait for the next time
      return;
    }

    ApbPacket pkt;
    if (intf.write.value.toBool()) {
      pkt = ApbWritePacket(
        addr: intf.addr.value,
        data: intf.wData.value,
        strobe: intf.strb.value,
      );
    } else {
      pkt = ApbReadPacket(addr: intf.addr.value);
    }

    await waitCycles(
      intf.clk,
      responseDelay != null ? responseDelay!(pkt) : 0,
      edge: Edge.neg,
    );

    if (pkt is ApbWritePacket) {
      // store the data
      storage.setData(pkt.addr, pkt.data);
      intf.ready.inject(1);
    } else if (pkt is ApbReadPacket) {
      // capture the data
      Simulator.injectAction(() {
        intf.rData.put(storage.getData(pkt.addr));
        intf.ready.put(1);
      });
    }

    // wait a cycle then end the transfer
    await intf.clk.nextNegedge;
    intf.ready.inject(0);
  }
}
