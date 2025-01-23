// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_bfm_test.dart
// Tests for the AXI4 BFM.
//
// 2025 January
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/models/axi4_bfm/axi4_bfm.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

import 'apb_test.dart';

class Axi4BfmTest extends Test {
  late final Axi4SystemInterface sIntf;
  late final Axi4ReadInterface rIntf;
  late final Axi4WriteInterface wIntf;

  late final Axi4MainAgent main;

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

  String get outFolder => 'tmp_test/axi4bfm/$name/';

  Axi4BfmTest(
    super.name, {
    this.numTransfers = 10,
    this.withStrobes = false,
    this.interTxnDelay = 0,
    this.withRandomRspDelays = false,
    this.withErrors = false,
  }) : super(randomSeed: 123) {
    // using default parameter values for all interfaces
    sIntf = Axi4SystemInterface();
    rIntf = Axi4ReadInterface();
    wIntf = Axi4WriteInterface();

    sIntf.clk <= SimpleClockGenerator(10).clk;

    main =
        Axi4MainAgent(sIntf: sIntf, rIntf: rIntf, wIntf: wIntf, parent: this);

    Axi4SubordinateAgent(
      sIntf: sIntf,
      rIntf: rIntf,
      wIntf: wIntf,
      parent: this,
      storage: storage,
      readResponseDelay:
          withRandomRspDelays ? (request) => Test.random!.nextInt(5) : null,
      writeResponseDelay:
          withRandomRspDelays ? (request) => Test.random!.nextInt(5) : null,,
      respondWithError: withErrors ? (request) => true : null,
    );

    final monitor = Axi4Monitor(sIntf: sIntf,
      rIntf: rIntf,
      wIntf: wIntf,
      parent: this,);

    Directory(outFolder).createSync(recursive: true);

    final tracker = Axi4Tracker(
      rIntf: rIntf,
      wIntf: wIntf,
      dumpTable: false,
      outputFolder: outFolder,
    );

    Axi4ComplianceChecker(sIntf,
      rIntf,
      wIntf, parent: this);

    Simulator.registerEndOfSimulationAction(() async {
      await tracker.terminate();

      final jsonStr =
          File('$outFolder/axi4Tracker.tracker.json').readAsStringSync();
      final jsonContents = json.decode(jsonStr);
      // ignore: avoid_dynamic_calls
      // TODO: fix??
      expect(jsonContents['records'].length, 2 * numTransfers);

      Directory(outFolder).deleteSync(recursive: true);
    });

    monitor.stream.listen(tracker.record);
  }

  int numTransfersCompleted = 0;

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('axi4BfmTestObj');

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
      final wrPkt = Axi4WriteRequestPacket(
        addr: LogicValue.ofInt(i, 32), 
        prot: LogicValue.ofInt(0, wIntf.protWidth), 
        data: randomData,
        id: LogicValue.ofInt(i, wIntf.idWidth),
        len: LogicValue.ofInt(randomData.length, wIntf.lenWidth),
        size: LogicValue.ofInt(2, wIntf.sizeWidth), // TODO
        burst: LogicValue.ofInt(Axi4BurstField.incr.value, wIntf.burstWidth),
        lock: LogicValue.ofInt(0, 1),
        cache: LogicValue.ofInt(0, wIntf.cacheWidth),
        qos: LogicValue.ofInt(0, wIntf.qosWidth),
        region: LogicValue.ofInt(0, wIntf.regionWidth),
        user: LogicValue.ofInt(0, wIntf.awuserWidth),
        strobe: withStrobes ? randomStrobes : null,
        wUser: LogicValue.ofInt(0, wIntf.wuserWidth),
      );

      main.sequencer.add(wrPkt);
      numTransfersCompleted++;

      // TODO: should we be waiting??
      // Note that driver will already serialize the writes

      await sIntf.clk.waitCycles(interTxnDelay);
    }

    // normal reads that check data
    for (var i = 0; i < numTransfers; i++) {
      final rdPkt = Axi4ReadRequestPacket(
        addr: LogicValue.ofInt(i, 32), 
        prot: LogicValue.ofInt(0, rIntf.protWidth), 
        id: LogicValue.ofInt(i, rIntf.idWidth),
        len: LogicValue.ofInt(randomData.length, rIntf.lenWidth),
        size: LogicValue.ofInt(2, rIntf.sizeWidth), // TODO
        burst: LogicValue.ofInt(Axi4BurstField.incr.value, rIntf.burstWidth),
        lock: LogicValue.ofInt(0, 1),
        cache: LogicValue.ofInt(0, rIntf.cacheWidth),
        qos: LogicValue.ofInt(0, rIntf.qosWidth),
        region: LogicValue.ofInt(0, rIntf.regionWidth),
        user: LogicValue.ofInt(0, rIntf.aruserWidth),
      );
    
      main.sequencer.add(rdPkt);

      // TODO: should we be waiting??

      await sIntf.clk.waitCycles(interTxnDelay);
    }

    obj.drop();
  }

  Future<void> _resetFlow() async {
    await sIntf.clk.waitCycles(2);
    sIntf.resetN.inject(0);
    await sIntf.clk.waitCycles(3);
    sIntf.resetN.inject(1);
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

  Future<void> runTest(Axi4BfmTest axi4BfmTest, {bool dumpWaves = false}) async {
    Simulator.setMaxSimTime(3000);

    // TODO: dump waves...

    await axi4BfmTest.start();
  }

  test('simple writes and reads', () async {
    await runTest(Axi4BfmTest('simple'));
  });

  test('writes with strobes', () async {
    await runTest(Axi4BfmTest('strobes', numTransfers: 20, withStrobes: true));
  });

  test('writes and reads with 1 cycle delays', () async {
    await runTest(Axi4BfmTest('delay1', interTxnDelay: 1));
  });

  test('writes and reads with 2 cycle delays', () async {
    await runTest(Axi4BfmTest('delay2', interTxnDelay: 2));
  });

  test('writes and reads with 3 cycle delays', () async {
    await runTest(Axi4BfmTest('delay3', interTxnDelay: 3));
  });

  test('writes and reads with big delays', () async {
    await runTest(Axi4BfmTest('delay5', interTxnDelay: 5));
  });

  test('random response delays', () async {
    await runTest(Axi4BfmTest(
      'randrsp',
      numTransfers: 20,
      withRandomRspDelays: true,
    ));
  });

  test('random everything', () async {
    await runTest(Axi4BfmTest(
      'randeverything',
      numTransfers: 20,
      withRandomRspDelays: true,
      withStrobes: true,
      interTxnDelay: 3,
    ));
  });

  test('with errors', () async {
    await runTest(Axi4BfmTest('werr', withErrors: true));
  });
}
