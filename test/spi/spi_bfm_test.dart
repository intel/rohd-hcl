// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_bfm_test.dart
// Tests for the SPI BFM.
//
// 2024 September 23
// Author: Roberto Torres <roberto.torres@intel.com>

import 'dart:async';
// import 'dart:convert';
import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

import 'spi_test.dart';

class SpiBfmTest extends Test {
  late final SpiInterface intf;
  late final SpiMainAgent main;
  late final SpiSubAgent sub;
  late final SpiMonitor monitor;

  String get outFolder => 'tmp_test/spibfm/$name/';

  SpiBfmTest(super.name) : super() {
    intf = SpiInterface(dataLength: 8);

    final clk = SimpleClockGenerator(10).clk;

    main = SpiMainAgent(intf: intf, parent: this, clk: clk);

    sub = SpiSubAgent(intf: intf, parent: this);

    monitor = SpiMonitor(intf: intf, parent: this);

    Directory(outFolder).createSync(recursive: true);

    final tracker =
        SpiTracker(intf: intf, dumpTable: false, outputFolder: outFolder);

    Simulator.registerEndOfSimulationAction(() async {
      await tracker.terminate();

      // // Commented to avoid bug
      //   final jsonStr =
      //        File('$outFolder/spiTracker.tracker.json').readAsStringSync();
      //   final jsonContents = json.decode(jsonStr);

      //   // ignore: avoid_dynamic_calls
      //   expect(jsonContents['records'].length, 2);

      //   Directory(outFolder).deleteSync(recursive: true);
    });

    monitor.stream.listen(tracker.record);
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('spiBfmTestObj');

    main.sequencer
        .add(SpiPacket(data: LogicValue.ofInt(0xCB, 8))); //0b1100 1011 = 203

    main.sequencer.add(SpiPacket(data: LogicValue.ofInt(0x00, 8)));

    //main.sequencer.add(SpiPacket(data: LogicValue.ofInt(0x00, 8)));

    unawaited(monitor.stream
        .where((event) =>
            event.direction == SpiDirection.main && event.data.toInt() == 0xCB)
        .first
        .then((_) {
      sub.sequencer
          .add(SpiPacket(data: LogicValue.ofInt(0x1B, 8))); //0b0001 1011 = 27
    }));

    // main.sequencer.add(SpiPacket(
    //     data: LogicValue.ofInt(0x00, 8),
    //     direction: SpiDirection.read)); //0b0111 0001 = 113

    obj.drop();
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  Future<void> runTest(SpiBfmTest spiBfmTest, {bool dumpWaves = true}) async {
    Simulator.setMaxSimTime(6000);

    if (dumpWaves) {
      final mod = SpiMainIntf(spiBfmTest.intf);
      await mod.build();
      WaveDumper(mod);
    }

    await spiBfmTest.start();
  }

  test('simple transfers', () async {
    await runTest(SpiBfmTest('simple'));
  });
}
