// Copyright (C) 2023-2024 Intel Corporation
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

  final bool withRandomRspDelays;

  final bool withErrors;

  String get outFolder => 'tmp_test/apbbfm/$name/';

  ApbBfmTest(
    super.name, {
    this.numTransfers = 10,
    this.withStrobes = false,
    this.interTxnDelay = 0,
    this.withRandomRspDelays = false,
    this.withErrors = false,
  }) : super(randomSeed: 123) {
    intf = ApbInterface(includeSlvErr: true);

    intf.clk <= SimpleClockGenerator(10).clk;

    requester = ApbRequesterAgent(intf: intf, parent: this);

    ApbCompleterAgent(
      intf: intf,
      parent: this,
      storage: storage,
      responseDelay:
          withRandomRspDelays ? (request) => Test.random!.nextInt(5) : null,
      respondWithError: withErrors ? (request) => true : null,
    );

    final monitor = ApbMonitor(intf: intf, parent: this);

    Directory(outFolder).createSync(recursive: true);

    final tracker = ApbTracker(
      intf: intf,
      dumpTable: false,
      outputFolder: outFolder,
    );

    ApbComplianceChecker(intf, parent: this);

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

    final randomStrobes = List.generate(
        numTransfers, (index) => LogicValue.ofInt(Test.random!.nextInt(16), 4));

    final randomData = List.generate(numTransfers,
        (index) => LogicValue.ofInt(Test.random!.nextInt(1 << 32), 32));

    LogicValue strobedData(LogicValue originalData, LogicValue strobe) => [
          for (var i = 0; i < 4; i++)
            strobe[i].toBool()
                ? originalData.getRange(i * 8, i * 8 + 8)
                : LogicValue.filled(8, LogicValue.zero)
        ].rswizzle();

    // normal writes
    for (var i = 0; i < numTransfers; i++) {
      final wrPkt = ApbWritePacket(
          addr: LogicValue.ofInt(i, 32),
          data: randomData[i],
          strobe: withStrobes ? randomStrobes[i] : null);

      requester.sequencer.add(wrPkt);

      unawaited(wrPkt.completed.then((value) {
        expect(wrPkt.returnedSlvErr!.toBool(), withErrors);

        numTransfersCompleted++;
      }));

      await intf.clk.waitCycles(interTxnDelay);
    }

    // normal reads that check data
    for (var i = 0; i < numTransfers; i++) {
      final rdPkt = ApbReadPacket(addr: LogicValue.ofInt(i, 32));
      requester.sequencer.add(rdPkt);

      unawaited(rdPkt.completed.then((value) {
        expect(
          rdPkt.returnedData,
          withErrors
              ? LogicValue.filled(32, LogicValue.x)
              : withStrobes
                  ? strobedData(randomData[i], randomStrobes[i])
                  : randomData[i],
        );

        expect(rdPkt.returnedSlvErr!.toBool(), withErrors);

        numTransfersCompleted++;
      }));

      await intf.clk.waitCycles(interTxnDelay);
    }

    obj.drop();
  }

  Future<void> _resetFlow() async {
    await intf.clk.waitCycles(2);
    intf.resetN.inject(0);
    await intf.clk.waitCycles(3);
    intf.resetN.inject(1);
  }

  @override
  void check() {
    expect(numTransfersCompleted, numTransfers * 2);

    if (withErrors) {
      expect(storage.isEmpty, true);
    }
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  Future<void> runTest(ApbBfmTest apbBfmTest, {bool dumpWaves = false}) async {
    Simulator.setMaxSimTime(3000);

    if (dumpWaves) {
      final mod = ApbCompleterTest(apbBfmTest.intf);
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

  test('random response delays', () async {
    await runTest(ApbBfmTest(
      'randrsp',
      numTransfers: 20,
      withRandomRspDelays: true,
    ));
  });

  test('random everything', () async {
    await runTest(ApbBfmTest(
      'randeverything',
      numTransfers: 20,
      withRandomRspDelays: true,
      withStrobes: true,
      interTxnDelay: 3,
    ));
  });

  test('with errors', () async {
    await runTest(ApbBfmTest('werr', withErrors: true));
  });
}
