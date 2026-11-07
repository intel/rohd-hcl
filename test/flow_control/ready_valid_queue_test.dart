// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_queue_test.dart
// Tests for ready/valid queue storage and visibility policies.
//
// 2026 November 5
// Author: GitHub Copilot

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _Packet extends LogicStructure {
  Logic get payload => elements.single;

  _Packet({String? name})
      : super([Logic(name: 'payload', width: 8)], name: name ?? 'packet');

  @override
  _Packet clone({String? name}) => _Packet(name: name ?? this.name);
}

void main() {
  tearDown(Simulator.reset);

  for (final storage in ReadyValidQueueStorage.values) {
    for (final policy in ReadyValidQueuePolicy.values) {
      for (final depth in [1, 3]) {
        test('$storage $policy depth $depth preserves transfers', () async {
          final clk = SimpleClockGenerator(10).clk;
          final reset = Logic();
          final flush = Logic();
          final upstream = ReadyValidInterface(Logic(name: 'input', width: 8));
          final downstream =
              ReadyValidInterface(Logic(name: 'output', width: 8));
          final queue = ReadyValidQueue<Logic>(
            clk: clk,
            reset: reset,
            flush: flush,
            upstream: upstream,
            downstream: downstream,
            depth: depth,
            policy: policy,
            storage: storage,
            almostFullThreshold: depth - 1,
            almostEmptyThreshold: 1,
          );
          await queue.build();
          unawaited(Simulator.run());
          reset.inject(1);
          flush.inject(0);
          upstream.valid.inject(0);
          upstream.data.inject(0);
          downstream.ready.inject(0);
          await clk.nextPosedge;
          await clk.nextNegedge;
          reset.inject(0);

          final expected = ListQueue<int>();
          final random = Random(923);
          try {
            for (var cycle = 0; cycle < 300; cycle++) {
              final value = random.nextInt(256);
              upstream.valid.inject(random.nextBool() ? 1 : 0);
              upstream.data.inject(value);
              downstream.ready.inject(random.nextBool() ? 1 : 0);

              expect(queue.occupancy.value.toInt(), expected.length,
                  reason: 'cycle $cycle');
              expect(queue.empty.value.toBool(), expected.isEmpty);
              expect(queue.full.value.toBool(), expected.length == depth);
              expect(queue.almostFull.value.toBool(),
                  expected.length >= depth - 1);
              expect(queue.almostEmpty.value.toBool(), expected.length <= 1);

              await clk.nextPosedge;
              final inputAccepted = upstream.ready.previousValue!.toBool() &&
                  upstream.valid.previousValue!.toBool();
              final outputValid = downstream.valid.previousValue!.toBool();
              final outputAccepted =
                  outputValid && downstream.ready.previousValue!.toBool();
              if (outputValid) {
                if (expected.isEmpty) {
                  expect(policy, ReadyValidQueuePolicy.fallThrough);
                  expect(downstream.data.previousValue!.toInt(), value);
                } else {
                  expect(downstream.data.previousValue!.toInt(), expected.first,
                      reason: 'cycle $cycle');
                }
              }
              if (outputAccepted && expected.isNotEmpty) {
                expected.removeFirst();
                if (inputAccepted) {
                  expected.addLast(value);
                }
              } else if (inputAccepted && !outputAccepted) {
                expected.addLast(value);
              }

              await clk.nextNegedge;
            }

            upstream.valid.inject(0);
            downstream.ready.inject(0);
            flush.inject(1);
            await clk.nextPosedge;
            await clk.nextNegedge;
            expect(queue.occupancy.value.toInt(), 0);
            expect(queue.empty.value.toBool(), isTrue);
          } finally {
            await Simulator.endSimulation();
          }
        });
      }
    }
  }

  for (final storage in ReadyValidQueueStorage.values) {
    for (final policy in ReadyValidQueuePolicy.values) {
      test('$storage $policy replaces a full typed entry', () async {
        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic();
        final upstream = ReadyValidInterface<_Packet>(_Packet());
        final downstream = ReadyValidInterface<_Packet>(_Packet());
        final queue = ReadyValidQueue<_Packet>(
          clk: clk,
          reset: reset,
          upstream: upstream,
          downstream: downstream,
          depth: 1,
          policy: policy,
          storage: storage,
        );
        await queue.build();
        expect(queue.upstream.data, isA<_Packet>());
        expect(queue.downstream.data, isA<_Packet>());
        unawaited(Simulator.run());
        try {
          reset.inject(1);
          upstream.valid.inject(0);
          downstream.ready.inject(0);
          await clk.nextPosedge;
          await clk.nextNegedge;
          reset.inject(0);
          upstream.valid.inject(1);
          upstream.data.payload.inject(17);
          await clk.nextPosedge;
          await clk.nextNegedge;
          expect(queue.full.value.toBool(), isTrue);
          expect(downstream.data.payload.value.toInt(), 17);

          upstream.data.payload.inject(34);
          downstream.ready.inject(1);
          await clk.nextPosedge;
          expect(upstream.ready.previousValue!.toBool(), isTrue);
          expect(downstream.valid.previousValue!.toBool(), isTrue);
          expect(downstream.data.payload.previousValue!.toInt(), 17);
          await clk.nextNegedge;
          expect(queue.full.value.toBool(), isTrue);
          expect(downstream.data.payload.value.toInt(), 34);

          upstream.valid.inject(0);
          downstream.ready.inject(0);
          await clk.nextPosedge;
          await clk.nextNegedge;
          expect(downstream.valid.value.toBool(), isTrue);
          expect(downstream.data.payload.value.toInt(), 34);
        } finally {
          await Simulator.endSimulation();
        }
      });
    }
  }

  test('queue rejects invalid depth and thresholds', () {
    ReadyValidQueue<Logic> makeQueue(int depth, {int? almostFullThreshold}) =>
        ReadyValidQueue<Logic>(
          clk: Logic(),
          reset: Logic(),
          upstream: ReadyValidInterface(Logic(width: 8)),
          downstream: ReadyValidInterface(Logic(width: 8)),
          depth: depth,
          almostFullThreshold: almostFullThreshold,
        );

    expect(() => makeQueue(0), throwsArgumentError);
    expect(() => makeQueue(1, almostFullThreshold: 2), throwsArgumentError);
  });
}
