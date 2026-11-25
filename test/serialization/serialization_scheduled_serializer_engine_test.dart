// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// serialization_scheduled_serializer_engine_test.dart
// Tests for Serialization Scheduled Serializer Engine.
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

  test('loads, advances, replaces, and clears scheduled arrays', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final load = Logic();
    final advance = Logic();
    final clear = Logic();
    final loadData = LogicArray([2], 8, name: 'loadData');
    final engine = ScheduledSerializerEngine<Logic>(
      clk: clk,
      reset: reset,
      loadData: loadData,
      load: load,
      advance: advance,
      clear: clear,
    );
    await engine.build();
    unawaited(Simulator.run());

    reset.inject(1);
    load.inject(0);
    advance.inject(0);
    clear.inject(0);
    await clk.nextPosedge;
    reset.inject(0);

    loadData.elements[0].inject(0x11);
    loadData.elements[1].inject(0x22);
    load.inject(1);
    await clk.nextPosedge;
    load.inject(0);
    expect(engine.active.value, LogicValue.one);
    expect(engine.index.value.toInt(), 0);
    expect(engine.data.value.toInt(), 0x11);
    expect(engine.last.value, LogicValue.zero);

    advance.inject(1);
    await clk.nextPosedge;
    advance.inject(0);
    expect(engine.index.value.toInt(), 1);
    expect(engine.data.value.toInt(), 0x22);
    expect(engine.last.value, LogicValue.one);

    loadData.elements[0].inject(0x33);
    loadData.elements[1].inject(0x44);
    load.inject(1);
    advance.inject(1);
    await clk.nextPosedge;
    load.inject(0);
    advance.inject(0);
    expect(engine.active.value, LogicValue.one);
    expect(engine.index.value.toInt(), 0);
    expect(engine.data.value.toInt(), 0x33);

    clear.inject(1);
    await clk.nextPosedge;
    clear.inject(0);
    expect(engine.active.value, LogicValue.zero);
    expect(engine.index.value.toInt(), 0);
    await Simulator.endSimulation();
  });
}
