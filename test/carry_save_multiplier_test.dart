// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// carry_save_mutiplier_test.dart
// Tests for carry save multiplier.
//
// 2023 May 15
// Author: Yao Jing Quek <yao.jing.quek@intel.com>
//

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  // TODO: make sure its work for any diff width
  // TODO: multiplier as base class
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
}
