// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// apb_completer.dart
// An agent for completing APB requests.
//
// 2023 June 12
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A model for the completer side of an [ApbInterface].
class ApbCompleterAgent extends Agent {
  /// The interface to drive.
  final ApbInterface intf;

  //TODO: slverr

  /// The index that this is listening to on the [intf].
  final int selectIndex;

  /// A place where the completer should save and retrieve data.
  ///
  /// The [ApbCompleterAgent] will reset [storage] whenever the `resetN` signal is
  /// dropped.
  final MemoryStorage storage;

  /// A function which delays the response for the given `request`.
  ///
  /// If none is provided, then the delay will always be `0`.
  final int Function(ApbPacket request)? responseDelay;

  /// Creates a new model [ApbCompleterAgent].
  ApbCompleterAgent(
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

    intf.ready.inject(0);

    // wait for reset to complete
    await intf.resetN.nextPosedge;

    while (!Simulator.simulationHasEnded) {
      await _receive();
    }
  }

  /// Calculates a strobed version of data.
  LogicValue _strobeData(LogicValue originalData, LogicValue strobe) => [
        for (var i = 0; i < strobe.width; i++)
          strobe[i].toBool()
              ? originalData.getRange(i, i + 8)
              : LogicValue.filled(8, LogicValue.zero)
      ].rswizzle();

  /// Receives one packet (or returns if not selected).
  Future<void> _receive() async {
    await intf.enable.nextPosedge;

    if (!intf.sel[selectIndex].value.toBool()) {
      // we're not selected, wait for the next time
      return;
    }

    ApbPacket packet;
    if (intf.write.value.toBool()) {
      packet = ApbWritePacket(
        addr: intf.addr.value,
        data: intf.wData.value,
        strobe: intf.strb.value,
      );
    } else {
      packet = ApbReadPacket(addr: intf.addr.value);
    }

    if (responseDelay != null) {
      await waitCycles(
        intf.clk,
        responseDelay!(packet),
        edge: Edge.neg,
      );
    }

    if (packet is ApbWritePacket) {
      // store the data
      // storage.setData(packet.addr, _strobeData(packet.data, packet.strobe));
      storage.setData(packet.addr, packet.data);
      intf.ready.inject(1);
    } else if (packet is ApbReadPacket) {
      // capture the data
      Simulator.injectAction(() {
        intf.rData.put(storage.getData(packet.addr));
        intf.ready.put(1);
      });
    }

    // wait a cycle then end the transfer
    await intf.enable.nextNegedge;
    intf.ready.inject(0);
  }
}
