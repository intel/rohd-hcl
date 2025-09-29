// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// replacement_test.dart
// Replacement policy tests.
//
// 2025 September 12
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/memory/replacement_policy.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('pLRU test', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    const ways = 16;

    final hit = AccessInterface(ways);
    final hit2 = AccessInterface(ways);
    final miss = AccessInterface(ways);
    final invalidate = AccessInterface(ways);

    final repl = PseudoLRUReplacement(
        clk, reset, [hit, hit2], [miss], [invalidate],
        ways: ways);
    await repl.build();
    unawaited(Simulator.run());

    // Reset flow

    invalidate.access.inject(0);
    invalidate.way.inject(0);
    reset.inject(0);
    hit.access.inject(0);
    hit.way.inject(0);
    hit2.access.inject(0);
    miss.access.inject(0);
    miss.way.inject(0);
    await clk.nextPosedge;
    await clk.nextPosedge;
    reset.inject(1);
    await clk.nextPosedge;
    reset.inject(0);
    // End reset flow.

    // Hit item should be LRU and not seen early in miss processing.
    await clk.nextPosedge;
    await clk.nextPosedge;
    const id1 = 6;
    const id2 = 12;
    hit.access.inject(1);
    hit.way.inject(id1);
    hit2.access.inject(1);
    hit2.way.inject(id2);
    await clk.nextPosedge;
    hit.access.inject(0);
    hit2.access.inject(0);

    // Pure miss processing
    miss.access.inject(1);
    final shortMisses = <int>[];
    for (var i = 0; i < ways ~/ 2; i++) {
      await clk.nextPosedge;
      shortMisses.add(miss.way.value.toInt());
    }
    for (final m in shortMisses) {
      expect(m != id1, isTrue, reason: '$id1 produces as miss: $m');
      expect(m != id2, isTrue, reason: '$id2 produces as miss: $m');
    }
    await clk.nextPosedge;
    miss.access.inject(1);
    final misses = <int>[];
    for (var i = 0; i < ways; i++) {
      await clk.nextPosedge;
      misses.add(miss.way.value.toInt());
    }
    misses.sort();
    // Make sure we got all ways.
    for (var i = 0; i < ways; i++) {
      expect(misses[i], i);
    }
    await Simulator.endSimulation();
  });
}
