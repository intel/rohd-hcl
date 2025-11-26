// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// counter_test.dart
// Tests for the counter.
//
// 2024 August 26
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

import 'summation_test_utils.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('basic 1-bit rolling counter', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final enable = Logic()..inject(1);

    final counter =
        Counter.ofLogics([Const(1)], clk: clk, reset: reset, enable: enable);

    await counter.build();

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    // little reset routine
    reset.inject(0);
    await clk.nextNegedge;
    reset.inject(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.inject(0);

    // check initial value
    expect(counter.count.value.toInt(), 0);

    // wait a cycle, see 1
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 1);

    // wait a cycle, should overflow (1-bit counter), back to 0
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 0);

    // wait a cycle, see 1
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 1);

    enable.inject(0);
    // wait a cycle, no change
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 1);
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 1);

    enable.inject(1);

    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;

    await Simulator.endSimulation();
  });

  test('simple up counter', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final counter = Counter.simple(clk: clk, reset: reset, maxValue: 5);

    await counter.build();

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    // little reset routine
    reset.inject(0);
    await clk.nextNegedge;
    reset.inject(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.inject(0);

    expect(counter.overflowed.value.toBool(), false);
    expect(counter.underflowed.value.toBool(), false);
    expect(counter.equalsMax.value.toBool(), false);
    expect(counter.equalsMin.value.toBool(), true);

    for (var i = 0; i < 20; i++) {
      expect(counter.count.value.toInt(), i % 6);

      if (i % 6 == 5) {
        expect(counter.overflowed.value.toBool(), false);
        expect(counter.equalsMax.value.toBool(), true);
        expect(counter.equalsMin.value.toBool(), false);
      } else if (i % 6 == 0 && i > 0) {
        expect(counter.overflowed.value.toBool(), true);
        expect(counter.equalsMax.value.toBool(), false);
        expect(counter.equalsMin.value.toBool(), true);
      } else {
        expect(counter.overflowed.value.toBool(), false);
        expect(counter.equalsMax.value.toBool(), false);
        if (i % 6 != 0) {
          expect(counter.equalsMin.value.toBool(), false);
        } else {
          expect(counter.equalsMin.value.toBool(), true);
        }
      }

      expect(counter.underflowed.value.toBool(), false);

      await clk.nextNegedge;
    }

    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;

    await Simulator.endSimulation();
  });

  test('simple down counter', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final counter = Counter.simple(
        clk: clk, reset: reset, maxValue: 5, resetValue: 5, increments: false);

    await counter.build();

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    // little reset routine
    reset.inject(0);
    await clk.nextNegedge;
    reset.inject(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.inject(0);

    expect(counter.overflowed.value.toBool(), false);
    expect(counter.underflowed.value.toBool(), false);
    expect(counter.equalsMax.value.toBool(), true);
    expect(counter.equalsMin.value.toBool(), false);

    for (var i = 0; i < 20; i++) {
      expect(counter.count.value.toInt(), 5 - (i % 6));

      if (i % 6 == 5) {
        expect(counter.underflowed.value.toBool(), false);
        expect(counter.equalsMax.value.toBool(), false);
        expect(counter.equalsMin.value.toBool(), true);
      } else if (i % 6 == 0 && i > 0) {
        expect(counter.underflowed.value.toBool(), true);
        expect(counter.equalsMax.value.toBool(), true);
        expect(counter.equalsMin.value.toBool(), false);
      } else {
        expect(counter.underflowed.value.toBool(), false);
        expect(counter.equalsMin.value.toBool(), false);
        if (i % 6 != 0) {
          expect(counter.equalsMax.value.toBool(), false);
        } else {
          expect(counter.equalsMax.value.toBool(), true);
        }
      }

      expect(counter.overflowed.value.toBool(), false);

      await clk.nextNegedge;
    }

    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;

    await Simulator.endSimulation();
  });

  test('simple up/down counter', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final inc = Logic()..put(0);
    final dec = Logic()..put(0);
    final counter = Counter.updn(
        clk: clk, reset: reset, enableInc: inc, enableDec: dec, maxValue: 5);

    await counter.build();

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    // little reset routine
    reset.inject(0);
    await clk.nextNegedge;
    reset.inject(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.inject(0);

    expect(counter.overflowed.value.toBool(), false);
    expect(counter.underflowed.value.toBool(), false);
    expect(counter.equalsMax.value.toBool(), false);
    expect(counter.equalsMin.value.toBool(), true);

    // increment by 3
    await clk.nextNegedge;
    inc.inject(1);
    await clk.waitCycles(3);
    await clk.nextNegedge;
    inc.inject(0);
    expect(counter.count.value.toInt(), 3);

    await clk.waitCycles(5);

    // decrement by 2
    await clk.nextNegedge;
    dec.inject(1);
    await clk.waitCycles(2);
    await clk.nextNegedge;
    dec.inject(0);
    expect(counter.count.value.toInt(), 1);

    await clk.waitCycles(5);

    // increment + decrement
    await clk.nextNegedge;
    inc.inject(1);
    dec.inject(1);
    await clk.nextNegedge;
    inc.inject(0);
    dec.inject(0);
    expect(counter.count.value.toInt(), 1);

    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;

    await Simulator.endSimulation();
  });

  test('reset and restart counter', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final restart = Logic();

    final counter = Counter(
      [
        SumInterface(fixedAmount: 4),
        SumInterface(fixedAmount: 2, increments: false),
      ],
      clk: clk,
      reset: reset,
      restart: restart,
      resetValue: 10,
      maxValue: 15,
      saturates: true,
      width: 8,
    );

    await counter.build();

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    // little reset routine
    reset.inject(0);
    restart.inject(0);
    await clk.nextNegedge;
    reset.inject(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.inject(0);

    // check initial value after reset drops
    expect(counter.count.value.toInt(), 10);

    // increment each cycle
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 12);
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 14);
    expect(counter.overflowed.value.toBool(), false);

    // saturate
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 15);
    expect(counter.overflowed.value.toBool(), true);
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 15);
    expect(counter.overflowed.value.toBool(), true);

    // restart (not reset!)
    restart.inject(1);

    // now we should catch the next +2 still, not miss it
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 12);

    // and hold there
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 12);

    // drop it and should continue
    restart.inject(0);
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 14);

    // now back to reset
    reset.inject(1);
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 10);
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 10);

    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;

    await Simulator.endSimulation();
  });

  test('async reset, clock tied off', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final restart = Logic();

    final counter = Counter(
      [
        SumInterface(fixedAmount: 4),
        SumInterface(fixedAmount: 2, increments: false),
      ],
      clk: Const(0),
      reset: reset,
      restart: restart,
      asyncReset: true,
      resetValue: 4,
      maxValue: 10,
      minValue: 1,
    );

    await counter.build();

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());
    // initializing/resetting with no clock
    await clk.waitCycles(2);
    reset.inject(0);
    restart.inject(0);
    await clk.nextNegedge;
    reset.inject(1);
    await clk.nextPosedge;
    expect(counter.count.value.toInt(), 4);

    await clk.waitCycles(2);
    await Simulator.endSimulation();
  });

  test('async reset with clock', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final restart = Logic();

    final counter = Counter(
      [
        SumInterface(fixedAmount: 4),
        SumInterface(fixedAmount: 2, increments: false),
      ],
      clk: clk,
      reset: reset,
      restart: restart,
      asyncReset: true,
      resetValue: 2,
      maxValue: 20,
      minValue: 1,
    );

    await counter.build();

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    // initial reset flow
    reset.inject(0);
    restart.inject(0);
    await clk.nextNegedge;
    reset.inject(1);
    await clk.nextPosedge;
    reset.inject(0);

    // check counter counts
    await clk.waitCycles(4);
    expect(counter.count.value.toInt(), 10);

    // reset
    reset.inject(1);
    await clk.nextChanged;
    expect(counter.count.previousValue!.toInt(), 2);
    await clk.waitCycles(2);

    await Simulator.endSimulation();
  });

  group('random counter', () {
    const numRandCounters = 20;
    const restartProbability = 0.05;

    final counterTypes = ['normal', 'gated'];

    for (final counterType in counterTypes) {
      group(counterType, () {
        for (var counterIdx = 0; counterIdx < numRandCounters; counterIdx++) {
          test('$counterIdx', () async {
            const numCycles = 500;

            final rand = Random(456 + counterIdx ^ counterType.hashCode);

            final cfg = genRandomSummationConfiguration(rand);

            final clk = SimpleClockGenerator(10).clk;
            Simulator.setMaxSimTime(numCycles * 10 * 2 + 100);

            final reset = Logic()..inject(1);
            final restart = rand.nextBool() ? Logic() : null;

            final dut = counterType == 'normal'
                ? Counter(
                    cfg.interfaces,
                    clk: clk,
                    reset: reset,
                    restart: restart,
                    minValue: cfg.minValue,
                    maxValue: cfg.maxValue,
                    saturates: cfg.saturates,
                    width: cfg.width,
                    resetValue: cfg.initialValue,
                  )
                : GatedCounter(cfg.interfaces,
                    clk: clk,
                    reset: reset,
                    restart: restart,
                    minValue: cfg.minValue,
                    maxValue: cfg.maxValue,
                    saturates: cfg.saturates,
                    width: cfg.width,
                    resetValue: cfg.initialValue,
                    gateToggles: rand.nextBool(),
                    clkGatePartitionIndex:
                        rand.nextBool() ? null : rand.nextInt(11) - 1);

            await dut.build();

            unawaited(Simulator.run());

            // reset flow
            reset.inject(1);
            restart?.inject(0);
            for (final intf in cfg.interfaces) {
              if (intf.hasEnable) {
                intf.enable!.inject(0);
              }
              intf.amount.inject(0);
            }
            await clk.waitCycles(3);
            reset.inject(0);
            await clk.waitCycles(3);

            // set up checking on edges
            checkCounter(dut);

            await clk.waitCycles(3);

            // randomize inputs on the interfaces of the counter
            for (var i = 0; i < numCycles; i++) {
              await clk.nextPosedge;

              for (final intf in cfg.interfaces) {
                if (intf.hasEnable) {
                  intf.enable!.inject(rand.nextBool());
                }

                if (intf.fixedAmount == null) {
                  intf.amount.inject(
                    // put 0 sometimes, for clk gating to trigger more
                    rand.nextBool() ? rand.nextInt(1 << intf.width) : 0,
                  );
                }
              }

              restart?.inject(rand.nextDouble() < restartProbability);
            }

            await clk.waitCycles(10);

            await Simulator.endSimulation();
          });
        }
      });
    }
  });
}
