// Copyright (C) 2023-2024 Intel Corporation
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
    await Test.reset();
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

    await Simulator.endSimulation();
  });

  test('fifo with depth 1', () async {
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
      depth: 1,
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
    wrData.put(0xdeadbeef);

    await clk.nextNegedge;

    wrEn.put(0);
    wrData.put(0);
    expect(fifo.full.value.toBool(), true);
    expect(fifo.error!.value.toBool(), false);

    await clk.nextNegedge;

    rdEn.put(1);
    expect(fifo.readData.value.toInt(), 0xdeadbeef);

    await clk.nextNegedge;
    rdEn.put(0);

    expect(fifo.empty.value.toBool(), true);
    expect(fifo.error!.value.toBool(), false);

    await Simulator.endSimulation();
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

    await Simulator.endSimulation();
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

    await Simulator.endSimulation();
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

    await Simulator.endSimulation();
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

    await Simulator.endSimulation();
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

    await Simulator.endSimulation();
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

      await Simulator.endSimulation();
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

    test('invalid value on port', () async {
      final fifoTest = FifoTest((clk, reset, wrEn, wrData, rdEn, rdData) async {
        wrEn.put(1);
        wrData.put(0x111);

        await clk.nextNegedge;
        wrEn.put(LogicValue.x);
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

    test('checker fails on error signal assertion', () async {
      final fifoTest = FifoTest(generateError: true,
          (clk, reset, wrEn, wrData, rdEn, rdData) async {
        // Cause underflow error: read when empty
        rdEn.put(1);
        await clk.waitCycles(3);
      });

      FifoChecker(fifoTest.fifo);

      var errorSignalCaught = false;
      final subscription = Logger.root.onRecord.listen((record) {
        if (record.level == Level.SEVERE &&
            record.message.contains('error signal was asserted')) {
          errorSignalCaught = true;
        }
      });

      fifoTest.printLevel = Level.OFF;

      try {
        await fifoTest.start();
        fail('Did not fail.');
      } on Exception catch (_) {
        expect(fifoTest.failureDetected, true);
      }

      expect(errorSignalCaught, isTrue);

      await subscription.cancel();
    });
  });

  test('sampling time', () async {
    final fifoTest = FifoTest((clk, reset, wrEn, wrData, rdEn, rdData) async {
      wrEn.inject(1);
      wrData.inject(0x111);

      await clk.nextPosedge;
      await clk.nextPosedge;
      wrEn.inject(0);
      rdEn.inject(1);
      await clk.nextPosedge;
      await clk.nextPosedge;
      rdEn.inject(0);
      await clk.nextPosedge;
      await clk.nextPosedge;
    });

    FifoChecker(fifoTest.fifo, parent: fifoTest);

    fifoTest.printLevel = Level.OFF;

    await fifoTest.start();
    expect(fifoTest.failureDetected, false);
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
        json.decode(File(tracker.jsonFileName).readAsStringSync())
            as Map<String, dynamic>;
    final records =
        List<Map<String, dynamic>>.from(trackerResults['records'] as List);

    expect(records[0]['Time'], '55');
    expect(records[1]['Occupancy'], '2');
    expect(records[2]['Data'], "32'h111");
    expect(records[3]['Command'], 'RD');

    File(tracker.jsonFileName).deleteSync();
  });

  group('fifo initial values', () {
    Future<List<LogicValue>> setupAndDumpFifo(List<dynamic> initialValues,
        {bool dumpWaves = false}) async {
      final fifoTest = InitValFifoTest(initialValues);

      await fifoTest.fifo.build();

      if (dumpWaves) {
        WaveDumper(fifoTest.fifo);
      }

      await fifoTest.start();

      return fifoTest.readValues;
    }

    test('full initial values is full, not empty, correct vals, correct occ',
        () async {
      final vals = await setupAndDumpFifo([1, 2, 3, 4]);
      expect(vals.map((e) => e.toInt()).toList(), [1, 2, 3, 4]);
    });

    test(
        'partial initial values not full, not empty, correct vals, correct occ',
        () async {
      final vals = await setupAndDumpFifo([1, 3]);
      expect(vals.map((e) => e.toInt()).toList(), [1, 3]);
    });

    test('too many initial values throws', () async {
      try {
        await setupAndDumpFifo([1, 2, 3, 4, 5]);
        fail('Did not throw');
      } on Exception catch (_) {
        // pass
      }
    });

    test('initial values is empty, not full, 0 occ', () async {
      final vals = await setupAndDumpFifo([]);
      expect(vals, isEmpty);
    });
  });

  test('typed fifo', () {
    final fifo = Fifo(
      Logic(),
      Logic(),
      writeEnable: Logic(),
      readEnable: Logic(),
      writeData: ExampleStruct(),
      depth: 4,
    );

    expect(fifo.readData, isA<ExampleStruct>());
  });
}

class ExampleStruct extends LogicStructure {
  ExampleStruct({super.name})
      : super([
          Logic(name: 'a', width: 8),
          Logic(name: 'b', width: 16),
          Logic(name: 'c', width: 32)
        ]);

  @override
  ExampleStruct clone({String? name}) => ExampleStruct(name: name);
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
    bool generateError = false,
  }) : super(name) {
    fifo = Fifo(
      clk,
      reset,
      writeEnable: wrEn,
      readEnable: rdEn,
      writeData: wrData,
      depth: 3,
      generateBypass: generateBypass,
      generateError: generateError,
    );
  }

  final Future<void> Function(Logic clk, Logic reset, Logic wrEn, Logic wrData,
      Logic rdEn, Logic rdData) content;

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('fifo_test');

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

class InitValFifoTest extends Test {
  late final Fifo fifo;

  final clk = SimpleClockGenerator(10).clk;
  final reset = Logic();
  final readEnable = Logic();

  final List<dynamic> initialValues;

  final readValues = <LogicValue>[];

  late final bool expectFullAfterReset = initialValues.length == fifo.depth;

  InitValFifoTest(this.initialValues) : super('simple_fifo_test') {
    fifo = Fifo(
      clk,
      reset,
      writeEnable: Const(0),
      writeData: Const(0, width: 8),
      readEnable: readEnable,
      depth: 4,
      generateOccupancy: true,
      generateError: true,
      initialValues: initialValues,
    );

    FifoChecker(fifo, parent: this);
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('fifo_test');

    reset.inject(0);
    readEnable.inject(0);
    await clk.waitCycles(2);
    reset.inject(1);
    await clk.waitCycles(2);
    reset.inject(0);
    await clk.waitCycles(2);

    if (expectFullAfterReset) {
      if (!fifo.full.previousValue!.toBool()) {
        logger.severe('FIFO was not full after reset as expected!');
      }
    }

    await clk.waitCycles(1);

    readEnable.inject(1);
    for (var i = 0; i < initialValues.length; i++) {
      await clk.nextPosedge;

      if (fifo.empty.previousValue!.toBool()) {
        logger.severe('FIFO was empty unexpectedly!');
      }

      final expectedOccupancy = initialValues.length - i;
      final actualOccupancy = fifo.occupancy!.previousValue!.toInt();
      if (actualOccupancy != expectedOccupancy) {
        logger.severe('FIFO occupancy was $actualOccupancy'
            ' but expected $expectedOccupancy');
      }

      readValues.add(fifo.readData.previousValue!);
    }
    readEnable.inject(0);

    await clk.waitCycles(3);

    obj.drop();
  }
}
