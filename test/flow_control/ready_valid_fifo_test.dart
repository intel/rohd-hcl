// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_fifo_test.dart
// Tests for ready-valid FIFO behavior.
//
// 2025 October 21
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

/// A small [LogicStructure] used only in these tests.
class SimpleOp extends LogicStructure {
  Logic get op => elements[0];
  Logic get data => elements[1];

  SimpleOp()
      : super([
          Logic(
              name: 'op', width: 4), // Make op field 4 bits to hold values 1-4
          Logic(name: 'data', width: 8),
        ], name: 'simple_op');

  SimpleOp._fromStructure(LogicStructure original, {String? name})
      : super(original.elements.map((e) => e.clone()).toList(),
            name: name ?? original.name);

  @override
  SimpleOp clone({String? name}) => SimpleOp._fromStructure(this, name: name);
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('ReadyValidFifo basic flow (SimpleOp)', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    final upstream = ReadyValidInterface<SimpleOp>(SimpleOp());
    final downstream = ReadyValidInterface<SimpleOp>(SimpleOp());

    final fifoModule = ReadyValidFifo<SimpleOp>(
        clk: clk,
        reset: reset,
        upstream: upstream,
        downstream: downstream,
        depth: 4);

    await fifoModule.build();
    unawaited(Simulator.run());

    // Reset
    reset.inject(1);
    upstream.valid.inject(0);
    downstream.ready.inject(0);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextPosedge;

    // Send one item
    upstream.valid.inject(1);
    upstream.data.op.inject(1);
    upstream.data.data.inject(0x12);
    await clk.nextPosedge;

    // FIFO should accept it (upstream.ready should be 1).
    expect(upstream.ready.value.toInt(), equals(1));

    // Now enable downstream ready to consume.
    downstream.ready.inject(1);
    await clk.nextPosedge;

    // Downstream should see valid data.
    expect(downstream.valid.value.toInt(), equals(1));
    expect(downstream.data.data.value.toInt(), equals(0x12));

    downstream.ready.inject(0);
    upstream.valid.inject(0);
    await clk.nextPosedge;
    await Simulator.endSimulation();
  });

  test('ReadyValidFifo backpressure and ready rising on drain', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    final upstream = ReadyValidInterface<SimpleOp>(SimpleOp());
    final downstream = ReadyValidInterface<SimpleOp>(SimpleOp());

    const fifoDepth = 4;
    final fifoModule = ReadyValidFifo<SimpleOp>(
        clk: clk,
        reset: reset,
        upstream: upstream,
        downstream: downstream,
        depth: fifoDepth);

    await fifoModule.build();
    // WaveDumper(fifoModule, outputPath: 'fifo_backpressure.vcd');
    unawaited(Simulator.run());

    // Reset
    reset.inject(1);
    upstream.valid.inject(0);
    downstream.ready.inject(0); // downstream NOT ready -> backpressure
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextPosedge;

    // Fill the FIFO continuously (no artificial valid pulsing)
    for (var i = 0; i < fifoDepth; i++) {
      upstream.valid.inject(1);
      upstream.data.op.inject(i + 1); // Unique op: 1, 2, 3, 4
      upstream.data.data
          .inject(0x10 + i); // Unique data: 0x10, 0x11, 0x12, 0x13
      await clk.nextPosedge;
      // Don't pulse valid - let ready handle backpressure
    }
    upstream.valid.inject(0);

    // After filling, upstream ready should be 0 (cannot accept more).
    expect(upstream.ready.value.toInt(), equals(0));

    // Now make downstream ready and fully drain the FIFO.
    downstream.ready.inject(1);

    // Collect all drained data to verify FIFO ordering
    final drainedOps = <int>[];
    final drainedData = <int>[];

    // Drain all 4 elements using proper ready-valid handshake timing
    for (var i = 0; i < fifoDepth; i++) {
      await clk.nextPosedge;

      // Sample data using previousValue to get the value before clock edge
      // This captures data that was valid during the handshake
      if (downstream.valid.previousValue!.toBool() &&
          downstream.ready.previousValue!.toBool()) {
        final op = downstream.data.op.previousValue!.toInt();
        final data = downstream.data.data.previousValue!.toInt();
        drainedOps.add(op);
        drainedData.add(data);
        expect(op, equals(i + 1),
            reason: 'Op should match expected value for element $i');
        expect(data, equals(0x10 + i),
            reason: 'Data should match expected value for element $i');
      }

      // After draining first element, upstream.ready should go high (space
      // available).
      if (i == 0) {
        expect(upstream.ready.value.toInt(), equals(1),
            reason: 'After draining one element, upstream should be ready');
      }
    }

    // Verify all data was drained in correct FIFO order
    expect(drainedOps, equals([1, 2, 3, 4]),
        reason: 'Operations should be drained in FIFO order');
    expect(drainedData, equals([0x10, 0x11, 0x12, 0x13]),
        reason: 'Data should be drained in FIFO order');

    // After fully draining, downstream should no longer have valid data
    await clk.nextPosedge;
    expect(downstream.valid.value.toInt(), equals(0),
        reason: 'After full drain, downstream should not be valid');

    downstream.ready.inject(0);
    upstream.valid.inject(0);
    await clk.nextPosedge;
    await Simulator.endSimulation();
  });

  test('ReadyValidFifo empty behavior and ordering', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    final upstream = ReadyValidInterface<SimpleOp>(SimpleOp());
    final downstream = ReadyValidInterface<SimpleOp>(SimpleOp());

    const fifoDepth = 4;
    final fifoModule = ReadyValidFifo<SimpleOp>(
        clk: clk,
        reset: reset,
        upstream: upstream,
        downstream: downstream,
        depth: fifoDepth);

    await fifoModule.build();
    unawaited(Simulator.run());

    // Reset sequence.
    reset.inject(1);
    upstream.valid.inject(0);
    downstream.ready.inject(0);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextPosedge;

    // Empty FIFO: downstream.valid should be 0.
    expect(downstream.valid.value.toInt(), equals(0));

    // Push multiple items with continuous streaming
    for (var i = 0; i < 3; i++) {
      upstream.valid.inject(1);
      upstream.data.op.inject(i + 1); // Unique op: 1, 2, 3
      upstream.data.data.inject(i + 10); // Unique data: 10, 11, 12
      await clk.nextPosedge;
    }
    upstream.valid.inject(0);

    // Now consume them and verify FIFO order (FIFO semantics) using handshakes.
    final collected = <int>[];
    downstream.ready.inject(1);
    while (collected.length < 3) {
      await clk.nextPosedge;
      // Use previousValue to capture the combinational handshake/data that
      // existed before the posedge. The FIFO updates pointers on the
      // posedge, so sampling .value after the posedge can show the next
      // element instead of the one that was just transferred.
      if (downstream.valid.previousValue!.toBool() &&
          downstream.ready.previousValue!.toBool()) {
        collected.add(downstream.data.data.previousValue!.toInt());
      }
    }
    expect(collected, equals([10, 11, 12]));

    downstream.ready.inject(0);
    upstream.valid.inject(0);
    await clk.nextPosedge;
    await Simulator.endSimulation();
  });

  test('ReadyValidFifo full prevention', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    final upstream = ReadyValidInterface<SimpleOp>(SimpleOp());
    final downstream = ReadyValidInterface<SimpleOp>(SimpleOp());

    const fifoDepth = 3;
    final fifoModule = ReadyValidFifo<SimpleOp>(
        clk: clk,
        reset: reset,
        upstream: upstream,
        downstream: downstream,
        depth: fifoDepth);

    await fifoModule.build();
    unawaited(Simulator.run());

    // Reset sequence.
    reset.inject(1);
    upstream.valid.inject(0);
    downstream.ready.inject(0);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextPosedge;

    // Fill to depth with continuous streaming
    for (var i = 0; i < fifoDepth; i++) {
      upstream.valid.inject(1);
      upstream.data.op.inject(i + 1); // Unique op: 1, 2, 3
      upstream.data.data.inject(0x20 + i); // Unique data: 0x20, 0x21, 0x22
      await clk.nextPosedge;
    }

    // FIFO should be full now — upstream should deassert ready.
    expect(upstream.ready.value.toInt(), equals(0));

    // Attempt to write one more - it should not be accepted (upstream.ready 0).
    upstream.valid.inject(1);
    upstream.data.data.inject(0xFF);
    await clk.nextPosedge;
    expect(upstream.ready.value.toInt(), equals(0));

    // Now drain one and ensure FIFO not full and upstream ready becomes 1.
    downstream.ready.inject(1);
    await clk.nextPosedge;
    // After draining one element, upstream should once again be ready.
    expect(upstream.ready.value.toInt(), equals(1));
    expect(upstream.ready.value.toInt(), equals(1));

    downstream.ready.inject(0);
    upstream.valid.inject(0);
    await clk.nextPosedge;
    await Simulator.endSimulation();
  });
}
