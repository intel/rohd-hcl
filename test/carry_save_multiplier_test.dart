// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// carry_save_mutiplier_test.dart
// Tests for carry save multiplier.
//
// 2023 June 1
// Author: Yao Jing Quek <yao.jing.quek@intel.com>
//

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

    expect(() => CarrySaveMultiplier(clk, reset, a, b),
        throwsA(const TypeMatcher<RohdHclException>()));
  });
  test('should return correct results when multiply in a pipeline.', () async {
    const widthLength = 16;
    final a = Logic(name: 'a', width: widthLength);
    final b = Logic(name: 'b', width: widthLength);
    final reset = Logic(name: 'reset');
    final clk = SimpleClockGenerator(10).clk;

    final csm = CarrySaveMultiplier(clk, reset, a, b);

    await csm.build();

    reset.inject(0);

    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());

    Future<void> waitCycles(int numCycles) async {
      for (var i = 0; i < numCycles; i++) {
        await clk.nextPosedge;
      }
    }

    final inputs = List.generate(
        10, (index) => List.generate(2, (index) => Random().nextInt(100) + 1));

    for (final input in inputs) {
      a.put(input[0]);
      b.put(input[1]);

      await waitCycles(csm.latency).then((value) {
        expect(csm.product.value.toInt(), equals(input[0] * input[1]));
      });

      await clk.nextNegedge;
    }

    await Simulator.simulationEnded;
  });
}
