// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// arbiter_test.dart
// Tests for arbiters
//
// 2023 March 13
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });
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

  group('round robin', () {
    final rrArbTypes = [
      (name: 'mask', constructor: MaskRoundRobinArbiter.new),
      (name: 'rotate', constructor: RotateRoundRobinArbiter.new),
    ];

    for (final rrArbType in rrArbTypes) {
      group(rrArbType.name, () {
        test('simple directed', () async {
          final clk = SimpleClockGenerator(10).clk;
          const width = 8;
          final vector = Logic(width: width);
          final reset = Logic();
          final reqs = List.generate(width, (i) => vector[i]);
          final arb = rrArbType.constructor(reqs, clk: clk, reset: reset);
          final grants = arb.grants.rswizzle();
          await arb.build();
          unawaited(Simulator.run());

          vector.put(bin('01001001'));
          reset.put(1); //Reset arbiter
          await clk.nextNegedge;
          await clk.nextNegedge;
          reset.put(0);
          expect(grants.value, LogicValue.ofString('00000001'));
          await clk.nextNegedge;
          expect(grants.value, LogicValue.ofString('00001000'));
          await clk.nextNegedge;
          expect(grants.value, LogicValue.ofString('01000000'));
          await clk.nextNegedge;
          expect(grants.value, LogicValue.ofString('00000001'));
          await clk.nextNegedge;
          expect(grants.value, LogicValue.ofString('00001000'));
          await clk.nextNegedge;
          expect(grants.value, LogicValue.ofString('01000000'));
          await clk.nextNegedge;
          expect(grants.value, LogicValue.ofString('00000001'));
          await clk.nextNegedge;
          vector.put(bin('00000000'));
          expect(grants.value, LogicValue.ofString('00000000'));
          await clk.nextNegedge;
          vector.put(bin('11001010'));
          expect(grants.value, LogicValue.ofString('00000010'));
          await clk.nextNegedge;
          expect(grants.value, LogicValue.ofString('00001000'));
          await clk.nextNegedge;
          expect(grants.value, LogicValue.ofString('01000000'));
          await clk.nextNegedge;
          expect(grants.value, LogicValue.ofString('10000000'));
          await clk.nextNegedge;
          expect(grants.value, LogicValue.ofString('00000010'));

          Simulator.endSimulation();
          await Simulator.simulationEnded;
        });

        test('dynamic request', () async {
          final clk = SimpleClockGenerator(10).clk;
          const width = 8;
          final vector = Logic(width: width);
          final reset = Logic();
          final reqs = List.generate(width, (i) => vector[i]);
          final arb = rrArbType.constructor(reqs, clk: clk, reset: reset);
          final grants = arb.grants.rswizzle();
          await arb.build();
          unawaited(Simulator.run());

          reset.put(1); //Reset arbiter
          await clk.nextNegedge;
          await clk.nextNegedge;
          reset.put(0);
          vector.put(bin('01000111'));
          expect(grants.value, LogicValue.ofString('00000001'));
          await clk.nextNegedge;
          vector.put(bin('10000101'));
          expect(grants.value, LogicValue.ofString('00000100'));
          await clk.nextNegedge;
          vector.put(bin('01001000'));
          expect(grants.value, LogicValue.ofString('00001000'));
          await clk.nextNegedge;
          vector.put(bin('10010001'));
          expect(grants.value, LogicValue.ofString('00010000'));
          await clk.nextNegedge;
          vector.put(bin('10000000'));
          expect(grants.value, LogicValue.ofString('10000000'));
          await clk.nextNegedge;
          expect(grants.value, LogicValue.ofString('10000000'));
          vector.put(bin('10000000'));
          expect(grants.value, LogicValue.ofString('10000000'));
          await clk.nextNegedge;
          vector.put(bin('10010001'));
          expect(grants.value, LogicValue.ofString('00000001'));
          await clk.nextNegedge;
          expect(grants.value, LogicValue.ofString('00010000'));
          await clk.nextNegedge;
          expect(grants.value, LogicValue.ofString('10000000'));
          await clk.nextNegedge;
          expect(grants.value, LogicValue.ofString('00000001'));
          await clk.nextNegedge;
          expect(grants.value, LogicValue.ofString('00010000'));
          await clk.nextNegedge;
          expect(grants.value, LogicValue.ofString('10000000'));

          Simulator.endSimulation();
          await Simulator.simulationEnded;
        });

        test('all reqs', () async {
          final clk = SimpleClockGenerator(10).clk;
          final reset = Logic();
          final requests = List.generate(8, (index) => Const(1));
          final arbiter =
              rrArbType.constructor(requests, clk: clk, reset: reset);
          await arbiter.build();
          Simulator.setMaxSimTime(5000);
          unawaited(Simulator.run());

          reset.inject(0);
          await clk.nextNegedge;
          reset.inject(1);
          await clk.nextNegedge;
          await clk.nextNegedge;
          reset.inject(0);
          for (var i = 0; i < 30; i++) {
            expect(arbiter.grants.rswizzle().value.toInt(), 1 << (i % 8));
            await clk.nextNegedge;
          }

          Simulator.endSimulation();
          await Simulator.simulationEnded;
        });

        test('all reqs, non-power-of-2', () async {
          final clk = SimpleClockGenerator(10).clk;
          final reset = Logic();
          final requests = List.generate(5, (index) => Const(1));
          final arbiter =
              rrArbType.constructor(requests, clk: clk, reset: reset);
          await arbiter.build();
          Simulator.setMaxSimTime(5000);
          unawaited(Simulator.run());

          reset.inject(0);
          await clk.nextNegedge;
          reset.inject(1);
          await clk.nextNegedge;
          await clk.nextNegedge;
          reset.inject(0);
          for (var i = 0; i < 30; i++) {
            expect(arbiter.grants.rswizzle().value.toInt(),
                1 << (i % arbiter.count));
            await clk.nextNegedge;
          }

          Simulator.endSimulation();
          await Simulator.simulationEnded;
        });

        test('beat pattern 2 request maintain fairness', () async {
          final clk = SimpleClockGenerator(10).clk;
          final reset = Logic();
          final req = Logic()..inject(0);
          final requests = List.generate(2, (index) => req);
          final arbiter =
              rrArbType.constructor(requests, clk: clk, reset: reset);
          await arbiter.build();

          WaveDumper(arbiter);

          final grantCounts = List.generate(arbiter.count, (_) => 0);

          for (var i = 0; i < arbiter.count; i++) {
            final grant = arbiter.grants[i];
            clk.negedge.listen((event) {
              if (grant.value.isValid && grant.value.toBool()) {
                grantCounts[i]++;
              }
            });
          }

          Simulator.setMaxSimTime(5000);
          unawaited(Simulator.run());

          reset.inject(0);
          await clk.nextNegedge;
          reset.inject(1);
          await clk.nextNegedge;
          await clk.nextNegedge;
          reset.inject(0);
          for (var i = 0; i < 32; i++) {
            req.inject(i % 2);
            await clk.nextPosedge;
          }

          Simulator.endSimulation();
          await Simulator.simulationEnded;

          // expect an equal number of grants between the two
          expect(grantCounts[0], grantCounts[1]);
        });
      });
    }
  });
}
