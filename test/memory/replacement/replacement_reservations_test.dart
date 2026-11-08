// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// replacement_reservations_test.dart
// Tests persistent reservations and deferred policy commits.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _ReservationsHarness extends Module {
  _ReservationsHarness() {
    final reserves = [
      for (var i = 0; i < 2; i++) ReplacementAccessInterface(3)
    ];
    final releases = [
      for (var i = 0; i < 2; i++) ReplacementAccessInterface(3)
    ];
    for (var i = 0; i < 2; i++) {
      reserves[i].en <= addInput('reserve$i', Logic());
      reserves[i].index <=
          addInput('reserveIndex$i', Logic(width: 2), width: 2);
      releases[i].en <= addInput('release$i', Logic());
      releases[i].index <=
          addInput('releaseIndex$i', Logic(width: 2), width: 2);
    }
    final dut = ReplacementReservations(
      clk: addInput('clk', Logic()),
      reset: addInput('reset', Logic()),
      entryCount: 3,
      reserves: reserves,
      releases: releases,
    );
    addOutput('mask', width: 3) <= dut.reservedMask;
    addOutput('badReserve') <= dut.invalidReserve;
    addOutput('badRelease') <= dut.invalidRelease;
  }
}

class _CommitHarness extends Module {
  _CommitHarness({required bool tree, bool behavioral = false}) {
    final count = tree ? 4 : 3;
    final allocation = ReplacementAllocationInterface(count);
    final commit = ReplacementCommitInterface(count);
    allocation.en <= addInput('alloc', Logic());
    allocation.commit <= Const(0);
    commit.en <= addInput('commit', Logic());
    commit.index <= addInput('index', Logic(width: 2), width: 2);
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final valid = Const((1 << count) - 1, width: count);
    final factory =
        tree ? CacheReplacement.treePseudoLru : CacheReplacement.roundRobin;
    final policy = behavioral
        ? BehavioralReplacementPolicy(
            clk: clk,
            reset: reset,
            validMask: valid,
            eligibleMask: valid,
            accesses: [],
            allocations: [allocation],
            commits: [commit],
            entryCount: count,
            kind: tree
                ? BehavioralReplacementKind.treePseudoLru
                : BehavioralReplacementKind.roundRobin,
          )
        : factory.buildWithCommits!(
            clk: clk,
            reset: reset,
            validMask: valid,
            eligibleMask: valid,
            accesses: [],
            allocations: [allocation],
            commits: [commit],
            entryCount: count,
            name: 'policy',
          );
    addOutput('victim', width: 2) <= allocation.index;
    addOutput('badCommit') <= policy.invalidCommit;
  }
}

void main() {
  tearDown(Simulator.reset);

  test('reservations persist, release, and detect invalid operations',
      () async {
    final dut = _ReservationsHarness();
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'reserve0': 0,
        'reserveIndex0': 0,
        'reserve1': 0,
        'reserveIndex1': 2,
        'release0': 0,
        'releaseIndex0': 0,
        'release1': 0,
        'releaseIndex1': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'reserve0': 1, 'reserve1': 1},
          {'mask': 0, 'badReserve': 0}),
      Vector({'clk': 1}, {'mask': 5}),
      Vector({'clk': 0, 'reserve0': 0, 'reserve1': 0}, {'mask': 5}),
      Vector({'clk': 1}, {'mask': 5}),
      Vector({
        'clk': 0,
        'release0': 1,
        'releaseIndex0': 0,
        'reserve0': 1,
        'reserveIndex0': 0,
      }, {
        'badReserve': 0,
        'badRelease': 0
      }),
      Vector({'clk': 1}, {'mask': 5}),
      Vector({'clk': 0, 'release0': 0, 'reserve0': 1}, {'badReserve': 1}),
      Vector({'reserve0': 0, 'release0': 1, 'releaseIndex0': 1},
          {'badRelease': 1}),
      Vector({'release0': 0, 'reserve0': 1, 'reserveIndex0': 3},
          {'badReserve': 1}),
      Vector({'reserve0': 0, 'release0': 1, 'releaseIndex0': 2},
          {'badRelease': 0}),
      Vector({'clk': 1}, {'mask': 1}),
      Vector({'clk': 0, 'release0': 0, 'reset': 1}, {}),
      Vector({'clk': 1}, {'mask': 0}),
      Vector({
        'clk': 0,
        'reset': 0,
        'reserve0': 1,
        'reserveIndex0': 1,
        'reserve1': 1,
        'reserveIndex1': 1,
      }, {
        'badReserve': 1
      }),
      Vector({'clk': 1}, {'mask': 2}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  for (final tree in [false, true]) {
    for (final behavioral in [false, true]) {
      test(
          '${tree ? 'tree PLRU' : 'round robin'} deferred commit '
          'behavioral=$behavioral', () async {
        final dut = _CommitHarness(tree: tree, behavioral: behavioral);
        final vectors = [
          Vector(
              {'clk': 0, 'reset': 1, 'alloc': 1, 'commit': 0, 'index': 0}, {}),
          Vector({'clk': 1}, {}),
          Vector({'clk': 0, 'reset': 0}, {'victim': 0, 'badCommit': 0}),
          Vector({'commit': 1, 'index': tree ? 0 : 1},
              {'victim': 2, 'badCommit': 0}),
          Vector({'clk': 1}, {'victim': 2}),
          Vector({'clk': 0, 'commit': 0}, {'victim': 2}),
          if (!tree)
            Vector({'commit': 1, 'index': 3}, {'victim': 2, 'badCommit': 1}),
        ];
        await dut.build();
        await SimCompare.checkFunctionalVector(dut, vectors);
        if (!behavioral) {
          SimCompare.checkIverilogVector(dut, vectors);
        }
      });
    }
  }
}
