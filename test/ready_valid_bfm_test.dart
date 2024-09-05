// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// rotate_test.dart
// Tests for rotating
//
// 2023 February 17
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/models/models.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

class DummyReadyValidModule extends Module {
  DummyReadyValidModule(
    Logic clk,
    Logic reset,
    Logic ready,
    Logic valid,
    Logic data,
  ) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    ready = addInput('ready', ready);
    valid = addInput('valid', valid);
    data = addInput('data', data, width: 32);
  }
}

class ReadyValidBfmTest extends Test {
  final int numTransfers;

  final int interTxnDelay;

  final bool withRandomBlocks;

  final clk = SimpleClockGenerator(10).clk;
  final Logic reset = Logic();
  final Logic ready = Logic();
  final Logic valid = Logic();
  final Logic data = Logic(width: 32);

  late final ReadyValidTransmitterAgent transmitter;
  late final ReadyValidReceiverAgent receiver;
  late final ReadyValidMonitor monitor;

  String get outFolder => 'tmp_test/readyvalidbfm/$name/';

  ReadyValidBfmTest(
    super.name, {
    this.numTransfers = 10,
    this.interTxnDelay = 0,
    this.withRandomBlocks = false,
    super.randomSeed = 1234,
    super.printLevel = Level.OFF,
  }) {
    transmitter = ReadyValidTransmitterAgent(
      clk: clk,
      reset: reset,
      ready: ready,
      valid: valid,
      data: data,
      blockRate: withRandomBlocks ? 0.5 : 0,
      parent: this,
    );

    receiver = ReadyValidReceiverAgent(
      clk: clk,
      reset: reset,
      ready: ready,
      valid: valid,
      data: data,
      blockRate: withRandomBlocks ? 0.5 : 0,
      parent: this,
    );

    monitor = ReadyValidMonitor(
      clk: clk,
      reset: reset,
      ready: ready,
      valid: valid,
      data: data,
      parent: this,
    );

    Directory(outFolder).createSync(recursive: true);

    final tracker = ReadyValidTracker(outputFolder: outFolder);
    monitor.stream.listen(tracker.record);

    Simulator.registerEndOfSimulationAction(() async {
      await tracker.terminate();

      final jsonStr =
          File('$outFolder/readyValidTracker.tracker.json').readAsStringSync();
      final jsonContents = json.decode(jsonStr);
      // ignore: avoid_dynamic_calls
      expect(jsonContents['records'].length, numTransfers);

      Directory(outFolder).deleteSync(recursive: true);
    });
  }

  int numTransfersCompleted = 0;

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('apbBfmTestObj');

    await _resetFlow();

    logger.info('Reset flow completed');

    final randomData = List.generate(numTransfers,
        (index) => LogicValue.ofInt(Test.random!.nextInt(1 << 32), 32));

    // check correct data coming out of the monitor
    monitor.stream.listen((event) {
      logger.info('Monitor received $numTransfersCompleted $event');
      expect(event.data, randomData[numTransfersCompleted++]);
    });

    for (var i = 0; i < numTransfers; i++) {
      final pkt = ReadyValidPacket(randomData[i]);

      logger.info('Adding packet $i');
      transmitter.sequencer.add(pkt);

      await clk.waitCycles(interTxnDelay);
    }

    logger.info('Dropping objection!');

    obj.drop();
  }

  Future<void> _resetFlow() async {
    await clk.waitCycles(2);
    reset.inject(1);
    await clk.waitCycles(3);
    reset.inject(0);
  }

  @override
  void check() {
    expect(numTransfersCompleted, numTransfers);
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  Future<void> runTest(ReadyValidBfmTest readyValidBfmTest,
      {bool dumpWaves = false}) async {
    Simulator.setMaxSimTime(3000);

    if (dumpWaves) {
      final mod = DummyReadyValidModule(
        readyValidBfmTest.clk,
        readyValidBfmTest.reset,
        readyValidBfmTest.ready,
        readyValidBfmTest.valid,
        readyValidBfmTest.data,
      );
      await mod.build();
      WaveDumper(mod);
    }

    await readyValidBfmTest.start();
  }

  test('simple', () async {
    await runTest(ReadyValidBfmTest('simple'));
  });

  test('kitchen sink', () async {
    await runTest(ReadyValidBfmTest(
      'kitchen_sink',
      withRandomBlocks: true,
      interTxnDelay: 3,
    ));
  });
}
