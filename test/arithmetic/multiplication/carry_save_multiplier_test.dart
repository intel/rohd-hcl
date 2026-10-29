// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// carry_save_mutiplier_test.dart
// Tests for carry save multiplier.
//
// 2023 June 1
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'dart:async';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('should throw exception if inputs Logics have different width.', () {
    final a = Logic(name: 'a', width: 8);
    final b = Logic(name: 'b', width: 16);
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic(name: 'reset');

    expect(() => CarrySaveMultiplier(clk: clk, reset: reset, a, b),
        throwsA(const TypeMatcher<RohdHclException>()));
  });

  test('should return correct results when multiply in a pipeline.', () async {
    const widthLength = 4;
    final a = Logic(name: 'a', width: widthLength);
    final b = Logic(name: 'b', width: widthLength);
    final reset = Logic(name: 'reset');
    final clk = SimpleClockGenerator(10).clk;

    final csm = CarrySaveMultiplier(clk: clk, reset: reset, a, b);

    await csm.build();

    reset.inject(0);

    Simulator.setMaxSimTime(10000);

    unawaited(Simulator.run());

    Future<int> waitCycles(int numCycles, {int a = 0, int b = 0}) async {
      for (var i = 0; i < numCycles; i++) {
        await clk.nextPosedge;
      }
      return a * b;
    }

    final randNum = Random(5);
    final inputs = List.generate(
        10,
        (index) => List.generate(
            2, (index) => randNum.nextInt(1 << widthLength - 1) + 1));

    var tested = 0;
    for (var i = 0; i < inputs.length; i++) {
      a.put(inputs[i][0]);
      b.put(inputs[i][1]);
      unawaited(
        waitCycles(csm.latency, a: inputs[i][0], b: inputs[i][1])
            .then((result) {
          expect(csm.product.value.toInt(), equals(result));
          tested += 1;
        }),
      );
      await clk.nextNegedge;
    }

    await waitCycles(inputs.length).then(
      (value) => {
        Simulator.endSimulation(),
        expect(tested, equals(inputs.length)),
      },
    );
    await Simulator.simulationEnded;
  });

  // Present one operand pair for a single enabled cycle, then stall the
  // pipeline mid-flight. The product must appear only after exactly
  // [CarrySaveMultiplier.latency] enabled cycles, with the stall cycles
  // excluded, and must not leak out while stalled.
  test('enable stalls every pipeline stage.', () async {
    const width = 4;
    const stallCycles = 3;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    final enable = Logic(name: 'enable');
    final reset = Logic(name: 'reset');
    final clk = SimpleClockGenerator(10).clk;
    final csm =
        CarrySaveMultiplier(clk: clk, reset: reset, enable: enable, a, b);
    await csm.build();

    reset.inject(0);
    enable.inject(1);
    a.inject(3);
    b.inject(5);

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    await clk.nextPosedge;
    a.put(0);
    b.put(0);
    await clk.nextPosedge;

    enable.put(0);
    for (var cycle = 0; cycle < stallCycles; cycle++) {
      await clk.nextPosedge;
      await clk.nextNegedge;
      expect(csm.product.value,
          isNot(equals(LogicValue.ofInt(15, csm.product.width))),
          reason: 'stall cycle $cycle must not advance the pipeline');
    }

    enable.put(1);
    for (var cycle = 2; cycle < csm.latency; cycle++) {
      await clk.nextPosedge;
    }
    await clk.nextNegedge;
    expect(csm.product.value.toInt(), equals(15),
        reason: 'product must appear after exactly latency enabled cycles');

    await Simulator.endSimulation();
  });
}
