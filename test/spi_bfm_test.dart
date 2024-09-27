// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_bfm_test.dart
// Definitions for the SPI interface.
//
// 2024 September 23
// Author: Roberto Torres <roberto.torres@intel.com>

import 'dart:async';
import 'dart:convert';
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
  final int numTransfers;

  String get outFolder => 'tmp_test/spibfm/$name';

  SpiBfmTest(
    super.name, {
    this.numTransfers = 2,
  }) : super() {
    intf = SpiInterface();

    final clk = SimpleClockGenerator(10).clk;

    main = SpiMainAgent(intf: intf, parent: this, clk: clk);

    sub = SpiSubAgent(intf: intf, parent: this);

    final monitor = SpiMonitor(intf: intf, parent: this);

    Directory(outFolder).createSync(recursive: true);

    final tracker =
        SpiTracker(intf: intf, dumpTable: false, outputFolder: outFolder);

    Simulator.registerEndOfSimulationAction(() async {
      await tracker.terminate();

      final jsonStr =
          File('$outFolder/spiTracker.tracker.json').readAsStringSync();
      final jsonContents = json.decode(jsonStr);

      // ignore: avoid_dynamic_calls
      expect(jsonContents['records'].length, 0);

      Directory(outFolder).deleteSync(recursive: true);
    });

    monitor.stream.listen(tracker.record);
  }

  //int numTransfersCompleted = 0;

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('spiBfmTestObj');

    logger.info('spi');
    // final randomData = List.generate(numTransfers,
    //     (index) => LogicValue.ofInt(Test.random!.nextInt(1 << 32), 32));

    // for (var i = 0; i < numTransfers; i++) {
    //  final packets = SpiPacket(data: randomData[i]);

    main.sequencer.add(SpiPacket(data: LogicValue.ofInt(0xB, 4))); //0b1011
    sub.sequencer.add(SpiPacket(data: LogicValue.ofInt(0xA, 4))); //0b1010
    // numTransfersCompleted++;
    // }
    obj.drop();
    logger.info('Done run test');
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  Future<void> runTest(SpiBfmTest spiBfmTest, {bool dumpWaves = true}) async {
    Simulator.setMaxSimTime(6000);

    if (dumpWaves) {
      final mod = SpiMain(spiBfmTest.intf);
      await mod.build();
      //print(mod.generateSynth());
      WaveDumper(mod);
    }

    await spiBfmTest.start();
  }

  test('simple transfers', () async {
    await runTest(SpiBfmTest('simple'));
  });
}
