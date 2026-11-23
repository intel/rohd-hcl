// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tensor_tile_iterator_test.dart
// Tests for Tensor Tile Iterator.
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

  test('iterates retained M/N/K extents with K innermost', () async {
    final fixture = _IteratorFixture();
    await fixture.buildAndReset();

    await fixture.startIteration(m: 2, n: 2, k: 3);
    final coordinates = <(int, int, int)>[];
    final lastFlags = <bool>[];
    while (fixture.dut.busy.value == LogicValue.one) {
      coordinates.add((
        fixture.dut.mIndex.value.toInt(),
        fixture.dut.nIndex.value.toInt(),
        fixture.dut.kIndex.value.toInt(),
      ));
      lastFlags.add(fixture.dut.last.value == LogicValue.one);
      fixture.advance.inject(1);
      await fixture.clk.nextPosedge;
      await fixture.clk.nextNegedge;
    }

    expect(coordinates, [
      (0, 0, 0),
      (0, 0, 1),
      (0, 0, 2),
      (0, 1, 0),
      (0, 1, 1),
      (0, 1, 2),
      (1, 0, 0),
      (1, 0, 1),
      (1, 0, 2),
      (1, 1, 0),
      (1, 1, 1),
      (1, 1, 2),
    ]);
    expect(lastFlags.where((flag) => flag), hasLength(1));
    expect(lastFlags.last, isTrue);
    expect(fixture.dut.done.value, LogicValue.one);
    await Simulator.endSimulation();
  });

  test('rejects zero extents and a start while busy', () async {
    final fixture = _IteratorFixture();
    await fixture.buildAndReset();

    await fixture.startIteration(m: 0, n: 2, k: 2);
    expect(fixture.dut.busy.value, LogicValue.zero);
    expect(fixture.dut.invalidExtent.value, LogicValue.one);

    fixture.start.inject(0);
    await fixture.clk.nextPosedge;
    await fixture.startIteration(m: 2, n: 1, k: 1);
    fixture.start.inject(1);
    await fixture.clk.nextPosedge;
    await fixture.clk.nextNegedge;
    expect(fixture.dut.startRejected.value, LogicValue.one);
    await Simulator.endSimulation();
  });
}

class _IteratorFixture {
  final Logic clk = SimpleClockGenerator(10).clk;
  final Logic reset = Logic();
  final Logic start = Logic();
  final Logic advance = Logic();
  final Logic mTiles = Logic(width: 3);
  final Logic nTiles = Logic(width: 3);
  final Logic kTiles = Logic(width: 3);
  late final TensorTileIterator dut = TensorTileIterator(
    clk: clk,
    reset: reset,
    start: start,
    advance: advance,
    mTiles: mTiles,
    nTiles: nTiles,
    kTiles: kTiles,
  );

  Future<void> buildAndReset() async {
    await dut.build();
    Simulator.setMaxSimTime(5000);
    unawaited(Simulator.run());
    reset.inject(1);
    start.inject(0);
    advance.inject(0);
    mTiles.inject(0);
    nTiles.inject(0);
    kTiles.inject(0);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextNegedge;
  }

  Future<void> startIteration({
    required int m,
    required int n,
    required int k,
  }) async {
    mTiles.inject(m);
    nTiles.inject(n);
    kTiles.inject(k);
    start.inject(1);
    await clk.nextPosedge;
    start.inject(0);
    await clk.nextNegedge;
  }
}
