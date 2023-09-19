// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fifo_test.dart
// Tests for FIFO
//
// 2023 March 13
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('fifo simple', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);

    final wrEn = Logic()..put(0);
    final rdEn = Logic()..put(0);
    final wrData = Logic(width: 32);

    final fifo = Fifo(
      clk,
      reset,
      writeEnable: wrEn,
      readEnable: rdEn,
      writeData: wrData,
      generateError: true,
      generateOccupancy: true,
      depth: 3,
    );

    final rdData = fifo.readData;

    await fifo.build();

    Future<void> checkThat(
        {required bool empty,
        required bool full,
        required int occupancy}) async {
      await clk.nextPosedge;
      expect(fifo.empty.value.toBool(), empty);
      expect(fifo.full.value.toBool(), full);
      expect(fifo.occupancy!.value.toInt(), occupancy);
    }

    unawaited(Simulator.run());

    // a little reset flow
    await clk.nextNegedge;
    reset.put(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.put(0);
    await clk.nextNegedge;
    await clk.nextNegedge;

    // this test, we don't expect any errors, check every negedge
    clk.negedge.listen((event) {
      // do it 1 timestamp after since this TB drives after edges
      Simulator.registerAction(
          Simulator.time + 1, () => expect(fifo.error!.value.toBool(), false));
    });

    await checkThat(empty: true, full: false, occupancy: 0);

    await clk.nextNegedge;

    // push a few things in, checking empty and full
    wrEn.put(1);
    wrData.put(0xa);

    await checkThat(empty: false, full: false, occupancy: 1);

    await clk.nextNegedge;

    wrData.put(0xb);

    await clk.nextNegedge;

    wrData.put(0xc);

    await checkThat(empty: false, full: true, occupancy: 3);

    await clk.nextNegedge;

    wrEn.put(0);

    // pop them out and check they match
    await clk.nextNegedge;

    rdEn.put(1);
    expect(rdData.value.toInt(), 0xa);

    await checkThat(empty: false, full: false, occupancy: 2);

    await clk.nextNegedge;

    expect(rdData.value.toInt(), 0xb);

    await clk.nextNegedge;

    expect(rdData.value.toInt(), 0xc);

    await checkThat(empty: true, full: false, occupancy: 0);

    await clk.nextNegedge;

    rdEn.put(0);

    await checkThat(empty: true, full: false, occupancy: 0);

    await clk.nextNegedge;

    Simulator.endSimulation();
    await Simulator.simulationEnded;
  });

  test('fifo underflow error without bypass', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);

    final wrEn = Logic()..put(0);
    final rdEn = Logic()..put(0);
    final wrData = Logic(width: 32);

    final fifo = Fifo(
      clk,
      reset,
      writeEnable: wrEn,
      readEnable: rdEn,
      writeData: wrData,
      generateError: true,
      depth: 3,
    );

    await fifo.build();

    unawaited(Simulator.run());

    // a little reset flow
    await clk.nextNegedge;
    reset.put(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.put(0);
    await clk.nextNegedge;
    await clk.nextNegedge;

    rdEn.put(1);

    expect(fifo.error!.value.toBool(), true);

    Simulator.endSimulation();
    await Simulator.simulationEnded;
  });

  test('fifo underflow error with bypass', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);

    final wrEn = Logic()..put(0);
    final rdEn = Logic()..put(0);
    final wrData = Logic(width: 32);

    final fifo = Fifo(
      clk,
      reset,
      writeEnable: wrEn,
      readEnable: rdEn,
      writeData: wrData,
      generateError: true,
      generateBypass: true,
      depth: 3,
    );

    await fifo.build();

    unawaited(Simulator.run());

    // a little reset flow
    await clk.nextNegedge;
    reset.put(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.put(0);
    await clk.nextNegedge;
    await clk.nextNegedge;

    rdEn.put(1);

    expect(fifo.error!.value.toBool(), true);

    Simulator.endSimulation();
    await Simulator.simulationEnded;
  });

  test('fifo overflow error', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);

    final wrEn = Logic()..put(0);
    final rdEn = Logic()..put(0);
    final wrData = Logic(width: 32);

    final fifo = Fifo(
      clk,
      reset,
      writeEnable: wrEn,
      readEnable: rdEn,
      writeData: wrData,
      generateError: true,
      depth: 3,
    );

    await fifo.build();

    unawaited(Simulator.run());

    // a little reset flow
    await clk.nextNegedge;
    reset.put(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.put(0);
    await clk.nextNegedge;
    await clk.nextNegedge;

    wrEn.put(1);
    wrData.put(0xdead);

    expect(fifo.error!.value.toBool(), false);

    await clk.nextPosedge;
    expect(fifo.error!.value.toBool(), false);
    await clk.nextPosedge;
    expect(fifo.error!.value.toBool(), false);
    await clk.nextPosedge;
    expect(fifo.error!.value.toBool(), true);
    await clk.nextPosedge;

    Simulator.endSimulation();
    await Simulator.simulationEnded;
  });

  test('fifo empty bypass', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);

    final wrEn = Logic()..put(0);
    final rdEn = Logic()..put(0);
    final wrData = Logic(width: 32);

    final fifo = Fifo(
      clk,
      reset,
      writeEnable: wrEn,
      readEnable: rdEn,
      writeData: wrData,
      depth: 3,
      generateBypass: true,
      generateError: true,
    );

    final rdData = fifo.readData;

    await fifo.build();

    unawaited(Simulator.run());

    // a little reset flow
    await clk.nextNegedge;
    reset.put(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.put(0);
    await clk.nextNegedge;
    await clk.nextNegedge;

    fifo.error!.posedge.listen((event) {
      fail('error signal detected!');
    });

    wrEn.put(1);
    wrData.put(0xfeedbeef);
    rdEn.put(1);

    expect(rdData.value.toInt(), 0xfeedbeef);

    await clk.nextNegedge;

    wrData.put(0xdeadbeef);
    expect(rdData.value.toInt(), 0xdeadbeef);

    await clk.nextNegedge;

    Simulator.endSimulation();
    await Simulator.simulationEnded;
  });

  test('fifo full write and read simultaneously', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);

    final wrEn = Logic()..put(0);
    final rdEn = Logic()..put(0);
    final wrData = Logic(width: 32);

    final fifo = Fifo(
      clk,
      reset,
      writeEnable: wrEn,
      readEnable: rdEn,
      writeData: wrData,
      depth: 3,
      generateBypass: true,
      generateError: true,
    );

    final rdData = fifo.readData;

    await fifo.build();

    unawaited(Simulator.run());

    // a little reset flow
    await clk.nextNegedge;
    reset.put(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.put(0);
    await clk.nextNegedge;
    await clk.nextNegedge;

    // let it fill for a while
    wrEn.put(1);
    wrData.put(0xfeedbeef);

    while (!fifo.full.value.toBool()) {
      await clk.nextNegedge;
    }

    rdEn.put(1);

    expect(fifo.error!.value.toBool(), false);

    await clk.nextNegedge;
    expect(rdData.value.toInt(), 0xfeedbeef);
    expect(fifo.error!.value.toBool(), false);

    await clk.nextNegedge;
    expect(rdData.value.toInt(), 0xfeedbeef);
    expect(fifo.error!.value.toBool(), false);

    await clk.nextNegedge;
    expect(fifo.error!.value.toBool(), false);

    Simulator.endSimulation();
    await Simulator.simulationEnded;
  });

  group('fifo peek', () {
    Future<void> testPeek({required bool generateBypass}) async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic()..put(0);

      final wrEn = Logic()..put(0);
      final rdEn = Logic()..put(0);
      final wrData = Logic(width: 32);

      final fifo = Fifo(clk, reset,
          writeEnable: wrEn,
          readEnable: rdEn,
          writeData: wrData,
          depth: 3,
          generateBypass: generateBypass);

      final rdData = fifo.readData;

      await fifo.build();

      unawaited(Simulator.run());

      // a little reset flow
      await clk.nextNegedge;
      reset.put(1);
      await clk.nextNegedge;
      await clk.nextNegedge;
      reset.put(0);
      await clk.nextNegedge;
      await clk.nextNegedge;

      wrEn.put(1);
      wrData.put(0xfeedbeef);

      // peek immediately, no bypass so can't see
      expect(rdData.value.toInt(), generateBypass ? 0xfeedbeef : 0);

      await clk.nextNegedge;
      wrEn.put(0);

      // peek after wrEn drops
      expect(rdData.value.toInt(), 0xfeedbeef);

      await clk.nextNegedge;

      // peek at stable
      expect(rdData.value.toInt(), 0xfeedbeef);

      Simulator.endSimulation();
      await Simulator.simulationEnded;
    }

    test('no bypass', () async {
      await testPeek(generateBypass: false);
    });

    test('with bypass', () async {
      await testPeek(generateBypass: true);
    });
  });

  group('fifo checker', () {
    group('underflow', () {
      Future<void> underflowTest({required bool generateBypass}) async {
        final fifoTest = FifoTest(generateBypass: generateBypass,
            (clk, reset, wrEn, wrData, rdEn, rdData) async {
          wrEn.put(1);
          wrData.put(0x111);

          rdEn.put(1);

          await clk.nextNegedge;

          wrEn.put(0);

          await clk.nextNegedge;
          await clk.nextNegedge;
        });

        FifoChecker(fifoTest.fifo, enableEndOfTestEmptyCheck: false);

        fifoTest.printLevel = Level.OFF;

        try {
          await fifoTest.start();
          fail('Did not fail.');
        } on Exception catch (_) {
          expect(fifoTest.failureDetected, true);
        }
      }

      test('without bypass', () async {
        await underflowTest(generateBypass: false);
      });

      test('with bypass', () async {
        await underflowTest(generateBypass: true);
      });
    });

    test('overflow', () async {
      final fifoTest = FifoTest((clk, reset, wrEn, wrData, rdEn, rdData) async {
        wrEn.put(1);
        wrData.put(0x111);

        await clk.nextNegedge;
        await clk.nextNegedge;
        await clk.nextNegedge;
        await clk.nextNegedge;
      });

      FifoChecker(fifoTest.fifo, enableEndOfTestEmptyCheck: false);

      fifoTest.printLevel = Level.OFF;

      try {
        await fifoTest.start();
        fail('Did not fail.');
      } on Exception catch (_) {
        expect(fifoTest.failureDetected, true);
      }
    });

    test('non-empty at end of test', () async {
      final fifoTest = FifoTest((clk, reset, wrEn, wrData, rdEn, rdData) async {
        wrEn.put(1);
        wrData.put(0x111);

        await clk.nextNegedge;

        wrEn.put(0);

        await clk.nextNegedge;
      });

      FifoChecker(fifoTest.fifo);

      fifoTest.printLevel = Level.OFF;

      try {
        await fifoTest.start();
        fail('Did not fail.');
      } on Exception catch (_) {
        expect(fifoTest.failureDetected, true);
      }
    });
  });

  test('fifo logger', () async {
    final fifoTest = FifoTest((clk, reset, wrEn, wrData, rdEn, rdData) async {
      wrEn.put(1);
      wrData.put(0x111);

      await clk.nextNegedge;

      wrEn.put(0);

      await clk.nextNegedge;

      wrEn.put(1);
      wrData.put(0x222);

      rdEn.put(1);

      await clk.nextNegedge;

      wrEn.put(0);

      await clk.nextNegedge;

      rdEn.put(0);

      await clk.nextNegedge;
    });

    Directory('tmp_test').createSync();

    final tracker =
        FifoTracker(fifoTest.fifo, outputFolder: 'tmp_test', dumpTable: false);

    Simulator.registerEndOfSimulationAction(() async => tracker.terminate());

    await fifoTest.start();

    final trackerResults =
        json.decode(File(tracker.jsonFileName).readAsStringSync());
    // ignore: avoid_dynamic_calls
    final records = trackerResults['records'];
    // ignore: avoid_dynamic_calls
    expect(records[0]['Time'], '55');
    // ignore: avoid_dynamic_calls
    expect(records[1]['Occupancy'], '2');
    // ignore: avoid_dynamic_calls
    expect(records[2]['Data'], "32'h111");
    // ignore: avoid_dynamic_calls
    expect(records[3]['Command'], 'RD');

    File(tracker.jsonFileName).deleteSync();
  });
}

class FifoTest extends Test {
  late final Fifo fifo;

  final clk = SimpleClockGenerator(10).clk;
  final reset = Logic()..put(0);

  final wrEn = Logic()..put(0);
  final rdEn = Logic()..put(0);
  final wrData = Logic(width: 32);

  FifoTest(
    this.content, {
    String name = 'fifoTest',
    bool generateBypass = false,
  }) : super(name) {
    fifo = Fifo(
      clk,
      reset,
      writeEnable: wrEn,
      readEnable: rdEn,
      writeData: wrData,
      depth: 3,
      generateBypass: generateBypass,
    );
  }

  final Future<void> Function(Logic clk, Logic reset, Logic wrEn, Logic wrData,
      Logic rdEn, Logic rdData) content;

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('counter_test');

    // a little reset flow
    await clk.nextNegedge;
    reset.put(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.put(0);
    await clk.nextNegedge;
    await clk.nextNegedge;

    await content(clk, reset, wrEn, wrData, rdEn, fifo.readData);

    obj.drop();
  }
}
