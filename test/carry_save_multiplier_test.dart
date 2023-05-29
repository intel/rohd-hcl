// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// carry_save_mutiplier_test.dart
// Tests for carry save multiplier.
//
// 2023 May 15
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

  test('should return correct results when multiply.', () async {
    final a = Logic(name: 'a', width: 4);
    final b = Logic(name: 'b', width: 4);
    final reset = Logic(name: 'reset');
    final clk = SimpleClockGenerator(10).clk;

    final csm = CarrySaveMultiplier(a, b, clk, reset);

    await csm.build();

    // after one cycle, change the value of a and b
    a.inject(12);
    b.inject(2);
    reset.inject(1);

    // Attach a waveform dumper so we can see what happens.
    WaveDumper(csm, outputPath: 'csm.vcd');

    Simulator.registerAction(10, () {
      reset.inject(0);
    });

    Simulator.registerAction(30, () {
      a.put(10);
      b.put(11);
    });

    Simulator.registerAction(60, () {
      a.put(10);
      b.put(6);
    });

    csm.product.changed.listen((event) {
      print('@t=${Simulator.time}, product is: ${event.newValue.toInt()}');
    });

    Simulator.setMaxSimTime(150);

    await Simulator.run();
  });

  test('should return correct results when multiply in a pipeline.', () async {
    // TODO(): do test on width other than 4
    // TODO(): performs more test
    // TODO(): Latency formula need to check again
    final a = Logic(name: 'a', width: 4);
    final b = Logic(name: 'b', width: 4);
    final reset = Logic(name: 'reset');
    final clk = SimpleClockGenerator(10).clk;

    final csm = CarrySaveMultiplier(a, b, clk, reset);

    await csm.build();

    reset.inject(0);

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    Future<void> waitCycles(int numCycles) async {
      for (var i = 0; i < numCycles; i++) {
        await clk.nextPosedge;
      }
    }

    final inputs = List.generate(
        10, (index) => List.generate(2, (index) => Random().nextInt(10) + 1));

    for (final input in inputs) {
      a.put(input[0]);
      b.put(input[1]);

      await waitCycles(input[0].bitLength + input[1].bitLength).then((value) {
        print(input[0]);
        print(input[1]);
        print(csm.product.value.toInt());
      });

      await clk.nextNegedge;
    }

    await Simulator.simulationEnded;
  });
}
