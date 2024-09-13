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

// class CustomClockGate extends ClockGate {
//   Logic get _override => input('override');

//   CustomClockGate(super.clk, super.enable,
//       {required Logic override, super.reset}) {
//     addInput('override', override);
//   }

//   @override
//   Logic generateGatedClk() => CustomClockGateMacro(
//         clk: freeClk,
//         en: enable,
//         override: _override,
//       ).gatedClk;
// }

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
  CounterWithSimpleClockGate(Logic clk, Logic incr, Logic reset,
      {bool withDelay = true, ClockGateControlInterface? cgIntf})
      : super(name: 'clk_gated_counter') {
    if (cgIntf != null) {
      cgIntf = ClockGateControlInterface.clone(cgIntf!)
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
      hasDelay: withDelay,
    );

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

  //TODO: explicit test for custom override, port gets punched, etc.

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

    // print(counter.generateSynth());

    expect(counter.tryInput('anotherOverride'), isNotNull);

    // WaveDumper(counter);

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

            // WaveDumper(counter);

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

            await Simulator.endSimulation();

            // print(counter.generateSynth());
          });
        }
      }
    }
  });
}
