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

  test('variable up and down steps saturate at a runtime limit', () async {
    const width = 4;
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic(name: 'reset');
    final incAmount = Logic(name: 'incAmount', width: width);
    final decAmount = Logic(name: 'decAmount', width: width);
    final limit = Logic(name: 'limit', width: width);

    final counter = Counter(
      [
        SumInterface(width: width)..amount.gets(incAmount),
        SumInterface(width: width, increments: false)..amount.gets(decAmount),
      ],
      clk: clk,
      reset: reset,
      maxValue: limit,
      saturates: true,
    );
    await counter.build();

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    limit.inject(6);
    incAmount.inject(0);
    decAmount.inject(0);
    reset.inject(1);
    await clk.nextNegedge;
    reset.inject(0);
    await clk.nextNegedge;

    // Step up by a variable amount, below the limit.
    incAmount.inject(3);
    await clk.nextPosedge;
    await clk.nextNegedge;
    incAmount.inject(0);
    expect(counter.count.value.toInt(), 3, reason: 'up 3 from 0');

    // Step up past the runtime limit of 6: saturates and reports overflow.
    incAmount.inject(5);
    await clk.nextPosedge;
    await clk.nextNegedge;
    incAmount.inject(0);
    expect(counter.count.value.toInt(), 6, reason: 'saturates at limit');
    expect(counter.equalsMax.value.toBool(), isTrue);
    expect(counter.overflowed!.value.toBool(), isTrue);

    // Step down by a variable amount.
    decAmount.inject(4);
    await clk.nextPosedge;
    await clk.nextNegedge;
    decAmount.inject(0);
    expect(counter.count.value.toInt(), 2, reason: 'down 4 from 6');

    // Step down past zero: saturates at the minimum and reports underflow.
    decAmount.inject(5);
    await clk.nextPosedge;
    await clk.nextNegedge;
    decAmount.inject(0);
    expect(counter.count.value.toInt(), 0, reason: 'saturates at zero');
    expect(counter.underflowed!.value.toBool(), isTrue);

    await Simulator.endSimulation();
  });
}
