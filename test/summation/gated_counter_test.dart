// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// gated_counter_test.dart
// Tests for the gated counter.
//
// 2024 October
// Author: Max Korbel <max.korbel@intel.com>

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
    bool printActivity = false,
    bool doChecks = true,
    bool printSv = false,
    Future<void> Function()? stimulus,
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

    await (stimulus?.call() ?? clk.waitCycles(numCycles));

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

  test(
      'simple 1-counter incrementing always, with rollover,'
      ' clock gating disabled', () async {
    final toggleCounter = await testCounter(
      (clk, reset) => GatedCounter(
        [SumInterface(fixedAmount: 1)],
        clk: clk,
        reset: reset,
        width: 6,
        clockGateControlInterface: ClockGateControlInterface(isPresent: false),
      ),
    );

    expect(toggleCounter.lowerActivity, greaterThan(0.95));
    expect(toggleCounter.upperActivity, greaterThan(0.95));
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
        width: 8,
        clkGatePartitionIndex: 4,
      ),
      numCycles: 1000,
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
        width: 8,
        clkGatePartitionIndex: 4,
      ),
      numCycles: 1000,
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

    expect(toggleCounter.lowerActivity, lessThan(0.51));
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

  test('increment by variable amount, properly gates', () async {
    final toggleCounter = await testCounter(
      (clk, reset) {
        final intf = SumInterface(width: 9, hasEnable: true)..enable!.inject(1);

        var clkCount = 0;
        clk.posedge.listen((_) {
          clkCount++;

          intf.amount.inject(clkCount % 3);
        });

        return GatedCounter(
          [intf],
          clk: clk,
          reset: reset,
          width: 9,
          clkGatePartitionIndex: 6,
        );
      },
      numCycles: 1000,
    );

    expect(toggleCounter.lowerActivity, lessThan(0.7));
    expect(toggleCounter.upperActivity, lessThan(0.5));
  });

  test('multiple interfaces', () async {
    final toggleCounter = await testCounter(
      (clk, reset) {
        final intf1 = SumInterface(width: 10, hasEnable: true)
          ..enable!.inject(1);
        final intf2 = SumInterface(width: 1, hasEnable: true)
          ..enable!.inject(1);
        final intf3 = SumInterface(fixedAmount: 3, hasEnable: true)
          ..enable!.inject(1);

        var clkCount = 0;
        clk.posedge.listen((_) {
          clkCount++;

          intf1.amount.inject(clkCount % 3);
          intf1.enable!.inject(clkCount % 5 > 2);

          intf2.amount.inject(clkCount % 2);
          intf2.enable!.inject(clkCount % 7 > 2);

          intf3.enable!.inject(clkCount % 3 > 1);
        });

        return GatedCounter(
          [intf1, intf2, intf3],
          clk: clk,
          reset: reset,
          width: 10,
          clkGatePartitionIndex: 6,
        );
      },
      numCycles: 1000,
    );

    expect(toggleCounter.lowerActivity, lessThan(0.65));
    expect(toggleCounter.upperActivity, lessThan(0.6));
  });
}
