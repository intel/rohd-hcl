// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// clock_gating_test.dart
// Tests for clock gating.
//
// 2024 September 18
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/clock_gating.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

class CustomClockGateMacro extends Module with SystemVerilog {
  Logic get gatedClk => output('gatedClk');

  CustomClockGateMacro({
    required Logic clk,
    required Logic en,
    required Logic override,
    required Logic anotherOverride,
  }) : super(name: 'custom_clock_gate_macro') {
    clk = addInput('clk', clk);
    en = addInput('en', en);
    override = addInput('override', override);
    anotherOverride = addInput('another_override', anotherOverride);

    addOutput('gatedClk');

    // simulation-only behavior
    gatedClk <= clk & flop(~clk, en | override | anotherOverride);
  }

  @override
  String instantiationVerilog(String instanceType, String instanceName,
          Map<String, String> ports) =>
      '`CUSTOM_CLOCK_GATE('
      '${ports['gatedClk']}, '
      '${ports['clk']}, '
      '${ports['en']}, '
      '${ports['override']}, '
      '${ports['another_override']}'
      ')';
}

class CustomClockGateControlInterface extends ClockGateControlInterface {
  Logic get anotherOverride => port('anotherOverride');

  CustomClockGateControlInterface({super.isPresent})
      : super(
            hasEnableOverride: true,
            additionalPorts: [
              Logic.port('anotherOverride'),
            ],
            gatedClockGenerator: (intf, clk, enable) => CustomClockGateMacro(
                  clk: clk,
                  en: enable,
                  override: intf.enableOverride!,
                  anotherOverride: intf.port('anotherOverride'),
                ).gatedClk);

  @override
  CustomClockGateControlInterface clone() =>
      CustomClockGateControlInterface(isPresent: isPresent);
}

class CounterWithSimpleClockGate extends Module {
  Logic get count => output('count');

  /// A probe for clock gating.
  late final ClockGate _clkGate;

  CounterWithSimpleClockGate(Logic clk, Logic incr, Logic reset,
      {bool withDelay = true, ClockGateControlInterface? cgIntf})
      : super(name: 'clk_gated_counter') {
    if (cgIntf != null) {
      cgIntf = cgIntf.clone()..pairConnectIO(this, cgIntf, PairRole.consumer);
    }

    clk = addInput('clk', clk);
    incr = addInput('incr', incr);
    reset = addInput('reset', reset);

    final clkEnable = incr;
    _clkGate = ClockGate(
      clk,
      enable: clkEnable,
      reset: reset,
      controlIntf: cgIntf,
      delayControlledSignals: withDelay,
    );

    final count = addOutput('count', width: 8);
    count <=
        flop(
          _clkGate.gatedClk,
          count + _clkGate.controlled(incr).zeroExtend(count.width),
          reset: reset,
        );
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('custom clock gating port', () async {
    final cgIntf = CustomClockGateControlInterface();

    cgIntf.enableOverride!.inject(0);
    cgIntf.anotherOverride.inject(1);

    final clk = SimpleClockGenerator(10).clk;
    final incr = Logic()..inject(0);
    final reset = Logic();

    final counter = CounterWithSimpleClockGate(
      clk,
      incr,
      reset,
      cgIntf: cgIntf,
    );

    await counter.build();

    final sv = counter.generateSynth();
    expect(sv, contains('anotherOverride'));
    expect(sv, contains('CUSTOM_CLOCK_GATE'));

    expect(counter.tryInput('anotherOverride'), isNotNull);

    Simulator.setMaxSimTime(500);
    unawaited(Simulator.run());

    reset.inject(1);
    await clk.waitCycles(3);
    reset.inject(0);
    await clk.waitCycles(3);

    incr.inject(1);
    await clk.waitCycles(5);
    incr.inject(0);
    await clk.waitCycles(5);

    expect(counter.count.value.toInt(), 5);

    cgIntf.anotherOverride.inject(1);

    await counter._clkGate.gatedClk.nextPosedge;
    final t1 = Simulator.time;
    await counter._clkGate.gatedClk.nextPosedge;
    expect(Simulator.time, t1 + 10);

    cgIntf.anotherOverride.inject(0);

    unawaited(counter._clkGate.gatedClk.nextPosedge.then((_) {
      fail('Expected a gated clock, no more toggles');
    }));

    await clk.waitCycles(5);

    await Simulator.endSimulation();
  });

  group('basic clock gating', () {
    final clockGatingTypes = {
      'none': () => null,
      'normal': ClockGateControlInterface.new,
      'normal not present': () => ClockGateControlInterface(isPresent: false),
      'override': () => ClockGateControlInterface(hasEnableOverride: true),
      'custom': CustomClockGateControlInterface.new,
    };

    for (final withDelay in [true, false]) {
      for (final cgType in clockGatingTypes.entries) {
        final hasOverride = cgType.value()?.hasEnableOverride ?? false;
        for (final enOverride in [
          if (hasOverride) true,
          false,
        ]) {
          test(
              [
                cgType.key,
                if (withDelay) 'with delay',
                if (hasOverride) 'override: $enOverride',
              ].join(', '), () async {
            final cgIntf = cgType.value();

            final overrideSignal = cgIntf is CustomClockGateControlInterface
                ? (cgIntf.anotherOverride..inject(0))
                : cgIntf?.enableOverride;
            cgIntf?.enableOverride?.inject(0);

            if (enOverride) {
              overrideSignal?.inject(1);
            } else {
              overrideSignal?.inject(0);
            }

            final clk = SimpleClockGenerator(10).clk;
            final incr = Logic()..inject(0);
            final reset = Logic();

            final counter = CounterWithSimpleClockGate(
              clk,
              incr,
              reset,
              cgIntf: cgIntf,
              withDelay: withDelay,
            );

            await counter.build();

            // WaveDumper(counter);

            var clkToggleCount = 0;
            counter._clkGate.gatedClk.posedge.listen((_) {
              clkToggleCount++;
            });

            Simulator.setMaxSimTime(500);
            unawaited(Simulator.run());

            reset.inject(1);
            await clk.waitCycles(3);
            reset.inject(0);
            await clk.waitCycles(3);

            incr.inject(1);
            await clk.waitCycles(5);
            incr.inject(0);
            await clk.waitCycles(5);

            expect(counter.count.value.toInt(), 5);

            if (counter._clkGate.isPresent && !enOverride) {
              if (counter._clkGate.delayControlledSignals) {
                expect(clkToggleCount, lessThanOrEqualTo(7 + 4));
              } else {
                expect(clkToggleCount, lessThanOrEqualTo(6 + 4));
              }
            } else {
              expect(clkToggleCount, greaterThanOrEqualTo(14));
            }

            if (hasOverride) {
              if (cgIntf is CustomClockGateControlInterface) {
                cgIntf.anotherOverride.inject(0);
              }

              cgIntf!.enableOverride!.inject(1);

              await counter._clkGate.gatedClk.nextPosedge;
              final t1 = Simulator.time;
              await counter._clkGate.gatedClk.nextPosedge;
              expect(Simulator.time, t1 + 10);

              cgIntf.enableOverride!.inject(0);

              unawaited(counter._clkGate.gatedClk.nextPosedge.then((_) {
                fail('Expected a gated clock, no more toggles');
              }));

              await clk.waitCycles(5);
            }

            await Simulator.endSimulation();
          });
        }
      }
    }
  });
}
