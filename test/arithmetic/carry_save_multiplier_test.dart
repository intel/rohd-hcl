// Copyright (C) 2023 Intel Corporation
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

  test('should throw exception if inputs Logics have diferent width.', () {
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
}
