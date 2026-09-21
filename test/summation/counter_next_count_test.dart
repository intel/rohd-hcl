// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// counter_next_count_test.dart
// Tests for the nextCount output of Counter
//
// 2026 September 21
// Author: Shubham Padkonde <shubhampadkonde12@gmail.com>

import 'dart:async';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

/// Drives [counter] with a random [enable] pattern and checks on every cycle
/// that the `nextCount` seen this cycle is the `count` seen on the next one.
Future<void> checkPredictsNextCycle(
    Counter counter, Logic clk, Logic reset, Logic enable) async {
  await counter.build();

  Simulator.setMaxSimTime(10000);
  unawaited(Simulator.run());

  reset.inject(1);
  enable.inject(0);
  for (var i = 0; i < 3; i++) {
    await clk.nextNegedge;
  }
  reset.inject(0);
  await clk.nextNegedge;

  final rand = Random(1234);
  for (var i = 0; i < 50; i++) {
    // drive, and give the combinational sum a cycle to settle...
    enable.inject(rand.nextBool() ? 1 : 0);
    await clk.nextNegedge;

    // ...sample what the counter says is coming...
    final predicted = counter.nextCount.value;

    // ...then cross exactly one posedge and see what it actually became
    await clk.nextNegedge;

    expect(counter.count.value, predicted,
        reason: 'cycle $i: nextCount did not match the following count');
  }

  await Simulator.endSimulation();
  await Simulator.simulationEnded;
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('Counter nextCount predicts the next count', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final enable = Logic();

    await checkPredictsNextCycle(
        Counter.simple(clk: clk, reset: reset, by: 3, width: 8, enable: enable),
        clk,
        reset,
        enable);
  });

  test('GatedCounter nextCount predicts the next count', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final enable = Logic();

    await checkPredictsNextCycle(
        GatedCounter([
          SumInterface(fixedAmount: 3, hasEnable: true)..enable!.gets(enable),
        ], clk: clk, reset: reset, width: 8),
        clk,
        reset,
        enable);
  });
}
