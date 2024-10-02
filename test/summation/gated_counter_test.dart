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

  Future<ClockToggleCounter> testCounter(
    GatedCounter Function(Logic clk, Logic reset) genCounter, {
    int numCycles = 150,
    bool dumpWaves = false,
  }) async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..inject(1);

    final dut = genCounter(clk, reset);

    await dut.build();

    if (dumpWaves) {
      WaveDumper(dut);
    }

    checkCounter(dut);

    final toggleCounter = ClockToggleCounter(dut);

    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());

    await clk.waitCycles(3);
    reset.inject(0);

    await clk.waitCycles(numCycles);

    await Simulator.endSimulation();

    return toggleCounter;
  }

  test('simple 1-counter incrementing always', () async {
    final toggleCounter = await testCounter((clk, reset) => GatedCounter(
          [SumInterface(fixedAmount: 1)],
          clk: clk,
          reset: reset,
          width: 6,
        ));

    expect(toggleCounter.lowerActivity, greaterThan(0.95));
    expect(toggleCounter.upperActivity, lessThan(0.75));
  });

  test('simple 1-counter incrementing always with saturation', () async {
    final toggleCounter = await testCounter((clk, reset) => GatedCounter(
          [SumInterface(fixedAmount: 1)],
          clk: clk,
          reset: reset,
          width: 6,
          clkGatePartitionIndex: 3,
          saturates: true,
        ));

    expect(toggleCounter.lowerActivity, lessThan(0.45));
    expect(toggleCounter.upperActivity, lessThan(0.25));
  });

  test('simple big-fixed counter incrementing only upper bits', () async {
    final toggleCounter = await testCounter(
      (clk, reset) => GatedCounter(
        [SumInterface(fixedAmount: 8)],
        clk: clk,
        reset: reset,
        width: 6,
        clkGatePartitionIndex: 3,
      ),
      dumpWaves: true,
    );

    expect(toggleCounter.lowerActivity, lessThan(0.5));
    expect(toggleCounter.upperActivity, greaterThan(0.95));
  });

  //TODO: testplan:
  // - when nothing is enabled, whole counter is gated
  // - toggle gate does a good job of gating toggles, enabling clock for it properly

  //TODO: checks that clock is actually gating in some interesting cases!
}
