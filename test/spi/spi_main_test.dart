// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_main_test.dart
// Tests for SPI main gasket.
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

    main = SpiMain(intf, busIn: busData, clk: clk, reset: reset, start: starts);

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
    await clk.waitCycles(2);
    reset.inject(false);

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
      Simulator.setMaxSimTime(6000);

      if (dumpWaves) {
        await spiMainTest.main.build();
        WaveDumper(spiMainTest.main);
      }
      await spiMainTest.start();
    }

    Future<void> sendPacket(SpiMainTest test, LogicValue data) async {
      test.sub.sequencer.add(SpiPacket(data: data));
      test.starts.inject(true);
      await test.clk.waitCycles(1);
      test.starts.inject(false);
      await test.clk.waitCycles(7);
    }

    test('simple transfers no gap', () async {
      await runMainTest(SpiMainTest((test) async {
        await sendPacket(test, LogicValue.ofInt(0x72, 8));
        expect(test.main.busOut.value.toInt(), 0x72);
        await sendPacket(test, LogicValue.ofInt(0xCD, 8));
        expect(test.main.busOut.value.toInt(), 0xCD);
        await sendPacket(test, LogicValue.ofInt(0x56, 8));
        expect(test.main.busOut.value.toInt(), 0x56);
      }, 'testMainA'));
    });

    test('simple transfers with gaps', () async {
      await runMainTest(SpiMainTest((test) async {
        await sendPacket(test, LogicValue.ofInt(0x72, 8));
        await test.clk.waitCycles(1);
        expect(test.main.busOut.value.toInt(), 0x72);
        await sendPacket(test, LogicValue.ofInt(0xCD, 8));
        await test.clk.waitCycles(4);
        expect(test.main.busOut.value.toInt(), 0xCD);
        await sendPacket(test, LogicValue.ofInt(0x56, 8));
        await test.clk.waitCycles(1);
        expect(test.main.busOut.value.toInt(), 0x56);
      }, 'testMainB'));
    });
  });
}
