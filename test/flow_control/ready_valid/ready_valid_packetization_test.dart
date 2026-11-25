// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_packetization_test.dart
// Tests protocol-neutral ready/valid packet framing primitives.
//
// 2026 August 29
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

TypedLogicArray<Logic, LogicValue> _array(int length, String name) =>
    TypedLogicArray<Logic, LogicValue>(
        [length], ({name}) => Logic(name: name, width: 8),
        name: name);

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('packetizer retains a packet and marks only its final frame', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final upstream = ReadyValidInterface<TypedLogicArray<Logic, LogicValue>>(
        _array(3, 'input'));
    final downstream = ReadyValidInterface<Frame<Logic>>(
        Frame(Logic(name: 'output', width: 8)));
    final packetizer = ReadyValidPacketizer(
        clk: clk, reset: reset, upstream: upstream, downstream: downstream);
    await packetizer.build();
    unawaited(Simulator.run());

    reset.inject(1);
    upstream.valid.inject(0);
    downstream.ready.inject(0);
    await clk.nextPosedge;
    reset.inject(0);
    for (final (index, value) in [0x11, 0x22, 0x33].indexed) {
      upstream.data.arrayElements[index].inject(value);
    }
    upstream.valid.inject(1);
    await clk.nextPosedge;
    upstream.valid.inject(0);
    expect(downstream.data.data.value, LogicValue.ofInt(0x11, 8));
    expect(downstream.data.last.value, LogicValue.zero);

    downstream.ready.inject(1);
    await clk.nextPosedge;
    expect(downstream.data.data.value, LogicValue.ofInt(0x22, 8));
    expect(downstream.data.last.value, LogicValue.zero);
    await clk.nextPosedge;
    expect(downstream.data.data.value, LogicValue.ofInt(0x33, 8));
    expect(downstream.data.last.value, LogicValue.one);
    await clk.nextPosedge;
    expect(downstream.valid.value, LogicValue.zero);
    await Simulator.endSimulation();
  });

  test('depacketizer reports early and capacity-truncated packets', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final upstream = ReadyValidInterface<Frame<Logic>>(
        Frame(Logic(name: 'input', width: 8)));
    final downstream = ReadyValidInterface<CollectedPacket<Logic>>(
        CollectedPacket(_array(3, 'output')));
    final depacketizer = ReadyValidDepacketizer(
        clk: clk, reset: reset, upstream: upstream, downstream: downstream);
    await depacketizer.build();
    unawaited(Simulator.run());

    reset.inject(1);
    upstream.valid.inject(0);
    downstream.ready.inject(0);
    await clk.nextPosedge;
    reset.inject(0);
    for (final (value, last) in [(0x11, 0), (0x22, 1)]) {
      upstream.data.data.inject(value);
      upstream.data.last.inject(last);
      upstream.valid.inject(1);
      await clk.nextPosedge;
    }
    upstream.valid.inject(0);
    expect(downstream.valid.value, LogicValue.one);
    expect(downstream.data.validElements.value, LogicValue.ofInt(2, 2));
    expect(downstream.data.framingError.value, LogicValue.zero);
    expect(downstream.data.data.arrayElements.map((lane) => lane.value), [
      LogicValue.ofInt(0x11, 8),
      LogicValue.ofInt(0x22, 8),
      LogicValue.ofInt(0, 8)
    ]);

    downstream.ready.inject(1);
    await clk.nextPosedge;
    downstream.ready.inject(0);
    for (final value in [0x44, 0x55, 0x66]) {
      upstream.data.data.inject(value);
      upstream.data.last.inject(0);
      upstream.valid.inject(1);
      await clk.nextPosedge;
    }
    upstream.valid.inject(0);
    expect(downstream.valid.value, LogicValue.one);
    expect(downstream.data.validElements.value, LogicValue.ofInt(3, 2));
    expect(downstream.data.framingError.value, LogicValue.one);
    await Simulator.endSimulation();
  });

  test('depacketizer represents a power-of-two capacity count', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final upstream = ReadyValidInterface<Frame<Logic>>(
        Frame(Logic(name: 'input', width: 8)));
    final downstream = ReadyValidInterface<CollectedPacket<Logic>>(
        CollectedPacket(_array(4, 'output')));
    final depacketizer = ReadyValidDepacketizer(
        clk: clk, reset: reset, upstream: upstream, downstream: downstream);
    await depacketizer.build();
    unawaited(Simulator.run());

    reset.inject(1);
    upstream.valid.inject(0);
    upstream.data.inject(0);
    downstream.ready.inject(0);
    await clk.nextPosedge;
    reset.inject(0);
    for (var value = 1; value <= 4; value++) {
      upstream.data.data.inject(value);
      upstream.data.last.inject(value == 4 ? 1 : 0);
      upstream.valid.inject(1);
      await clk.nextPosedge;
    }
    upstream.valid.inject(0);

    expect(downstream.valid.value, LogicValue.one);
    expect(downstream.data.validElements.value, LogicValue.ofInt(4, 3));
    expect(downstream.data.framingError.value, LogicValue.zero);
    expect(
      downstream.data.data.arrayElements.map((lane) => lane.value.toInt()),
      [1, 2, 3, 4],
    );
    await Simulator.endSimulation();
  });
}
