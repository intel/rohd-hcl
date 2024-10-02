// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/summation/gated_counter.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

import 'summation_test_utils.dart';

class ClockToggleCounter {
  final GatedCounter dut;

  int upperToggles = 0;
  int lowerToggles = 0;
  int totalToggles = 0;

  ClockToggleCounter(this.dut) {
    dut.upperGatedClock.posedge.listen((_) => upperToggles++);
    dut.lowerGatedClock.posedge.listen((_) => lowerToggles++);
    dut.clk.posedge.listen((_) => totalToggles++);
  }

  double get upperActivity => upperToggles / totalToggles;
  double get lowerActivity => lowerToggles / totalToggles;
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('simple 1-counter incrementing always', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..inject(1);
    final dut = GatedCounter([SumInterface(fixedAmount: 1)],
        clk: clk, reset: reset, width: 6, clkGatePartitionIndex: 3);

    await dut.build();

    checkCounter(dut);
    final toggleCounter = ClockToggleCounter(dut);

    // WaveDumper(dut);
    // print(dut.generateSynth());

    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());

    await clk.waitCycles(3);
    reset.inject(0);

    await clk.waitCycles(150);

    await Simulator.endSimulation();

    expect(toggleCounter.lowerActivity, greaterThan(0.95));
    expect(toggleCounter.upperActivity, lessThan(0.75));
  });

  //TODO: testplan:
  // - if saturates, then no risk of over/underflow
  // - if incrementing by large amount, then lower bits don't need to enable?
  // - when nothing is enabled, whole counter is gated
  // - toggle gate does a good job of gating toggles, enabling clock for it properly

  //TODO: checks that clock is actually gating in some interesting cases!
}
