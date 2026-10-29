// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('circular pointer wraps at a non-power-of-two slot count', () async {
    // Five slots with increments [2, 2, 2, 0, 4]. Each increment is applied
    // after a posedge; the pointer moves on the following posedge. A step
    // wraps when pointer + increment >= slots.
    const slots = 5;
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic(name: 'reset');
    final increment = Logic(name: 'increment', width: 3);
    final dut = CircularPointer(clk, reset, increment, slots: slots);

    await dut.build();

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    reset.inject(1);
    increment.inject(0);
    await clk.nextNegedge;
    reset.inject(0);
    await clk.nextNegedge;

    var model = 0;
    for (final inc in [2, 2, 2, 0, 4]) {
      increment.inject(inc);
      await clk.nextNegedge;
      model = (model + inc) % slots;
      expect(dut.pointer.value.toInt(), model,
          reason: 'after inc=$inc, expected $model');
      expect(dut.wrapped.value.toBool(), model + inc >= slots,
          reason: 'wrapped tracks pointer + held inc=$inc');
    }

    await Simulator.endSimulation();
  });
}
