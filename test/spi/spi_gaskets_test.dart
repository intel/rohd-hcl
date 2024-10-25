// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_gaskets_test.dart
// Tests for SPI gaskets, main and sub.
//
// 2024 October 10
// Author: Roberto Torres <roberto.torres@intel.com>

import 'dart:async';
// import 'dart:convert';
import 'dart:io';

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

  String get outFolder => 'tmp_test/spiMain/$name/';

  final Future<void> Function(SpiMainTest test) stimulus;

  SpiMainTest(this.stimulus, super.name) : super() {
    intf = SpiInterface(dataLength: 8);

    sub = SpiSubAgent(intf: intf, parent: this);

    monitor = SpiMonitor(intf: intf, parent: this);

    Directory(outFolder).createSync(recursive: true);

    final tracker =
        SpiTracker(intf: intf, dumpTable: true, outputFolder: outFolder);

    clk = SimpleClockGenerator(10).clk;

    // initialize the bus with 00
    final busData = Logic(width: 8)..inject(0x00);
    reset = Logic();
    starts = Logic();

    main = SpiMain(busData, intf, clk: clk, reset: reset, start: starts);

    Simulator.registerEndOfSimulationAction(() async {
      await tracker.terminate();

      //   // final jsonStr =
      //   //      File('$outFolder/spiTracker.tracker.json').readAsStringSync();
      //   // final jsonContents = json.decode(jsonStr);

      //   // // ignore: avoid_dynamic_calls
      //   // expect(jsonContents['records'].length, 2);

      //   //Directory(outFolder).deleteSync(recursive: true);
      // });
    });

    monitor.stream.listen(tracker.record);
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('SpiMainTestObj');

    // reset flow
    reset.inject(true);
    starts.inject(false);
    await clk.waitCycles(1);
    reset.inject(false);
    //await clk.waitCycles(2);
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
        SpiTracker(intf: intf, dumpTable: true, outputFolder: outFolder);

    Simulator.registerEndOfSimulationAction(() async {
      await tracker.terminate();

      // final jsonStr =
      //      File('$outFolder/spiTracker.tracker.json').readAsStringSync();
      // final jsonContents = json.decode(jsonStr);

      // // ignore: avoid_dynamic_calls
      // expect(jsonContents['records'].length, 2);

      //Directory(outFolder).deleteSync(recursive: true);
    });

    monitor.stream.listen(tracker.record);
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('SpiSubTestObj');

    // reset flow
    reset.inject(true);
    await clk.waitCycles(1);
    reset.inject(false);
    //await clk.waitCycles(1);
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
        SpiTracker(intf: intf, dumpTable: true, outputFolder: outFolder);

    clk = SimpleClockGenerator(10).clk;

    // initialize main
    resetMain = Logic();
    busInMain = Logic(width: 8);
    starts = Logic();

    main = SpiMain(busInMain, intf, clk: clk, reset: resetMain, start: starts);

    //init sub
    resetSub = Logic();
    busInSub = Logic(width: 8);
    sub = SpiSub(intf: intf, busIn: busInSub, reset: resetSub);

    Simulator.registerEndOfSimulationAction(() async {
      await tracker.terminate();

      //   // final jsonStr =
      //   //      File('$outFolder/spiTracker.tracker.json').readAsStringSync();
      //   // final jsonContents = json.decode(jsonStr);

      //   // // ignore: avoid_dynamic_calls
      //   // expect(jsonContents['records'].length, 2);

      //   //Directory(outFolder).deleteSync(recursive: true);
      // });
    });

    monitor.stream.listen(tracker.record);
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('SpiPairTestObj');

    // reset flow
    resetMain.inject(true);
    resetSub.inject(true);
    starts.inject(false);
    // extra cycles for easy waveform visibility
    await clk.waitCycles(3);
    resetMain.inject(false);
    resetSub.inject(false);
    busInSub.inject(00);

    await stimulus(this);

    obj.drop();
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  group('main gasket tests', () {
    Future<void> runMainTest(SpiMainTest spiMainTest,
        {bool dumpWaves = true}) async {
      Simulator.setMaxSimTime(3000);

      if (dumpWaves) {
        await spiMainTest.main.build();
        WaveDumper(spiMainTest.main,
            outputPath: '${spiMainTest.outFolder}/waves.vcd');
      }
      await spiMainTest.start();
    }

    Future<void> sendSubPacket(SpiMainTest test, LogicValue data) async {
      test.sub.sequencer.add(SpiPacket(data: data));
      test.starts.inject(true);
      await test.clk.waitCycles(1);
      test.starts.inject(false);
      await test.clk.waitCycles(7);
    }

    test('simple transfers no gap', () async {
      await runMainTest(SpiMainTest((test) async {
        await sendSubPacket(test, LogicValue.ofInt(0x72, 8));
        expect(test.main.busOut.value.toInt(), 0x72);

        // await test.clk.nextNegedge;
        await sendSubPacket(test, LogicValue.ofInt(0xCD, 8));
        expect(test.main.busOut.value.toInt(), 0xCD);

        // await test.clk.nextNegedge;
        await sendSubPacket(test, LogicValue.ofInt(0x56, 8));
        expect(test.main.busOut.value.toInt(), 0x56);

        // await test.clk.nextNegedge;
        await sendSubPacket(test, LogicValue.ofInt(0xE2, 8));
        expect(test.main.busOut.value.toInt(), 0xE2);
        await test.clk.waitCycles(4);
      }, 'testMainA'));
    });

    test('simple transfers with gaps', () async {
      await runMainTest(SpiMainTest((test) async {
        await sendSubPacket(test, LogicValue.ofInt(0x72, 8));

        expect(test.main.busOut.value.toInt(), 0x72);
        await test.clk.waitCycles(3);

        await sendSubPacket(test, LogicValue.ofInt(0xCD, 8)); // 1100 1101

        expect(test.main.busOut.value.toInt(), 0xCD);
        await test.clk.waitCycles(4);

        await sendSubPacket(test, LogicValue.ofInt(0x56, 8));

        expect(test.main.busOut.value.toInt(), 0x56);
        await test.clk.waitCycles(4);
      }, 'testMainB'));
    });
  });

  group('sub gasket tests', () {
    Future<void> runSubTest(SpiSubTest spiSubTest,
        {bool dumpWaves = true}) async {
      Simulator.setMaxSimTime(6000);
      final mod = SpiTop(spiSubTest.intf, spiSubTest);
      if (dumpWaves) {
        await mod.build();
        WaveDumper(mod, outputPath: '${spiSubTest.outFolder}/waves.vcd');
      }

      await spiSubTest.start();
    }

    test('sub tx with busIn and reset', () async {
      await runSubTest(SpiSubTest((test) async {
        test.main.sequencer
            .add(SpiPacket(data: LogicValue.ofInt(0xCD, 8))); // 1100 1101
        test.main.sequencer
            .add(SpiPacket(data: LogicValue.ofInt(0x2E, 8))); // 0010 1110
        await test.intf.sclk.waitCycles(16);
        await test.clk.waitCycles(1);
        test.busIn.inject(0x19); // 0001 1001 need to change to LSB.
        test.reset.inject(true);
        await test.clk.nextChanged;
        test.reset.inject(false);

        await test.clk.waitCycles(1);
        test.main.sequencer.add(SpiPacket(data: LogicValue.ofInt(0x00, 8)));
        await test.clk.waitCycles(10);
      }, 'testSubA'));
    });
  });

  group('pair of gaskets tests', () {
    Future<void> runPairTest(SpiPairTest spiPairTest,
        {bool dumpWaves = true}) async {
      Simulator.setMaxSimTime(6000);
      final mod = SpiTop(spiPairTest.intf, null);
      if (dumpWaves) {
        await mod.build();
        WaveDumper(mod, outputPath: '${spiPairTest.outFolder}/waves.vcd');
      }
      await spiPairTest.start();
    }

    Future<void> sendMainPacket(SpiPairTest test, LogicValue data) async {
      test.busInMain.inject(data);
      test.starts.inject(true);
      await test.clk.waitCycles(1);
      test.starts.inject(false);
      await test.clk.waitCycles(7);
    }

    Future<void> sendSubPacket(SpiPairTest test, LogicValue data) async {
      test.busInSub.inject(data);
      test.starts.inject(true);
      await test.clk.waitCycles(1);
      test.starts.inject(false);
      await test.clk.waitCycles(7);
    }

    test('simple transfers no gap', () async {
      await runPairTest(SpiPairTest((test) async {
        await sendMainPacket(test, LogicValue.ofInt(0x72, 8)); // 0111 0010
        await sendMainPacket(test, LogicValue.ofInt(0x00, 8)); // 0111 0010
        expect(test.sub.busOut.value.toInt(), 0x72);
        await test.clk.waitCycles(2);
        // await sendMainPacket(test, LogicValue.ofInt(0xCD, 8));
        // expect(test.main.busOut.value.toInt(), 0xCD);
        // await sendMainPacket(test, LogicValue.ofInt(0x56, 8));
        // expect(test.main.busOut.value.toInt(), 0x56);
      }, 'testPairA'));
    });

    // test('simple transfers with gaps', () async {
    //   await runBothTest(SpiBothTest((test) async {
    //     await sendMainPacket(test, LogicValue.ofInt(0x72, 8));
    //     await test.clk.waitCycles(1);
    //     expect(test.main.busOut.value.toInt(), 0x72);
    //     await sendMainPacket(test, LogicValue.ofInt(0xCD, 8));
    //     await test.clk.waitCycles(4);
    //     expect(test.main.busOut.value.toInt(), 0xCD);
    //     await sendMainPacket(test, LogicValue.ofInt(0x56, 8));
    //     await test.clk.waitCycles(1);
    //     expect(test.main.busOut.value.toInt(), 0x56);
    //   }, 'testPairB'));
    // });
  });
}
