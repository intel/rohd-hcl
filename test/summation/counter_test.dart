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
  tearDown(() async {
    await Simulator.reset();
  });

  test('basic 1-bit rolling counter', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final enable = Logic()..inject(1);

    final counter =
        Counter.ofLogics([Const(1)], clk: clk, reset: reset, enable: enable);

    await counter.build();

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
    expect(counter.count.value.toInt(), 0);

    // wait a cycle, see 1
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 1);

    // wait a cycle, should overflow (1-bit counter), back to 0
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 0);

    // wait a cycle, see 1
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 1);

    enable.inject(0);
    // wait a cycle, no change
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 1);
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 1);

    enable.inject(1);

    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;

    await Simulator.endSimulation();
  });

  test('simple up counter', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final counter = Counter.simple(clk: clk, reset: reset, maxValue: 5);

    await counter.build();

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    // little reset routine
    reset.inject(0);
    await clk.nextNegedge;
    reset.inject(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.inject(0);

    expect(counter.overflowed.value.toBool(), false);
    expect(counter.underflowed.value.toBool(), false);
    expect(counter.equalsMax.value.toBool(), false);
    expect(counter.equalsMin.value.toBool(), true);

    for (var i = 0; i < 20; i++) {
      expect(counter.count.value.toInt(), i % 6);

      if (i % 6 == 5) {
        expect(counter.overflowed.value.toBool(), false);
        expect(counter.equalsMax.value.toBool(), true);
        expect(counter.equalsMin.value.toBool(), false);
      } else if (i % 6 == 0 && i > 0) {
        expect(counter.overflowed.value.toBool(), true);
        expect(counter.equalsMax.value.toBool(), false);
        expect(counter.equalsMin.value.toBool(), true);
      } else {
        expect(counter.overflowed.value.toBool(), false);
        expect(counter.equalsMax.value.toBool(), false);
        if (i % 6 != 0) {
          expect(counter.equalsMin.value.toBool(), false);
        } else {
          expect(counter.equalsMin.value.toBool(), true);
        }
      }

      expect(counter.underflowed.value.toBool(), false);

      await clk.nextNegedge;
    }

    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;

    await Simulator.endSimulation();
  });

  test('simple down counter', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final counter = Counter.simple(
        clk: clk, reset: reset, maxValue: 5, resetValue: 5, increments: false);

    await counter.build();

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    // little reset routine
    reset.inject(0);
    await clk.nextNegedge;
    reset.inject(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.inject(0);

    expect(counter.overflowed.value.toBool(), false);
    expect(counter.underflowed.value.toBool(), false);
    expect(counter.equalsMax.value.toBool(), true);
    expect(counter.equalsMin.value.toBool(), false);

    for (var i = 0; i < 20; i++) {
      expect(counter.count.value.toInt(), 5 - (i % 6));

      if (i % 6 == 5) {
        expect(counter.underflowed.value.toBool(), false);
        expect(counter.equalsMax.value.toBool(), false);
        expect(counter.equalsMin.value.toBool(), true);
      } else if (i % 6 == 0 && i > 0) {
        expect(counter.underflowed.value.toBool(), true);
        expect(counter.equalsMax.value.toBool(), true);
        expect(counter.equalsMin.value.toBool(), false);
      } else {
        expect(counter.underflowed.value.toBool(), false);
        expect(counter.equalsMin.value.toBool(), false);
        if (i % 6 != 0) {
          expect(counter.equalsMax.value.toBool(), false);
        } else {
          expect(counter.equalsMax.value.toBool(), true);
        }
      }

      expect(counter.overflowed.value.toBool(), false);

      await clk.nextNegedge;
    }

    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;

    await Simulator.endSimulation();
  });

  test('reset and restart counter', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final restart = Logic();

    final counter = Counter(
      [
        SumInterface(fixedAmount: 4),
        SumInterface(fixedAmount: 2, increments: false),
      ],
      clk: clk,
      reset: reset,
      restart: restart,
      resetValue: 10,
      maxValue: 15,
      saturates: true,
      width: 8,
    );

    await counter.build();
    WaveDumper(counter);

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    // little reset routine
    reset.inject(0);
    restart.inject(0);
    await clk.nextNegedge;
    reset.inject(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.inject(0);

    // check initial value after reset drops
    expect(counter.count.value.toInt(), 10);

    // increment each cycle
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 12);
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 14);
    expect(counter.overflowed.value.toBool(), false);

    // saturate
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 15);
    expect(counter.overflowed.value.toBool(), true);
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 15);
    expect(counter.overflowed.value.toBool(), true);

    // restart (not reset!)
    restart.inject(1);

    // now we should catch the next +2 still, not miss it
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 12);

    // and hold there
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 12);

    // drop it and should continue
    restart.inject(0);
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 14);

    // now back to reset
    reset.inject(1);
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 10);
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 10);

    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;

    await Simulator.endSimulation();
  });
}
