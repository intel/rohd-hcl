// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// edge_detector_test.dart
// Tests for edge detector.
//
// 2024 January 29
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  Future<void> testEdgeDetector(Edge edgeType) async {
    final clk = SimpleClockGenerator(10).clk;
    final a = Logic();
    final mod = EdgeDetector(a, clk: clk, edgeType: edgeType);
    await mod.build();
    final edge = mod.edge;

    Simulator.setMaxSimTime(200);
    unawaited(Simulator.run());

    a.inject(0);
    await clk.waitCycles(3);
    expect(edge.value.toBool(), isFalse);

    a.inject(1);

    await clk.nextNegedge;

    expect(edge.value.toBool(), edgeType == Edge.pos || edgeType == Edge.any);

    await clk.nextPosedge;

    await clk.nextNegedge;

    expect(edge.value.toBool(), isFalse);

    await clk.nextPosedge;

    a.inject(0);

    await clk.nextNegedge;

    expect(edge.value.toBool(), edgeType == Edge.neg || edgeType == Edge.any);

    await clk.nextPosedge;

    await clk.nextNegedge;

    expect(edge.value.toBool(), isFalse);

    await Simulator.endSimulation();
  }

  for (final edgeType in Edge.values) {
    test('${edgeType.name} edge detector', () async {
      await testEdgeDetector(edgeType);
    });
  }

  test('custom reset value', () async {
    final clk = SimpleClockGenerator(10).clk;
    final a = Logic();
    final reset = Logic();
    const resetValue = 1;
    final mod = EdgeDetector(
      a,
      clk: clk,
      reset: reset,
      resetValue: resetValue,
      edgeType: Edge.neg,
    );
    await mod.build();
    final edge = mod.edge;

    Simulator.setMaxSimTime(200);
    unawaited(Simulator.run());

    // leave `a` floating intentionally
    reset.inject(0);

    await clk.waitCycles(3);

    reset.inject(1);

    await clk.nextPosedge;
    reset.inject(0);
    a.inject(0);

    await clk.nextNegedge;

    expect(edge.value.toBool(), isTrue);

    await Simulator.endSimulation();
  });

  test('exception: bad width signal', () {
    expect(() => EdgeDetector(Logic(width: 2), clk: Logic()),
        throwsA(isA<RohdHclException>()));
  });

  test('exception: reset value without reset', () {
    expect(() => EdgeDetector(Logic(), clk: Logic(), resetValue: 5),
        throwsA(isA<RohdHclException>()));
  });
}
