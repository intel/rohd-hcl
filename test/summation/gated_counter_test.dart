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
  int totalToggles = -1;

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
    bool printActivity = false,
    bool doChecks = true,
    bool printSv = false,
  }) async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..inject(1);

    final dut = genCounter(clk, reset);

    await dut.build();

    if (dumpWaves) {
      WaveDumper(dut);
    }

    if (printSv) {
      // ignore: avoid_print
      print(dut.generateSynth());
    }

    if (doChecks) {
      checkCounter(dut);
    }

    final toggleCounter = ClockToggleCounter(dut);

    Simulator.setMaxSimTime(2 * numCycles * 10);
    unawaited(Simulator.run());

    await clk.waitCycles(3);
    reset.inject(0);

    await clk.waitCycles(numCycles);

    await Simulator.endSimulation();

    if (printActivity) {
      // ignore: avoid_print
      print('Upper activity: ${toggleCounter.upperActivity}');
      // ignore: avoid_print
      print('Lower activity: ${toggleCounter.lowerActivity}');
    }

    return toggleCounter;
  }

  test('simple 1-counter incrementing always, with rollover', () async {
    final toggleCounter = await testCounter(
      (clk, reset) => GatedCounter(
        [SumInterface(fixedAmount: 1)],
        clk: clk,
        reset: reset,
        width: 6,
      ),
    );

    expect(toggleCounter.lowerActivity, greaterThan(0.95));
    expect(toggleCounter.upperActivity, lessThan(0.75));
  });

  test('simple 1-counter incrementing always, with saturation', () async {
    final toggleCounter = await testCounter(
      (clk, reset) => GatedCounter(
        [SumInterface(fixedAmount: 1)],
        clk: clk,
        reset: reset,
        width: 6,
        clkGatePartitionIndex: 3,
        saturates: true,
      ),
    );

    expect(toggleCounter.lowerActivity, lessThan(0.45));
    expect(toggleCounter.upperActivity, lessThan(0.25));
  });

  test('simple 1-down-counter decrementing always, with rollover', () async {
    final toggleCounter = await testCounter(
      (clk, reset) => GatedCounter(
        [SumInterface(fixedAmount: 1, increments: false)],
        resetValue: 63,
        clk: clk,
        reset: reset,
        width: 6,
        clkGatePartitionIndex: 3,
      ),
    );

    expect(toggleCounter.lowerActivity, greaterThan(0.95));
    expect(toggleCounter.upperActivity, lessThan(0.25));
  });

  test('simple 1-down-counter decrementing always, with saturation', () async {
    final toggleCounter = await testCounter(
      (clk, reset) => GatedCounter(
        [SumInterface(fixedAmount: 1, increments: false)],
        saturates: true,
        resetValue: 63,
        clk: clk,
        reset: reset,
        width: 6,
        clkGatePartitionIndex: 3,
      ),
    );

    expect(toggleCounter.lowerActivity, lessThan(0.50));
    expect(toggleCounter.upperActivity, lessThan(0.15));
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
    );

    expect(toggleCounter.lowerActivity, lessThan(0.5));
    expect(toggleCounter.upperActivity, greaterThan(0.95));
  });

  test('disabled increment turns off whole counter', () async {
    final toggleCounter = await testCounter(
      (clk, reset) {
        final enable = Logic()..inject(0);

        var clkCount = 0;
        var mod = 2;
        clk.posedge.listen((_) {
          if (clkCount >= mod) {
            enable.inject(~enable.value);
            clkCount = 0;
            mod++;
          } else {
            clkCount++;
          }
        });

        return GatedCounter(
          [SumInterface(fixedAmount: 1, hasEnable: true)..enable!.gets(enable)],
          clk: clk,
          reset: reset,
          width: 6,
          clkGatePartitionIndex: 3,
        );
      },
    );

    expect(toggleCounter.lowerActivity, lessThan(0.5));
    expect(toggleCounter.upperActivity, lessThan(0.4));
  });

  //TODO: testplan:
  // - toggle gate does a good job of gating toggles, enabling clock for it properly
  // - decrementing counter stuff
  // - variable numbers
  // - multiple interfaces
}
