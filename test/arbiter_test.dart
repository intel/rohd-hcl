// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// arbiter_test.dart
// Tests for arbiters
//
// 2023 March 13
// Author: Max Korbel <max.korbel@intel.com>
//
import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  test('priority arbiter', () async {
    const width = 8;

    final vector = Logic(width: width);
    final reqs = List.generate(width, (i) => vector[i]);

    final arb = PriorityArbiter(reqs);

    final grantVec = arb.grants.rswizzle();

    vector.put(bin('00000000'));
    expect(grantVec.value, LogicValue.ofString('00000000'));

    vector.put(bin('00000001'));
    expect(grantVec.value, LogicValue.ofString('00000001'));

    vector.put(bin('00010000'));
    expect(grantVec.value, LogicValue.ofString('00010000'));

    vector.put(bin('00010100'));
    expect(grantVec.value, LogicValue.ofString('00000100'));
  });
  test('round robin logic', () async {
    final clk = SimpleClockGenerator(10).clk;

    const width = 8;

    final vector = Logic(width: width);
    final reset = Logic();
    final reqs = List.generate(width, (i) => vector[i]);
    final arb = RoundRobinArbiterlogic(reqs, clk, reset);
    final grants = arb.grants.rswizzle();
    await arb.build();
    //WaveDumper(arb);
    unawaited(Simulator.run());
    vector.put(bin('01001001'));
    reset.put(1); //Reset arbiter
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.put(0);
    await clk.nextNegedge;
    expect(grants.value, LogicValue.ofString('00000001'));
    await clk.nextNegedge;
    expect(grants.value, LogicValue.ofString('00001000'));
    await clk.nextNegedge;
    expect(grants.value, LogicValue.ofString('01000000'));
    await clk.nextNegedge; //All requests attended, therefore resets
    expect(grants.value, LogicValue.ofString('00000001'));
    await clk.nextNegedge;
    expect(grants.value, LogicValue.ofString('00001000'));
    await clk.nextNegedge;
    expect(grants.value, LogicValue.ofString('01000000'));
    await clk.nextNegedge;
    expect(grants.value, LogicValue.ofString('00000001'));
    vector.put(bin('00000000'));
    await clk.nextNegedge;
    expect(grants.value, LogicValue.ofString('00000000'));
    vector.put(bin('11001010'));
    await clk.nextNegedge;
    expect(grants.value, LogicValue.ofString('00000010'));
    await clk.nextNegedge;
    expect(grants.value, LogicValue.ofString('00001000'));
    await clk.nextNegedge;
    expect(grants.value, LogicValue.ofString('01000000'));
    await clk.nextNegedge;
    expect(grants.value, LogicValue.ofString('10000000'));
    Simulator.endSimulation();
    await Simulator.simulationEnded;
  });

  test('Round Robin dynamic request test', () async {
    final clk = SimpleClockGenerator(10).clk;

    const width = 8;

    final vector = Logic(width: width);
    final reset = Logic();
    final reqs = List.generate(width, (i) => vector[i]);
    final arb = RoundRobinArbiterlogic(reqs, clk, reset);
    final grants = arb.grants.rswizzle();
    await arb.build();
    unawaited(Simulator.run());
    vector.put(bin('01000111'));
    reset.put(1); //Reset arbiter
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.put(0);
    await clk.nextNegedge;
    expect(grants.value, LogicValue.ofString('00000001'));
    vector.put(bin('10000101'));
    await clk.nextNegedge;
    expect(grants.value, LogicValue.ofString('00000100'));
    vector.put(bin('01001000'));
    await clk.nextNegedge;
    expect(grants.value, LogicValue.ofString('00001000'));
    vector.put(bin('10010001'));
    await clk.nextNegedge;
    expect(grants.value, LogicValue.ofString('00010000'));
    vector.put(bin('10000000'));
    await clk.nextNegedge;
    expect(grants.value, LogicValue.ofString('10000000'));
    vector.put(bin('10000000'));
    await clk.nextNegedge;
    expect(grants.value, LogicValue.ofString('10000000'));
    vector.put(bin('10010001'));
    await clk.nextNegedge;
    expect(grants.value, LogicValue.ofString('00000001'));
    await clk.nextNegedge;
    expect(grants.value, LogicValue.ofString('00010000'));
    await clk.nextNegedge;
    expect(grants.value, LogicValue.ofString('10000000'));
    await clk.nextNegedge;
    expect(grants.value, LogicValue.ofString('00000001'));
    await clk.nextNegedge;
    expect(grants.value, LogicValue.ofString('00010000'));
    Simulator.endSimulation();
    await Simulator.simulationEnded;
  });
}
