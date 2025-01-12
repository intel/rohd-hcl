// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// reduction_tree_test.dart
// Tests of the ReductionTreeNode generator.
//
// 2025 January 8
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/reduction_tree.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });
  Logic addReduce(List<Logic> inputs) {
    final a = inputs.reduce((v, e) => v + e);
    return a;
  }

  test('reduction tree of adders -- quick test', () async {
    final clk = SimpleClockGenerator(10).clk;

    const width = 17;
    const length = 79;
    final vec = <Logic>[];
    // First sum will be length *(length-1) /2
    var count = 0;
    for (var i = 0; i < length; i++) {
      vec.add(Const(i, width: width));
      count = count + i;
    }
    for (var reduce = 2; reduce < length; reduce++) {
      final prefixAdd =
          ReductionTreeModule(vec, reduce: reduce, addReduce, clk: clk);
      expect(prefixAdd.out.value.toInt(), equals(count));
    }
  });
  test('reduction tree of adders', () async {
    final clk = SimpleClockGenerator(10).clk;

    const width = 17;
    const length = 290;
    final vec = <Logic>[];
    // First sum will be length *(length-1) /2
    var count = 0;
    for (var i = 0; i < length; i++) {
      vec.add(Const(i, width: width));
      count = count + i;
    }
    for (var reduce = 2; reduce < length; reduce++) {
      final prefixAdd =
          ReductionTreeModule(vec, reduce: reduce, addReduce, clk: clk);
      expect(prefixAdd.out.value.toInt(), equals(count));
    }
  });

  test('reduction tree of adders', () async {
    final clk = SimpleClockGenerator(10).clk;

    const width = 17;
    const length = 290;
    final vec = <Logic>[];
    // First sum will be length *(length-1) /2
    for (var i = 0; i < length; i++) {
      vec.add(Const(i, width: width));
    }
    const reduce = 4;
    final prefixAdd = ReductionTreeModule(
        vec, reduce: reduce, addReduce, clk: clk, depthToFlop: 1);

    await prefixAdd.build();
    WaveDumper(prefixAdd);
    unawaited(Simulator.run());
    var cycles = 0;
    await clk.nextNegedge;
    cycles++;
    // second sum will be length
    for (var i = 0; i < length; i++) {
      vec[i].inject(1);
    }
    await clk.nextNegedge;
    cycles++;
    // third sum will be length *2
    for (var i = 0; i < length; i++) {
      vec[i].inject(2);
    }
    if (prefixAdd.flopDepth > cycles) {
      await clk.waitCycles(prefixAdd.flopDepth - cycles);
      await clk.nextNegedge;
    }
    expect(prefixAdd.out.value.toInt(), equals(length * (length - 1) / 2));
    await clk.nextNegedge;
    expect(prefixAdd.out.value.toInt(), equals(length));
    await clk.nextNegedge;
    expect(prefixAdd.out.value.toInt(), equals(length * 2));
    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;
    await Simulator.endSimulation();
  });

  Logic addReduceAdders(List<Logic> inputs) {
    if (inputs.length < 4) {
      return inputs.reduce((v, e) => v + e);
    } else {
      final add0 = ParallelPrefixAdder(inputs[0], inputs[1]);
      final add1 = ParallelPrefixAdder(inputs[2], inputs[3]);
      final add2 = ParallelPrefixAdder(add0.sum, add1.sum);
      return add2.sum;
    }
  }

  test('reduction tree of real adders', () async {
    final clk = SimpleClockGenerator(10).clk;

    const width = 17;
    const length = 290;
    final vec = <Logic>[];
    // First sum will be length *(length-1) /2
    for (var i = 0; i < length; i++) {
      vec.add(Const(i, width: width));
    }
    const reduce = 4;
    final prefixAdd = ReductionTreeModule(
        vec, reduce: reduce, addReduceAdders, clk: clk, depthToFlop: 1);

    await prefixAdd.build();
    WaveDumper(prefixAdd);
    unawaited(Simulator.run());
    var cycles = 0;
    await clk.nextNegedge;
    cycles++;
    // second sum will be length
    for (var i = 0; i < length; i++) {
      vec[i].inject(1);
    }
    await clk.nextNegedge;
    cycles++;
    // third sum will be length *2
    for (var i = 0; i < length; i++) {
      vec[i].inject(2);
    }
    if (prefixAdd.flopDepth > cycles) {
      await clk.waitCycles(prefixAdd.flopDepth - cycles);
      await clk.nextNegedge;
    }
    expect(prefixAdd.out.value.toInt(), equals(length * (length - 1) / 2));
    await clk.nextNegedge;
    expect(prefixAdd.out.value.toInt(), equals(length));
    await clk.nextNegedge;
    expect(prefixAdd.out.value.toInt(), equals(length * 2));
    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;
    await Simulator.endSimulation();
  });
}
