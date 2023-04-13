// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// rf_test.dart
// Tests for register file
//
// 2023 March 13
// Author: Max Korbel <max.korbel@intel.com>
//

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('rf simple', () async {
    const dataWidth = 32;
    const addrWidth = 5;

    const numWr = 3;
    const numRd = 3;

    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    final wrPorts = [
      for (var i = 0; i < numWr; i++)
        DataPortInterface(dataWidth, addrWidth)..en.put(0)
    ];
    final rdPorts = [
      for (var i = 0; i < numRd; i++)
        DataPortInterface(dataWidth, addrWidth)..en.put(0)
    ];

    final rf = RegisterFile(clk, reset, wrPorts, rdPorts, numEntries: 20);

    await rf.build();

    unawaited(Simulator.run());

    // a little reset flow
    await clk.nextNegedge;
    reset.put(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.put(0);
    await clk.nextNegedge;
    await clk.nextNegedge;

    // write to addr 0x4 on port 0
    wrPorts[0].en.put(1);
    wrPorts[0].addr.put(4);
    wrPorts[0].data.put(0xdeadbeef);

    await clk.nextNegedge;
    wrPorts[0].en.put(0);
    await clk.nextNegedge;

    // read it back out on a different port
    rdPorts[2].en.put(1);
    rdPorts[2].addr.put(4);
    expect(rdPorts[2].data.value.toInt(), 0xdeadbeef);

    await clk.nextNegedge;
    rdPorts[2].en.put(0);
    await clk.nextNegedge;

    Simulator.endSimulation();
    await Simulator.simulationEnded;
  });

  test('rf wr strobe', () async {
    const dataWidth = 32;
    const addrWidth = 5;

    const numWr = 1;
    const numRd = 1;

    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    final wrPorts = [
      for (var i = 0; i < numWr; i++)
        StrobeDataPortInterface(dataWidth, addrWidth)..en.put(0)
    ];
    final rdPorts = [
      for (var i = 0; i < numRd; i++)
        DataPortInterface(dataWidth, addrWidth)..en.put(0)
    ];

    final rf = RegisterFile(clk, reset, wrPorts, rdPorts, numEntries: 20);

    await rf.build();

    unawaited(Simulator.run());

    // a little reset flow
    await clk.nextNegedge;
    reset.put(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.put(0);
    await clk.nextNegedge;
    await clk.nextNegedge;

    // write to addr 0x4 on port 0
    wrPorts[0].en.put(1);
    wrPorts[0].strobe.put(bin('1010'));
    wrPorts[0].addr.put(4);
    wrPorts[0].data.put(0xffffffff);

    await clk.nextNegedge;
    wrPorts[0].en.put(0);
    await clk.nextNegedge;

    // read it back out on a different port
    rdPorts[0].en.put(1);
    rdPorts[0].addr.put(4);
    expect(rdPorts[0].data.value.toInt(), 0xff00ff00);

    await clk.nextNegedge;
    rdPorts[0].en.put(0);
    await clk.nextNegedge;

    Simulator.endSimulation();
    await Simulator.simulationEnded;
  });

  test('non-byte-aligned data widths are legal without strobes', () {
    DataPortInterface(1, 1);
  });

  group('rf exceptions', () {
    test('mismatch addr width', () {
      expect(
          () => RegisterFile(
                Logic(),
                Logic(),
                [DataPortInterface(32, 31)],
                [DataPortInterface(32, 32)],
              ),
          throwsA(const TypeMatcher<RohdHclException>()));
    });

    test('mismatch data width', () {
      expect(
          () => RegisterFile(
                Logic(),
                Logic(),
                [DataPortInterface(64, 32)],
                [DataPortInterface(32, 32)],
              ),
          throwsA(const TypeMatcher<RohdHclException>()));
    });
  });
}
