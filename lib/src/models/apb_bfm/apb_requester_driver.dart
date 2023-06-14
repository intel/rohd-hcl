// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// apb_requester_driver.dart
// A driver for APB requests.
//
// 2023 June 12
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/interfaces.dart';
import 'package:rohd_hcl/src/models/apb_bfm/apb_packet.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A driver for the [ApbInterface] from the requester side.
///
/// Driven read packets will update the returned data into the same packet.
class ApbRequesterDriver extends PendingClockedDriver<ApbPacket> {
  /// The interface to drive.
  final ApbInterface intf;

  /// Creates a new [ApbRequesterDriver].
  ApbRequesterDriver({
    required Component parent,
    required this.intf,
    required super.sequencer,
    super.timeoutCycles = 500,
    super.dropDelayCycles = 30,
    String name = 'apbRequesterDriver',
  }) : super(
          name,
          parent,
          clk: intf.clk,
        );

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    _deselectAll();

    // wait for reset to complete before driving anything
    await intf.resetN.nextPosedge;

    while (!Simulator.simulationHasEnded) {
      if (pendingSeqItems.isNotEmpty) {
        await _drivePacket(pendingSeqItems.removeFirst());
      } else {
        await intf.clk.nextNegedge;
        Simulator.injectAction(() {
          _deselectAll();
          intf.enable.put(0);
        });
      }
    }
  }

  /// Drives a packet onto the interface.
  Future<void> _drivePacket(ApbPacket packet) async {
    // first, SETUP

    await intf.clk.nextNegedge;

    // if we're not selecting this interface, then we need to select it
    if (!intf.sel[packet.selectIndex].value.toBool()) {
      _select(packet.selectIndex);
    }

    Simulator.injectAction(() {
      intf.enable.put(0);
      intf.addr.put(packet.addr);

      if (packet is ApbWritePacket) {
        intf.write.put(1);
        intf.wData.put(packet.data);
        intf.strb.put(packet.strobe);
      } else if (packet is ApbReadPacket) {
        intf.write.put(0);
        intf.wData.put(0);
        intf.strb.put(0);
      }
    });

    await intf.clk.nextNegedge;

    // now, ACCESS
    intf.enable.inject(1);

    // wait for ready from completer, if not already asserted
    if (!intf.ready.value.toBool()) {
      await intf.ready.nextPosedge;
    }

    if (packet is ApbWritePacket) {
      packet.complete(
        slvErr: intf.slvErr?.value,
      );
    } else if (packet is ApbReadPacket) {
      packet.complete(
        data: intf.rData.value,
        slvErr: intf.slvErr?.value,
      );
    }

    // now we're done, since enable and ready are both high, move on
  }

  /// Selects [index] and deselects the rest.
  void _select(int index) {
    _deselectAll();
    intf.sel[index].put(1);
  }

  /// Clears all selects.
  void _deselectAll() {
    // zero out all the selects, which should mask everything else
    for (var i = 0; i < intf.numSelects; i++) {
      intf.sel[i].put(0);
    }
  }
}
