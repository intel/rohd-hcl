import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/summation/gated_counter.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

import 'summation_test_utils.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('simple 1-counter incrementing always', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..inject(1);
    final dut = GatedCounter([SumInterface(fixedAmount: 1)],
        clk: clk, reset: reset, width: 4, clkGatePartitionIndex: 2);

    await dut.build();

    checkCounter(dut);

    WaveDumper(dut);

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    await clk.waitCycles(3);
    reset.inject(0);

    await clk.waitCycles(50);

    await Simulator.endSimulation();
  });

  //TODO: checks that clock is actually gating in some interesting cases!
}
