// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// apb_bfm_test.dart
// Tests for the APB BFM.
//
// 2023 June 12
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

import 'apb_test.dart';

class ApbBfmTest extends Test {
  late final ApbInterface intf;
  late final ApbRequesterAgent requester;

  final storage = SparseMemoryStorage(addrWidth: 32);

  final int numTransfers;

  ApbBfmTest({this.numTransfers = 10}) : super('apbBfmTest') {
    intf = ApbInterface();

    intf.clk <= SimpleClockGenerator(10).clk;

    requester = ApbRequesterAgent(intf: intf, parent: this);

    ApbCompleterAgent(intf: intf, parent: this, storage: storage);

    final monitor = ApbMonitor(intf: intf, parent: this);
    final tracker = ApbTracker(intf: intf);

    Simulator.registerEndOfSimulationAction(() async {
      await tracker.terminate();
    });

    monitor.stream.listen(tracker.record);
  }

  int _numReadsCompleted = 0;

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('apbBfmTestObj');

    await _resetFlow();

    // normal writes
    for (var i = 0; i < numTransfers; i++) {
      requester.sequencer.add(ApbWritePacket(
          addr: LogicValue.ofInt(i, 32), data: LogicValue.ofInt(i, 32)));
    }

    // normal reads that check data
    for (var i = 0; i < numTransfers; i++) {
      final rdPkt = ApbReadPacket(addr: LogicValue.ofInt(i, 32));
      requester.sequencer.add(rdPkt);

      unawaited(rdPkt.completed.then((value) {
        // expect(rdPkt.returnedData!.toInt(), i);
        _numReadsCompleted++;
      }));
    }

    obj.drop();
  }

  Future<void> _resetFlow() async {
    await waitCycles(intf.clk, 2);
    intf.resetN.inject(0);
    await waitCycles(intf.clk, 3);
    intf.resetN.inject(1);
  }

  @override
  void check() {
    // expect(_numReadsCompleted, numTransfers);
  }
}

//TODO: with strobe
//TODO: check the tracker works

void main() {
  test('simple writes and reads', () async {
    Simulator.setMaxSimTime(3000);
    final apbBfmTest = ApbBfmTest();

    final mod = ApbCompleter(apbBfmTest.intf);
    await mod.build();
    WaveDumper(mod);

    await apbBfmTest.start();
  });
}
