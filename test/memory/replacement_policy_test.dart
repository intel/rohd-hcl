// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// replacement_test.dart
// Replacement policy tests.
//
// 2025 September 12
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
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
    await clk.waitCycles(2);

    reset.inject(1);
    await clk.nextPosedge;
    reset.inject(0);
    // End reset flow.

    // Hit item should be LRU and not seen early in miss processing.
    await clk.waitCycles(2);

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

  group('Test PLRU instantiated in PseudoLRUReplacement', () {
    final clk = Logic();
    final reset = Logic();
    const ways = 8;
    final bi = <int>[0, 1, 1, 0, 0, 1, 1];

    final hits = List<AccessInterface>.generate(2, (i) => AccessInterface(ways),
        growable: false);
    final allocs = List<AccessInterface>.generate(
        1, (i) => AccessInterface(ways),
        growable: false);
    final invals = List<AccessInterface>.generate(
        1, (i) => AccessInterface(ways),
        growable: false);

    final plru =
        PseudoLRUReplacement(clk, reset, hits, allocs, invals, ways: ways);

    // This is an example of combinational method testing inside a module rather
    // than having to setup state and sequencing to test this functionality.
    test('PLRU write invalidate', () async {
      final bv = [for (var i = 0; i < 7; i++) Logic()];
      for (var i = 0; i < bv.length; i++) {
        bv[i].put(bi[i]);
      }
      var brv = bv.rswizzle();

      for (final a in [5, 1, 6, 2, 4, 0, 7]) {
        brv = plru.hitPLRU(brv, Const(a, width: 3), invalidate: Const(1));
        expect(a, plru.allocPLRU(brv).value.toInt());
      }
    });

    test('PLRU hit', () async {
      final bv = [for (var i = 0; i < 7; i++) Logic()];
      for (var i = 0; i < bv.length; i++) {
        bv[i].put(bi[i]);
      }

      var brv = bv.rswizzle();

      for (final a in [5, 1, 6, 2, 4, 0, 7, 3, 5, 1, 6, 2, 4, 0, 7, 3]) {
        brv = plru.hitPLRU(brv, Const(a, width: 3));
      }
      expect(plru.allocPLRU(brv).value.toInt(), 5);
    });
  });
}
