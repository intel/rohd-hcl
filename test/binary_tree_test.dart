// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// binary_tree_test.dart
// Tests of the BinaryTree generator.
//
// 2025 January 8
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('binary tree of adders', () async {
    final clk = SimpleClockGenerator(10).clk;

    const width = 17;
    const length = 290;
    final vec = <Logic>[];
    // First sum will be length *(length-1) /2
    for (var i = 0; i < length; i++) {
      vec.add(Const(i, width: width));
    }
    final prefixAdd =
        BinaryTreeModule(vec, (a, b) => a + b, clk: clk, depthToFlop: 1);

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
    await clk.waitCycles(prefixAdd.flopDepth - cycles);
    await clk.nextNegedge;
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

  test('binary tree ary of adders', () async {
    final clk = SimpleClockGenerator(10).clk;

    const width = 17;
    const length = 290;
    final ary = LogicArray([length], width);
    // FIrst sum will be length *(length-1) /2
    for (var i = 0; i < length; i++) {
      ary.elements[i].put(i);
    }

    final prefixAdd =
        BinaryTreeAryModule(ary, (a, b) => a + b, clk: clk, depthToFlop: 1);

    await prefixAdd.build();
    WaveDumper(prefixAdd);
    unawaited(Simulator.run());
    var cycles = 0;
    await clk.nextNegedge;
    cycles++;
    // second sum will be length
    for (var i = 0; i < length; i++) {
      ary.elements[i].inject(1);
    }
    await clk.nextNegedge;
    cycles++;
    // third sum will be length *2
    for (var i = 0; i < length; i++) {
      ary.elements[i].inject(2);
    }
    await clk.waitCycles(prefixAdd.flopDepth - cycles);
    await clk.nextNegedge;
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
