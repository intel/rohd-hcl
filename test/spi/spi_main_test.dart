// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_main_test.dart
// Definitions for the SPI interface.
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

class SpiBfmTest extends Test {
  late final SpiInterface intf;
  late final SpiMainAgent main;
  late final SpiMonitor monitor;

  String get outFolder => 'tmp_test/spibfm/$name/';

  SpiBfmTest(super.name) : super() {
    intf = SpiInterface(dataLength: 8);

    final clk = SimpleClockGenerator(10).clk;

    main = SpiMainAgent(intf: intf, parent: this, clk: clk);

    monitor = SpiMonitor(intf: intf, parent: this);

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

    final obj = phase.raiseObjection('spiBfmTestObj');

    main.sequencer
        .add(SpiPacket(data: LogicValue.ofInt(0xCB, 8))); //0b1100 1011 = 203

    main.sequencer.add(SpiPacket(data: LogicValue.ofInt(0x22, 8)));

    obj.drop();
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  Future<void> runTest(SpiBfmTest spiBfmTest, {bool dumpWaves = true}) async {
    Simulator.setMaxSimTime(6000);
    final sub = SpiSub(intf: spiBfmTest.intf);

    if (dumpWaves) {
      await sub.build();
      WaveDumper(sub);
    }

    await spiBfmTest.start();
  }

  test('simple transfers', () async {
    await runTest(SpiBfmTest('simple'));
  });
}
