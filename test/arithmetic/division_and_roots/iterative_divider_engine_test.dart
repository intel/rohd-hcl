// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// iterative_divider_engine_test.dart
// Tests for the iterative divider engine and ready/valid wrapper.
//
// 2026 November 8
// Author: Copilot <223556219+Copilot@users.noreply.github.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

Future<void> _tick(Logic clk) async {
  await clk.nextPosedge;
  await clk.nextNegedge;
}

Future<void> _waitFor(Logic clk, Logic signal) async {
  for (var cycle = 0; cycle < 200; cycle++) {
    if (signal.value.toBool()) {
      return;
    }
    await _tick(clk);
  }
  fail('Timed out waiting for ${signal.name}');
}

void main() {
  tearDown(Simulator.reset);

  test('direct engine accepts a start and pulses done', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final start = Logic();
    final dividend = Logic(width: 8);
    final divisor = Logic(width: 8);
    final isSigned = Logic();
    final engine = IterativeDividerEngine(
      clk: clk,
      reset: reset,
      start: start,
      dividend: dividend,
      divisor: divisor,
      isSigned: isSigned,
    );
    await engine.build();
    unawaited(Simulator.run());
    try {
      reset.inject(1);
      start.inject(0);
      dividend.inject(20);
      divisor.inject(3);
      isSigned.inject(0);
      await _tick(clk);
      reset.inject(0);
      expect(engine.busy.value.toBool(), isFalse);
      start.inject(1);
      await _tick(clk);
      start.inject(0);
      expect(engine.busy.value.toBool(), isTrue);
      await _waitFor(clk, engine.done);
      expect(engine.quotient.value.toInt(), 6);
      expect(engine.remainder.value.toInt(), 2);
      expect(engine.divZero.value.toBool(), isFalse);
      await _tick(clk);
      expect(engine.done.value.toBool(), isFalse);
      expect(engine.busy.value.toBool(), isFalse);
    } finally {
      await Simulator.endSimulation();
    }
  });

  test('ready/valid wrapper retains stalled results and blocks commands',
      () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final upstream = ReadyValidInterface(
      DivisionRequest(dataWidth: 8),
      contract: ReadyValidContract.readyAndValid,
    );
    final downstream = ReadyValidInterface(DivisionResult(dataWidth: 8));
    final divider = ReadyValidIterativeDivider(
      clk: clk,
      reset: reset,
      upstream: upstream,
      downstream: downstream,
    );
    await divider.build();
    unawaited(Simulator.run());
    try {
      reset.inject(1);
      upstream.valid.inject(0);
      upstream.data.dividend.inject(20);
      upstream.data.divisor.inject(3);
      upstream.data.isSigned.inject(0);
      downstream.ready.inject(0);
      await _tick(clk);
      reset.inject(0);
      expect(upstream.ready.value.toBool(), isTrue);
      upstream.valid.inject(1);
      await _tick(clk);
      upstream.data.dividend.inject(17);
      upstream.data.divisor.inject(5);
      expect(upstream.ready.value.toBool(), isFalse);
      await _waitFor(clk, downstream.valid);
      for (var cycle = 0; cycle < 5; cycle++) {
        expect(downstream.valid.value.toBool(), isTrue);
        expect(downstream.data.quotient.value.toInt(), 6);
        expect(downstream.data.remainder.value.toInt(), 2);
        expect(downstream.data.divZero.value.toBool(), isFalse);
        expect(upstream.ready.value.toBool(), isFalse);
        await _tick(clk);
      }
      downstream.ready.inject(1);
      await _tick(clk);
      expect(downstream.valid.value.toBool(), isFalse);
      expect(upstream.ready.value.toBool(), isTrue);

      await _tick(clk);
      upstream.valid.inject(0);
      expect(upstream.ready.value.toBool(), isFalse);
      await _waitFor(clk, downstream.valid);
      expect(downstream.data.quotient.value.toInt(), 3);
      expect(downstream.data.remainder.value.toInt(), 2);
      await _tick(clk);
      expect(downstream.valid.value.toBool(), isFalse);
      expect(upstream.ready.value.toBool(), isTrue);

      downstream.ready.inject(0);
      upstream.valid.inject(1);
      await _tick(clk);
      upstream.valid.inject(0);
      await _waitFor(clk, downstream.valid);
      await _tick(clk);
      expect(downstream.valid.value.toBool(), isTrue);
      reset.inject(1);
      await _tick(clk);
      expect(downstream.valid.value.toBool(), isFalse);
      expect(upstream.ready.value.toBool(), isTrue);
    } finally {
      await Simulator.endSimulation();
    }
  });

  test('wrapper matches divider handshake timing, including reset', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final upstream = ReadyValidInterface(
      DivisionRequest(dataWidth: 8),
      contract: ReadyValidContract.readyAndValid,
    );
    final downstream = ReadyValidInterface(DivisionResult(dataWidth: 8));
    final wrapper = ReadyValidIterativeDivider(
      clk: clk,
      reset: reset,
      upstream: upstream,
      downstream: downstream,
    );
    final reference = MultiCycleDivider.ofLogics(
      clk: clk,
      reset: reset,
      validIn: upstream.valid,
      dividend: upstream.data.dividend,
      divisor: upstream.data.divisor,
      isSigned: upstream.data.isSigned,
      readyOut: downstream.ready,
    );
    await wrapper.build();
    await reference.build();
    unawaited(Simulator.run());
    try {
      reset.inject(1);
      upstream.valid.inject(0);
      upstream.data.dividend.inject(0);
      upstream.data.divisor.inject(1);
      upstream.data.isSigned.inject(0);
      downstream.ready.inject(0);
      await _tick(clk);
      reset.inject(0);

      final commands = [
        (dividend: 20, divisor: 3, signed: 0),
        (dividend: 236, divisor: 3, signed: 1),
        (dividend: 42, divisor: 0, signed: 0),
        (dividend: 17, divisor: 5, signed: 0),
      ];
      var commandIndex = 0;
      var completed = 0;
      for (var cycle = 0; cycle < 400; cycle++) {
        final command = commands[commandIndex % commands.length];
        upstream.valid.inject(1);
        upstream.data.dividend.inject(command.dividend);
        upstream.data.divisor.inject(command.divisor);
        upstream.data.isSigned.inject(command.signed);
        downstream.ready.inject(cycle % 40 < 25 ? 0 : 1);
        reset.inject(cycle == 80 ? 1 : 0);

        expect(upstream.ready.value, reference.readyIn.value, reason: '$cycle');
        expect(downstream.valid.value, reference.validOut.value,
            reason: '$cycle');
        if (downstream.valid.value.toBool()) {
          expect(downstream.data.quotient.value, reference.quotient.value,
              reason: '$cycle');
          expect(downstream.data.remainder.value, reference.remainder.value,
              reason: '$cycle');
          expect(downstream.data.divZero.value, reference.divZero.value,
              reason: '$cycle');
          if (downstream.ready.value.toBool() && cycle != 80) {
            completed++;
          }
        }
        if (upstream.ready.value.toBool() && cycle != 80) {
          commandIndex++;
        }
        await _tick(clk);
      }
      expect(completed, greaterThan(4));
    } finally {
      await Simulator.endSimulation();
    }
  });
}
