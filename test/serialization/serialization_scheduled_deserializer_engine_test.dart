// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// serialization_scheduled_deserializer_engine_test.dart
// Tests for Serialization Scheduled Deserializer Engine.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('collects typed elements, completes early, and clears partial work',
      () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final element = Logic(width: 8);
    final write = Logic();
    final last = Logic();
    final clear = Logic();
    final engine = ScheduledDeserializerEngine<Logic>(
      clk: clk,
      reset: reset,
      element: element,
      write: write,
      last: last,
      clear: clear,
      length: 3,
    );
    await engine.build();
    unawaited(Simulator.run());

    reset.inject(1);
    write.inject(0);
    last.inject(0);
    clear.inject(0);
    await clk.nextPosedge;
    reset.inject(0);

    element.inject(0x11);
    write.inject(1);
    await clk.nextPosedge;
    expect(engine.index.value.toInt(), 1);
    expect(engine.complete.value, LogicValue.zero);
    expect(engine.data.arrayElements[0].value.toInt(), 0x11);

    element.inject(0x22);
    last.inject(1);
    await clk.nextPosedge;
    write.inject(0);
    last.inject(0);
    expect(engine.index.value.toInt(), 0);
    expect(engine.complete.value, LogicValue.one);
    expect(
      engine.data.arrayElements.take(2).map((entry) => entry.value.toInt()),
      [0x11, 0x22],
    );

    await clk.nextPosedge;
    expect(engine.complete.value, LogicValue.zero);
    element.inject(0x33);
    write.inject(1);
    await clk.nextPosedge;
    write.inject(0);
    expect(engine.index.value.toInt(), 1);

    clear.inject(1);
    await clk.nextPosedge;
    clear.inject(0);
    expect(engine.index.value.toInt(), 0);
    expect(engine.complete.value, LogicValue.zero);
    await Simulator.endSimulation();
  });

  test('preserves scalar deserializer completion timing', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final element = Logic(width: 8);
    final enable = Logic();
    final last = Logic();
    final deserializer = Deserializer<Logic, LogicValue>(
      element,
      3,
      valueCodec: LogicValueCodec.logicValue,
      clk: clk,
      reset: reset,
      enable: enable,
      last: last,
    );
    await deserializer.build();
    unawaited(Simulator.run());

    reset.inject(1);
    enable.inject(0);
    last.inject(0);
    await clk.nextPosedge;
    reset.inject(0);
    enable.inject(1);

    element.inject(0x11);
    await clk.nextPosedge;
    element.inject(0x22);
    last.inject(1);
    await clk.nextPosedge;
    expect(deserializer.done.value, LogicValue.one);
    expect(deserializer.count.value.toInt(), 1);
    expect(
      deserializer.deserialized.elements
          .take(2)
          .map((entry) => entry.value.toInt()),
      [0x11, 0x22],
    );
    await Simulator.endSimulation();
  });
}
