// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// apb_bfm_test.dart
// Tests for the APB BFM.
//
// 2023 June 12
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

import 'apb_test.dart';

class ApbBfmTest extends Test {
  late final ApbInterface intf;
  late final ApbRequesterAgent requester;

  final storage = SparseMemoryStorage(
    addrWidth: 32,
    dataWidth: 32,
    onInvalidRead: (addr, dataWidth) =>
        LogicValue.filled(dataWidth, LogicValue.zero),
  );

  final int numTransfers;

  final bool withStrobes;

  final int interTxnDelay;

  String get outFolder => 'tmp_test/apbbfm/$name/';

  ApbBfmTest(
    super.name, {
    this.numTransfers = 10,
    this.withStrobes = false,
    this.interTxnDelay = 0,
  }) {
    intf = ApbInterface();

    intf.clk <= SimpleClockGenerator(10).clk;

    requester = ApbRequesterAgent(intf: intf, parent: this);

    ApbCompleterAgent(intf: intf, parent: this, storage: storage);

    final monitor = ApbMonitor(intf: intf, parent: this);

    Directory(outFolder).createSync(recursive: true);

    final tracker = ApbTracker(
      intf: intf,
      dumpTable: false,
      outputFolder: outFolder,
    );

    Simulator.registerEndOfSimulationAction(() async {
      await tracker.terminate();

      final jsonStr =
          File('$outFolder/apbTracker.tracker.json').readAsStringSync();
      final jsonContents = json.decode(jsonStr);
      // ignore: avoid_dynamic_calls
      expect(jsonContents['records'].length, 2 * numTransfers);

      Directory(outFolder).deleteSync(recursive: true);
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
                ? originalData.getRange(i * 8, i * 8 + 8)
                : LogicValue.filled(8, LogicValue.zero)
        ].rswizzle();

    // normal writes
    for (var i = 0; i < numTransfers; i++) {
      requester.sequencer.add(ApbWritePacket(
          addr: LogicValue.ofInt(i, 32),
          data: randomData[i],
          strobe: withStrobes ? randomStrobes[i] : null));
      await waitCycles(intf.clk, interTxnDelay);
    }

    // normal reads that check data
    for (var i = 0; i < numTransfers; i++) {
      final rdPkt = ApbReadPacket(addr: LogicValue.ofInt(i, 32));
      requester.sequencer.add(rdPkt);

      unawaited(rdPkt.completed.then((value) {
        expect(
          rdPkt.returnedData,
          withStrobes
              ? strobedData(randomData[i], randomStrobes[i])
              : randomData[i],
        );
        numTransfersCompleted++;
      }));

      await waitCycles(intf.clk, interTxnDelay);
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

//TODO: check the checker
//TODO: check response delays

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  Future<void> runTest(ApbBfmTest apbBfmTest, {bool dumpWaves = false}) async {
    Simulator.setMaxSimTime(3000);

    if (dumpWaves) {
      final mod = ApbCompleter(apbBfmTest.intf);
      await mod.build();
      WaveDumper(mod);
    }

    await apbBfmTest.start();
  }

  test('simple writes and reads', () async {
    await runTest(ApbBfmTest('simple'));
  });

  test('writes with strobes', () async {
    await runTest(ApbBfmTest('strobes', numTransfers: 20, withStrobes: true));
  });

  test('writes and reads with 1 cycle delays', () async {
    await runTest(ApbBfmTest('delay1', interTxnDelay: 1));
  });

  test('writes and reads with 2 cycle delays', () async {
    await runTest(ApbBfmTest('delay2', interTxnDelay: 2));
  });

  test('writes and reads with 3 cycle delays', () async {
    await runTest(ApbBfmTest('delay3', interTxnDelay: 3));
  });

  test('writes and reads with big delays', () async {
    await runTest(ApbBfmTest('delay5', interTxnDelay: 5));
  });
}
