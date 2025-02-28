// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_gaskets_test.dart
// Tests for SPI gaskets, main and sub.
//
// 2024 October 10
// Author: Roberto Torres <roberto.torres@intel.com>

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

class SpiMainTest extends Test {
  late final SpiInterface intf;
  late final SpiSubAgent sub;
  late final SpiMonitor monitor;
  late final SpiMain main;
  late final Logic reset;
  late final Logic starts;
  late final Logic clk;
  late final Logic busInMain;

  String get outFolder => 'tmp_test/spiMain/$name/';

  final Future<void> Function(SpiMainTest test) stimulus;

  SpiMainTest(this.stimulus, super.name) : super() {
    intf = SpiInterface(dataLength: 8);

    sub = SpiSubAgent(intf: intf, parent: this);

    monitor = SpiMonitor(intf: intf, parent: this);

    Directory(outFolder).createSync(recursive: true);

    final tracker =
        SpiTracker(intf: intf, dumpTable: false, outputFolder: outFolder);

    SpiChecker(intf, parent: this);

    clk = SimpleClockGenerator(10).clk;

    // initialize the bus with 00
    busInMain = Logic(width: 8)..inject(0x00);
    reset = Logic();
    starts = Logic();

    main =
        SpiMain(intf, busIn: busInMain, clk: clk, reset: reset, start: starts);

    Simulator.registerEndOfSimulationAction(() async {
      await tracker.terminate();
      const numTransfers = 4;
      final jsonStr =
          File('$outFolder/spiTracker.tracker.json').readAsStringSync();
      final jsonContents = json.decode(jsonStr);
      // ignore: avoid_dynamic_calls
      expect(jsonContents['records'].length, 2 * numTransfers);

      Directory(outFolder).deleteSync(recursive: true);
    });

    monitor.stream.listen(tracker.record);
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('SpiMainTestObj');

    // reset flow
    await clk.waitCycles(1);
    reset.inject(true);
    starts.inject(false);
    await clk.waitCycles(1);
    reset.inject(false);
    await clk.waitCycles(1);
    await stimulus(this);

    obj.drop();
  }
}

class SpiSubTest extends Test {
  late final SpiInterface intf;
  late final SpiMainAgent main;
  late final SpiMonitor monitor;
  late final SpiSub sub;
  late final Logic reset;
  late final Logic clk;
  late final Logic busIn;

  String get outFolder => 'tmp_test/spiSub/$name/';

  final Future<void> Function(SpiSubTest test) stimulus;

  SpiSubTest(this.stimulus, super.name) : super() {
    intf = SpiInterface(dataLength: 8);

    clk = SimpleClockGenerator(10).clk;

    main = SpiMainAgent(intf: intf, parent: this, clk: clk);

    monitor = SpiMonitor(intf: intf, parent: this);

    busIn = Logic(width: 8);

    reset = Logic();

    sub = SpiSub(intf: intf, busIn: busIn, reset: reset);

    Directory(outFolder).createSync(recursive: true);

    final tracker =
        SpiTracker(intf: intf, dumpTable: false, outputFolder: outFolder);

    SpiChecker(intf, parent: this);

    Simulator.registerEndOfSimulationAction(() async {
      await tracker.terminate();
      Directory(outFolder).deleteSync(recursive: true);
    });

    monitor.stream.listen(tracker.record);
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('SpiSubTestObj');

    // reset flow
    busIn.inject(0x00);
    reset.inject(false);
    await clk.waitCycles(1);
    reset.inject(true);
    await clk.waitCycles(1);
    reset.inject(false);
    await stimulus(this);

    obj.drop();
  }
}

class SpiTop extends Module {
  SpiTop(SpiInterface intf, SpiSubTest? test, {super.name = 'spiTop'}) {
    addOutput('dummy') <= intf.sclk;
    if (test != null) {
      addOutput('clk') <= test.clk;
    }
  }
}

class SpiPairTest extends Test {
  late final SpiInterface intf;
  late final SpiMonitor monitor;
  late final SpiMain main;
  late final SpiSub sub;
  late final Logic clk;
  late final Logic resetMain;
  late final Logic resetSub;
  late final Logic busInMain;
  late final Logic busInSub;
  late final Logic starts;

  String get outFolder => 'tmp_test/spiPair/$name/';

  final Future<void> Function(SpiPairTest test) stimulus;

  SpiPairTest(this.stimulus, super.name) : super() {
    intf = SpiInterface(dataLength: 8);

    monitor = SpiMonitor(intf: intf, parent: this);

    Directory(outFolder).createSync(recursive: true);

    final tracker =
        SpiTracker(intf: intf, dumpTable: false, outputFolder: outFolder);

    SpiChecker(intf, parent: this);

    clk = SimpleClockGenerator(10).clk;

    // initialize main
    resetMain = Logic();
    busInMain = Logic(width: 8);
    starts = Logic();

    main = SpiMain(intf,
        busIn: busInMain, clk: clk, reset: resetMain, start: starts);

    //init sub
    resetSub = Logic();
    busInSub = Logic(width: 8);
    sub = SpiSub(intf: intf, busIn: busInSub, reset: resetSub);

    Simulator.registerEndOfSimulationAction(() async {
      await tracker.terminate();
      Directory(outFolder).deleteSync(recursive: true);
    });

    monitor.stream.listen(tracker.record);
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('SpiPairTestObj');

    // Initialize all inputs to initial state.
    // Just for waveform clarity.
    await clk.waitCycles(1);

    busInMain.inject(00);
    busInSub.inject(00);

    starts.inject(false);
    resetMain.inject(false);
    resetSub.inject(false);

    await clk.waitCycles(1);
    resetMain.inject(true);
    resetSub.inject(true);

    await clk.waitCycles(1);
    resetMain.inject(false);
    resetSub.inject(false);

    await clk.waitCycles(1);
    await stimulus(this);

    obj.drop();
  }
}

class SpiCheckerTest extends Test {
  late final SpiInterface intf;
  late final Logic clk;

  SpiCheckerTest(super.name) : super(printLevel: Level.OFF) {
    intf = SpiInterface(dataLength: 8);
    clk = SimpleClockGenerator(10).clk;

    SpiChecker(intf, parent: this);

    intf.csb <= Const(0);
    intf.sclk <= clk;
    intf.mosi <= ~clk;
    intf.miso <= clk;
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('SpiPairTestObj');

    await clk.waitCycles(2);

    obj.drop();
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  group('main gasket tests', () {
    Future<void> runMainTest(SpiMainTest spiMainTest,
        {bool dumpWaves = false}) async {
      Simulator.setMaxSimTime(3000);

      if (dumpWaves) {
        await spiMainTest.main.build();
        WaveDumper(spiMainTest.main,
            outputPath: '${spiMainTest.outFolder}/waves.vcd');
      }
      await spiMainTest.start();
    }

    test('simple transfers no gap', () async {
      await runMainTest(SpiMainTest((test) async {
        Future<void> sendMainData(SpiMainTest test, int data) async {
          test.busInMain.inject(LogicValue.ofInt(data, test.intf.dataLength));
          test.reset.inject(true);
          Simulator.registerAction(
              Simulator.time + 2, () => test.reset.inject(false));
          test.starts.inject(true);
          await test.clk.waitCycles(1);
          test.starts.inject(false);
          await test.clk.waitCycles(7);
        }

        Future<void> sendSubPacket(SpiMainTest test, LogicValue data) async {
          test.sub.sequencer.add(SpiPacket(data: data));
          await sendMainData(test, 0x00);
        }

        var clkCount = 0;
        test.clk.negedge.listen((event) {
          clkCount++;
        });
        final txPeriod = test.intf.dataLength;

        await sendSubPacket(test, LogicValue.ofInt(0x72, 8));
        expect(test.main.busOut.previousValue?.toInt(), 0x72);
        expect(clkCount, txPeriod);

        await sendSubPacket(test, LogicValue.ofInt(0xCD, 8));
        expect(test.main.busOut.previousValue?.toInt(), 0xCD);
        expect(clkCount, 2 * txPeriod);

        await sendSubPacket(test, LogicValue.ofInt(0x56, 8));
        expect(test.main.busOut.previousValue?.toInt(), 0x56);
        expect(clkCount, 3 * txPeriod);

        await sendSubPacket(test, LogicValue.ofInt(0xE2, 8));
        expect(test.main.busOut.previousValue?.toInt(), 0xE2);
        expect(clkCount, 4 * txPeriod);

        await test.clk.waitCycles(4);
      }, 'testMainA'));
    });

    test('simple transfers with gaps', () async {
      await runMainTest(SpiMainTest((test) async {
        Future<void> sendMainData(SpiMainTest test, int data) async {
          test.busInMain.inject(LogicValue.ofInt(data, test.intf.dataLength));
          test.reset.inject(true);
          await test.clk.nextPosedge;
          test.reset.inject(false);
          test.starts.inject(true);
          await test.clk.waitCycles(1);
          test.starts.inject(false);
          await test.clk.waitCycles(7);
        }

        Future<void> sendSubPacket(SpiMainTest test, LogicValue data) async {
          test.sub.sequencer.add(SpiPacket(data: data));
          await sendMainData(test, 0x00);
        }

        var clkCount = 0;
        test.clk.negedge.listen((event) {
          clkCount++;
        });

        final clkPeriod = test.intf.dataLength + 1;
        await sendSubPacket(test, LogicValue.ofInt(0x72, 8));

        expect(test.main.busOut.value.toInt(), 0x72);
        expect(test.main.done.value.toBool(), true);
        expect(clkCount, clkPeriod);

        await test.clk.waitCycles(3);
        expect(clkCount, clkPeriod + 3);

        await sendSubPacket(test, LogicValue.ofInt(0xCD, 8)); // 1100 1101
        expect(test.main.busOut.value.toInt(), 0xCD);
        expect(test.main.done.value.toBool(), true);
        expect(clkCount, (2 * clkPeriod) + 3);

        await test.clk.waitCycles(4);

        await sendSubPacket(test, LogicValue.ofInt(0x56, 8));
        expect(test.main.busOut.value.toInt(), 0x56);
        expect(test.main.done.value.toBool(), true);
        expect(clkCount, (3 * clkPeriod) + 7);

        await test.clk.waitCycles(4);

        await sendSubPacket(test, LogicValue.ofInt(0xAB, 8));
        expect(test.main.busOut.value.toInt(), 0xAB);
        expect(test.main.done.value.toBool(), true);
        expect(clkCount, (4 * clkPeriod) + 11);

        await test.clk.waitCycles(4);
      }, 'testMainB'));
    });
  });

  group('sub gasket tests', () {
    Future<void> runSubTest(SpiSubTest spiSubTest,
        {bool dumpWaves = false}) async {
      Simulator.setMaxSimTime(3000);
      final mod = SpiTop(spiSubTest.intf, spiSubTest);
      if (dumpWaves) {
        await mod.build();
        WaveDumper(mod, outputPath: '${spiSubTest.outFolder}/waves.vcd');
      }

      await spiSubTest.start();
    }

    test('sub tx busOut correctly no gaps', () async {
      await runSubTest(SpiSubTest((test) async {
        test.main.sequencer
            .add(SpiPacket(data: LogicValue.ofInt(0xCD, 8))); // 1100 1101
        test.main.sequencer
            .add(SpiPacket(data: LogicValue.ofInt(0x83, 8))); // 1000 0011
        test.main.sequencer
            .add(SpiPacket(data: LogicValue.ofInt(0xE2, 8))); // 1110 0010
        test.main.sequencer.add(SpiPacket(data: LogicValue.ofInt(0x00, 8)));

        await test.clk.waitCycles(8);

        await test.clk.nextPosedge;
        expect(test.sub.busOut.value.toInt(), 0xCD);

        await test.clk.waitCycles(7);
        await test.clk.nextPosedge;
        expect(test.sub.busOut.value.toInt(), 0x83);

        await test.clk.waitCycles(7);
        await test.clk.nextPosedge;
        expect(test.sub.busOut.value.toInt(), 0xE2);

        await test.clk.waitCycles(7);
        await test.clk.nextPosedge;
        expect(test.sub.busOut.value.toInt(), 0x00);
        await test.clk.waitCycles(4);
      }, 'testSubA'));
    });

    test('sub tx busOut correctly with gaps', () async {
      await runSubTest(SpiSubTest((test) async {
        test.main.sequencer
            .add(SpiPacket(data: LogicValue.ofInt(0xCD, 8))); // 1100 1101

        await test.clk.waitCycles(8);
        expect(test.sub.done?.value.toBool(), false);
        await test.clk.nextPosedge;
        expect(test.sub.busOut.value.toInt(), 0xCD);
        expect(test.sub.done?.value.toBool(), true);
        //gap
        await test.clk.waitCycles(7);

        test.main.sequencer
            .add(SpiPacket(data: LogicValue.ofInt(0x72, 8))); // 0111 0010
        await test.clk.waitCycles(8);

        await test.clk.nextPosedge;
        expect(test.sub.busOut.value.toInt(), 0x72);

        // gap
        await test.clk.waitCycles(2);

        test.main.sequencer.add(SpiPacket(data: LogicValue.ofInt(0xAC, 8)));
        await test.clk.waitCycles(8);

        await test.clk.nextPosedge;
        expect(test.sub.busOut.value.toInt(), 0xAC);

        // gap
        await test.clk.waitCycles(3);

        test.main.sequencer.add(SpiPacket(data: LogicValue.ofInt(0xE2, 8)));
        test.main.sequencer.add(SpiPacket(data: LogicValue.ofInt(0x00, 8)));
        await test.clk.waitCycles(8);

        await test.clk.nextPosedge;
        expect(test.sub.busOut.value.toInt(), 0xE2);

        // waiting for the read packet
        await test.clk.waitCycles(7);
        await test.clk.nextPosedge;
        expect(test.sub.busOut.value.toInt(), 0x00);
      }, 'testSubA'));
    });

    test('sub tx with no gaps, busIn and reset injects', () async {
      await runSubTest(SpiSubTest((test) async {
        test.main.sequencer.add(SpiPacket(data: LogicValue.ofInt(0xCD, 8)));
        test.main.sequencer.add(SpiPacket(data: LogicValue.ofInt(0x72, 8)));

        await test.clk.waitCycles(8);

        await test.clk.nextPosedge;
        expect(test.sub.busOut.value.toInt(), 0xCD);

        await test.clk.waitCycles(7);

        // read busOut here
        await test.clk.nextPosedge;
        expect(test.sub.busOut.value.toInt(), 0x72);

        // inject bus in on neg edge of same cycle
        await test.clk.nextNegedge;
        test.busIn.inject(0x19);
        test.main.sequencer.add(SpiPacket(data: LogicValue.ofInt(0x00, 8)));

        // trigger reset
        await test.clk.nextPosedge;
        test.reset.inject(true);
        await test.clk.waitCycles(1);
        test.reset.inject(false);

        await test.clk.waitCycles(7);

        await test.clk.nextPosedge;
        expect(test.sub.busOut.value.toInt(), 0x00);

        await test.clk.waitCycles(4);
      }, 'testSubA'));
    });
  });

  group('pair of gaskets tests', () {
    Future<void> runPairTest(SpiPairTest spiPairTest,
        {bool dumpWaves = false}) async {
      Simulator.setMaxSimTime(3000);
      final mod = SpiTop(spiPairTest.intf, null);
      if (dumpWaves) {
        await mod.build();
        WaveDumper(mod, outputPath: '${spiPairTest.outFolder}/waves.vcd');
      }
      await spiPairTest.start();
    }

    Future<void> sendMainData(SpiPairTest test, int data) async {
      test.busInMain.inject(LogicValue.ofInt(data, test.intf.dataLength));
      await test.clk.nextNegedge;
      test.resetMain.inject(true);
      await test.clk.nextPosedge;
      test.resetMain.inject(false);
      test.starts.inject(true);
      await test.clk.waitCycles(1);
      test.starts.inject(false);
      expect(test.sub.done?.value.toBool(), false);
      await test.clk.waitCycles(7);
    }

    Future<void> sendBothData(SpiPairTest test,
        {required int mainData, required int subData}) async {
      test.busInSub.inject(LogicValue.ofInt(subData, test.intf.dataLength));
      test.busInMain.inject(LogicValue.ofInt(mainData, test.intf.dataLength));
      await test.clk.nextNegedge;
      test.resetSub.inject(true);
      test.resetMain.inject(true);
      await test.clk.nextPosedge;
      test.resetSub.inject(false);
      test.resetMain.inject(false);
      test.starts.inject(true);
      await test.clk.waitCycles(1);
      test.starts.inject(false);
      await test.clk.waitCycles(7);
    }

    void checkMainBusOut(SpiPairTest test, int data) {
      if (test.main.busOut.value.toInt() != data) {
        test.logger.severe('main busOut: ${test.main.busOut.value}');
      }
    }

    void checkSubBusOut(SpiPairTest test, int data) {
      if (test.sub.busOut.value.toInt() != data) {
        test.logger.severe('sub busOut: ${test.sub.busOut.value}');
      }
    }

    test('main busIn injects, both busOut checks, no gaps', () async {
      await runPairTest(SpiPairTest((test) async {
        // Send main data.
        await sendMainData(test, 0x73); // 0111 0011
        // Check both busOuts on posEdge of 8th sclk/ negEdge of 8th CLK
        checkSubBusOut(test, 0x73);
        checkMainBusOut(test, 0x00);

        // Send new main data.
        await sendMainData(test, 0xCD); // 1100 1101

        // check both busOuts, main should equal previous main busIn data
        checkSubBusOut(test, 0xCD);
        checkMainBusOut(test, 0x73);

        // Send new, check both busOuts
        await sendMainData(test, 0xE2); // 1110 0010
        checkSubBusOut(test, 0xE2);
        checkMainBusOut(test, 0xCD);

        // Send new, check both busOuts
        await sendMainData(test, 0xB3); // 1011 0011
        checkSubBusOut(test, 0xB3);
        checkMainBusOut(test, 0xE2);

        // Send new, check both busOuts
        await sendMainData(test, 0x00); // 1011 0011
        checkSubBusOut(test, 0x00);
        checkMainBusOut(test, 0xB3);
      }, 'testPairA'));
    });

    test('main busIn injects, both busOut checks, with gaps', () async {
      await runPairTest(SpiPairTest((test) async {
        // Send main data.
        await sendMainData(test, 0x73); // 0111 0011
        // Check both busOuts on posEdge of 8th sclk/ negEdge of 8th CLK
        checkSubBusOut(test, 0x73);
        checkMainBusOut(test, 0x00);

        // 1 cycle gap
        await test.clk.waitCycles(1);

        // Send new main data.
        await sendMainData(test, 0xCD); // 1100 1101

        // check both busOuts, main should equal previous main busIn data
        checkSubBusOut(test, 0xCD);
        checkMainBusOut(test, 0x73);
        await test.clk.waitCycles(1);
        // Send new, check both busOuts
        await sendMainData(test, 0xE2); // 1110 0010
        checkSubBusOut(test, 0xE2);
        checkMainBusOut(test, 0xCD);
        await test.clk.waitCycles(3);
        // Send new, check both busOuts
        await sendMainData(test, 0xB3); // 1011 0011
        checkSubBusOut(test, 0xB3);
        checkMainBusOut(test, 0xE2);

        // with gaps
        await test.clk.waitCycles(1);

        await sendMainData(test, 0x15); // 0001 0101
        checkSubBusOut(test, 0x15);
        checkMainBusOut(test, 0xB3);

        await test.clk.waitCycles(4);

        await sendMainData(test, 0x2D); // 0010 1101
        checkSubBusOut(test, 0x2D);
        checkMainBusOut(test, 0x15);

        await test.clk.waitCycles(6);
        await sendMainData(test, 0x00);
        checkSubBusOut(test, 0x00);
        checkMainBusOut(test, 0x2D);
        await test.clk.waitCycles(4);
      }, 'testPairA'));
    });

    test('main and sub busIn, both busOut checks', () async {
      await runPairTest(SpiPairTest((test) async {
        // Send regular main data.
        // var mainData = Random().nextInt(256);
        // var subData = Random().nextInt(256);
        await sendBothData(test, mainData: 0x73, subData: 0x00); // 0111 0011
        checkSubBusOut(test, 0x73);
        checkMainBusOut(test, 0x00);

        await test.clk.waitCycles(1);

        // Send sub data with main 00 and check busOuts
        await sendBothData(test, mainData: 0x00, subData: 0x6A); // 0110 1010
        checkMainBusOut(test, 0x6A);
        checkSubBusOut(test, 0x00);

        await test.clk.waitCycles(2);

        await sendBothData(test, mainData: 0x50, subData: 0x82); // 1000 0010
        checkMainBusOut(test, 0x82);
        checkSubBusOut(test, 0x50);

        // await test.clk.waitCycles(4);

        await sendBothData(test, mainData: 0x33, subData: 0x7D); // 1000 0010
        checkMainBusOut(test, 0x7D);
        checkSubBusOut(test, 0x33);

        await test.clk.waitCycles(4);
      }, 'testPairA'));
    });
  });

  test('SpiChecker test', () async {
    final checkerTest = SpiCheckerTest('checkerTest');
    var sawError = false;

    Simulator.setMaxSimTime(200);

    try {
      await checkerTest.start();
    } on Exception {
      sawError = true;
    }

    expect(sawError, isTrue);

    await Simulator.endSimulation();
  });
}
