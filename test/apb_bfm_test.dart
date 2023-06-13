// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// apb_bfm_test.dart
// Tests for the APB BFM.
//
// 2023 June 12
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';
import 'dart:math';

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

  final bool withStrobes;

  ApbBfmTest({this.numTransfers = 10, this.withStrobes = false})
      : super('apbBfmTest') {
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

  int numTransfersCompleted = 0;

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('apbBfmTestObj');

    await _resetFlow();

    final rand = Random(123);

    final randomStrobes = List.generate(
        numTransfers, (index) => LogicValue.ofInt(rand.nextInt(16), 4));

    final randomData = List.generate(
        numTransfers, (index) => LogicValue.ofInt(rand.nextInt(1 << 32), 32));

    LogicValue strobedData(LogicValue originalData, LogicValue strobe) => [
          for (var i = 0; i < 4; i++)
            strobe[i].toBool()
                ? originalData.getRange(i, i + 8)
                : LogicValue.filled(8, LogicValue.zero)
        ].rswizzle();

    // normal writes
    for (var i = 0; i < numTransfers; i++) {
      requester.sequencer.add(ApbWritePacket(
          addr: LogicValue.ofInt(i, 32),
          data: randomData[i],
          strobe: withStrobes ? randomStrobes[i] : null));
    }

    // normal reads that check data
    for (var i = 0; i < numTransfers; i++) {
      final rdPkt = ApbReadPacket(addr: LogicValue.ofInt(i, 32));
      requester.sequencer.add(rdPkt);

      unawaited(rdPkt.completed.then((value) {
        expect(rdPkt.returnedData, randomData[i]);
        //  strobedData(randomData[i], randomStrobes[i]));
        numTransfersCompleted++;
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
    expect(numTransfersCompleted, numTransfers);
  }
}

//TODO: with strobe
//TODO: check the tracker works
//TODO: check the checker
//TODO: make sure there's no extra transactions detected! (or too few!)
//TODO: check delays
//TODO: strobes need to apply to the same addr multiple times

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('simple writes and reads', () async {
    Simulator.setMaxSimTime(3000);
    final apbBfmTest = ApbBfmTest();

    final mod = ApbCompleter(apbBfmTest.intf);
    await mod.build();
    WaveDumper(mod);

    await apbBfmTest.start();
  });

  test('writes with strobes', () async {
    Simulator.setMaxSimTime(3000);
    final apbBfmTest = ApbBfmTest(numTransfers: 20, withStrobes: true);

    final mod = ApbCompleter(apbBfmTest.intf);
    await mod.build();
    WaveDumper(mod);

    await apbBfmTest.start();
  });
}
