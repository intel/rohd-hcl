// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// counter_test.dart
// Tests for the counter.
//
// 2024 August 26
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  test('basic 1-bit counter', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final intf = CounterInterface(fixedAmount: 1);
    final counter = Counter([intf], clk: clk, reset: reset);

    await counter.build();

    WaveDumper(counter);
    print(counter.generateSynth());

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    // little reset routine
    reset.inject(0);
    await clk.nextNegedge;
    reset.inject(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.inject(0);

    // check initial value
    expect(counter.value.value.toInt(), 0);

    // wait a cycle, see 1
    await clk.nextNegedge;
    expect(counter.value.value.toInt(), 1);

    // wait a cycle, should overflow (1-bit counter), back to 0
    await clk.nextNegedge;
    expect(counter.value.value.toInt(), 0);

    // wait a cycle, see 1
    await clk.nextNegedge;
    expect(counter.value.value.toInt(), 1);

    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;

    await Simulator.endSimulation();
  });

  //TODO: test modulo requirement -- if sum is >2x greater than saturation
}
