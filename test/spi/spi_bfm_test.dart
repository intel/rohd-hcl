// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_bfm_test.dart
// Tests for the SPI BFM.
//
// 2024 September 23
// Author: Roberto Torres <roberto.torres@intel.com>

import 'dart:async';
import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

class SpiMod extends Module {
  SpiMod(SpiInterface intf, {super.name = 'SpiModIntf'}) {
    intf = SpiInterface.clone(intf)
      ..connectIO(this, intf,
          inputTags: [PairDirection.fromProvider, PairDirection.fromConsumer]);
  }
}

class SpiBfmTest extends Test {
  late final SpiInterface intf;
  late final SpiMainAgent main;
  late final SpiSubAgent sub;
  late final SpiMonitor monitor;

  String get outFolder => 'tmp_test/spiBfm/$name/';

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

    unawaited(monitor.stream
        .where((event) =>
            event.direction == SpiDirection.main && event.data.toInt() == 0xCB)
        .first
        .then((_) {
      sub.sequencer
          .add(SpiPacket(data: LogicValue.ofInt(0x1B, 8))); //0b0001 1011 = 27
    }));

    obj.drop();
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  Future<void> runTest(SpiBfmTest spiBfmTest, {bool dumpWaves = true}) async {
    Simulator.setMaxSimTime(3000);

    if (dumpWaves) {
      final mod = SpiMod(spiBfmTest.intf);
      await mod.build();
      WaveDumper(mod, outputPath: '${spiBfmTest.outFolder}/waves.vcd');
    }

    await spiBfmTest.start();
  }

  test('simple transfers', () async {
    await runTest(SpiBfmTest('simple'));
  });
}
