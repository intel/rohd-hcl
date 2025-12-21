// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// apb_test.dart
// Tests for the APB interface.
//
// 2023 May 19
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

class ApbCompleterTest extends Module {
  ApbCompleterTest(ApbInterface intf) {
    intf = intf.clone()
      ..connectIO(this, intf,
          inputTags: {ApbDirection.misc, ApbDirection.fromRequester},
          outputTags: {ApbDirection.fromCompleter});
  }
}

class ApbRequesterTest extends Module {
  ApbRequesterTest(ApbInterface intf) {
    intf = intf.clone()
      ..connectIO(this, intf,
          inputTags: {ApbDirection.misc, ApbDirection.fromCompleter},
          outputTags: {ApbDirection.fromRequester});
  }
}

class ApbPair extends Module {
  ApbPair(Logic clk, Logic reset) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    final apb = ApbInterface(
      includeSlvErr: true,
      userDataWidth: 10,
      userReqWidth: 11,
      userRespWidth: 12,
    );
    apb.clk <= clk;
    apb.resetN <= ~reset;

    ApbCompleterTest(apb);
    ApbRequesterTest(apb);
  }
}

class ApbCsrCompleterHwTest extends Test {
  late final ApbInterface intf;
  late final ApbRequesterAgent requester;
  late final DataPortInterface csrRd;
  late final DataPortInterface csrWr;
  late final ApbCompleter completer;
  late final CsrBlock csrs;

  final int dataWidth = 32;
  final int addrWidth = 32;

  late final int numTransfers;

  final int interTxnDelay;

  String get outFolder => 'tmp_test/apbhw/$name/';

  ApbCsrCompleterHwTest(
    super.name, {
    this.interTxnDelay = 0,
    int apbClkLatency = 0,
  }) : super(randomSeed: 123) {
    intf = ApbInterface(includeSlvErr: true);

    intf.clk <= SimpleClockGenerator(10).clk;

    csrRd = DataPortInterface(dataWidth, addrWidth);
    csrWr = DataPortInterface(dataWidth, addrWidth);

    requester = ApbRequesterAgent(intf: intf, parent: this);

    csrs = CsrBlock(
      config: CsrBlockConfig(name: 'test', baseAddr: 0x0, registers: [
        CsrInstanceConfig(
          arch: CsrConfig(
            name: 'reg0',
            access: CsrAccess.readWrite,
            fields: const [],
            isBackdoorWritable: false,
          ),
          addr: 0x0,
          width: dataWidth,
          resetValue: 0xa,
        ),
        CsrInstanceConfig(
          arch: CsrConfig(
            name: 'reg1',
            access: CsrAccess.readWrite,
            fields: const [],
            isBackdoorWritable: false,
          ),
          addr: 0x4,
          width: dataWidth,
          resetValue: 0xb,
        ),
      ]),
      clk: intf.clk,
      reset: ~intf.resetN,
      frontWrite: csrWr,
      frontRead: csrRd,
    );

    completer = ApbCsrCompleter(
        apb: intf,
        csrRd: csrRd,
        csrWr: csrWr,
        name: 'apb_csr_completer',
        apbClkLatency: apbClkLatency);

    final monitor = ApbMonitor(intf: intf, parent: this);

    Directory(outFolder).createSync(recursive: true);

    final tracker = ApbTracker(
      intf: intf,
      dumpTable: false,
      outputFolder: outFolder,
    );

    numTransfers = csrs.config.registers.length;

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

    final obj = phase.raiseObjection('apbHwTestObj');

    await _resetFlow();

    final randomData = List.generate(
        numTransfers,
        (index) =>
            LogicValue.ofInt(Test.random!.nextInt(1 << dataWidth), dataWidth));

    // normal writes
    for (var i = 0; i < numTransfers; i++) {
      final addr = i * 4;
      final wrPkt = ApbWritePacket(
          addr: LogicValue.ofInt(addr, addrWidth), data: randomData[i]);

      requester.sequencer.add(wrPkt);

      unawaited(wrPkt.completed.then((value) {
        numTransfersCompleted++;
      }));

      await intf.clk.waitCycles(interTxnDelay);
    }

    // normal reads that check data
    for (var i = 0; i < numTransfers; i++) {
      final addr = i * 4;
      final rdPkt = ApbReadPacket(addr: LogicValue.ofInt(addr, addrWidth));
      requester.sequencer.add(rdPkt);

      unawaited(rdPkt.completed.then((value) {
        expect(
          rdPkt.returnedData,
          randomData[i],
        );

        numTransfersCompleted++;
      }));

      await intf.clk.waitCycles(interTxnDelay);
    }

    obj.drop();
  }

  Future<void> _resetFlow() async {
    intf.resetN.inject(1);
    await intf.clk.waitCycles(2);
    intf.resetN.inject(0);
    await intf.clk.waitCycles(3);
    intf.resetN.inject(1);
  }

  @override
  void check() {
    expect(numTransfersCompleted, numTransfers * 2);
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  Future<void> runTest(ApbCsrCompleterHwTest apbTest,
      {bool dumpWaves = false}) async {
    Simulator.setMaxSimTime(3000);

    await apbTest.completer.build();
    if (dumpWaves) {
      WaveDumper(apbTest.completer);
    }

    await apbTest.start();
  }

  test('connect apb modules', () async {
    final abpPair = ApbPair(Logic(), Logic());
    await abpPair.build();
  });

  test('abp optional ports null', () async {
    final apb = ApbInterface();
    expect(apb.aUser, isNull);
    expect(apb.bUser, isNull);
    expect(apb.rUser, isNull);
    expect(apb.wUser, isNull);
    expect(apb.slvErr, isNull);
  });

  test('apb csr completer - zero latency', () async {
    await runTest(ApbCsrCompleterHwTest('test'));
  });

  test('apb csr completer - non zero latency', () async {
    await runTest(ApbCsrCompleterHwTest('test', apbClkLatency: 1));
  });
}
