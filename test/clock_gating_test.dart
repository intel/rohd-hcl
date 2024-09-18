import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/clock_gating.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

class CustomClockGateMacro extends Module with CustomSystemVerilog {
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
    gatedClk <= clk & (en | override | anotherOverride);
  }

  @override
  String instantiationVerilog(String instanceType, String instanceName,
          Map<String, String> inputs, Map<String, String> outputs) =>
      '`CUSTOM_CLOCK_GATE('
      '${outputs['gatedClk']}, '
      '${inputs['clk']}, '
      '${inputs['en']}, '
      '${inputs['override']}, '
      '${inputs['another_override']}'
      ')';
}

class CustomClockGateControlInterface extends ClockGateControlInterface {
  Logic get anotherOverride => port('anotherOverride');

  CustomClockGateControlInterface({super.isPresent})
      : super(
            hasEnableOverride: true,
            additionalPorts: [
              Port('anotherOverride'),
            ],
            gatedClockGenerator: (intf, clk, enable) => CustomClockGateMacro(
                  clk: clk,
                  en: enable,
                  override: intf.enableOverride!,
                  anotherOverride: intf.port('anotherOverride'),
                ).gatedClk);
}

class CounterWithSimpleClockGate extends Module {
  Logic get count => output('count');

  /// A probe for testing.
  late final Logic _gatedClk;

  CounterWithSimpleClockGate(Logic clk, Logic incr, Logic reset,
      {bool withDelay = true, ClockGateControlInterface? cgIntf})
      : super(name: 'clk_gated_counter') {
    if (cgIntf != null) {
      cgIntf = ClockGateControlInterface.clone(cgIntf)
        ..pairConnectIO(this, cgIntf, PairRole.consumer);
    }

    clk = addInput('clk', clk);
    incr = addInput('incr', incr);
    reset = addInput('reset', reset);

    final clkEnable = incr;
    final clkGate = ClockGate(
      clk,
      enable: clkEnable,
      reset: reset,
      controlIntf: cgIntf,
      delayControlledSignals: withDelay,
    );

    _gatedClk = clkGate.gatedClk;

    final count = addOutput('count', width: 8);
    count <=
        flop(
          clkGate.gatedClk,
          count + clkGate.controlled(incr).zeroExtend(count.width),
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

    // ignore: invalid_use_of_protected_member
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

    await counter._gatedClk.nextPosedge;
    final t1 = Simulator.time;
    await counter._gatedClk.nextPosedge;
    expect(Simulator.time, t1 + 10);

    cgIntf.anotherOverride.inject(0);

    unawaited(counter._gatedClk.nextPosedge.then((_) {
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

            if ((cgIntf?.hasEnableOverride ?? false) && enOverride) {
              cgIntf!.enableOverride!.inject(1);
            } else {
              cgIntf?.enableOverride?.inject(0);
            }

            if (cgIntf is CustomClockGateControlInterface) {
              cgIntf.anotherOverride.inject(1);
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

            if (hasOverride) {
              if (cgIntf is CustomClockGateControlInterface) {
                cgIntf.anotherOverride.inject(0);
              }

              cgIntf!.enableOverride!.inject(1);

              await counter._gatedClk.nextPosedge;
              final t1 = Simulator.time;
              await counter._gatedClk.nextPosedge;
              expect(Simulator.time, t1 + 10);

              cgIntf.enableOverride!.inject(0);

              unawaited(counter._gatedClk.nextPosedge.then((_) {
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
