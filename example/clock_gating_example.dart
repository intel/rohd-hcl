// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// clock_gating_example.dart
// Example of how to use clock gating.
//
// 2024 September 24
// Author: Max Korbel <max.korbel@intel.com>

// ignore_for_file: avoid_print

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A very simple counter that has clock gating internally.
class CounterWithSimpleClockGate extends Module {
  Logic get count => output('count');

  CounterWithSimpleClockGate({
    required Logic clk,
    required Logic incr,
    required Logic reset,
    required ClockGateControlInterface cgIntf,
  }) : super(name: 'clk_gated_counter') {
    clk = addInput('clk', clk);
    incr = addInput('incr', incr);
    reset = addInput('reset', reset);

    // We clone the incoming interface, receiving all config information with it
    cgIntf = cgIntf.clone()..pairConnectIO(this, cgIntf, PairRole.consumer);

    // In this case, we want to enable the clock any time we're incrementing
    final clkEnable = incr;

    // Build the actual clock gate component.
    final clkGate = ClockGate(
      clk,
      enable: clkEnable,
      reset: reset,
      controlIntf: cgIntf,
      delayControlledSignals: true,
    );

    final count = addOutput('count', width: 8);
    count <=
        flop(
          // access the gated clock from the component
          clkGate.gatedClk,

          // depending on configuration default, `controlled` signals are
          // delayed by 1 cycle (in this case we enable it)
          count + clkGate.controlled(incr).zeroExtend(count.width),

          reset: reset,
        );
  }
}

/// A reference to an external SystemVerilog clock-gating macro.
class CustomClockGateMacro extends Module with SystemVerilog {
  Logic get gatedClk => output('gatedClk');

  CustomClockGateMacro({
    required Logic clk,
    required Logic en,
    required Logic override,
    required Logic anotherOverride,
  }) : super(name: 'custom_clock_gate_macro') {
    // make sure ports match the SystemVerilog
    clk = addInput('clk', clk);
    en = addInput('en', en);
    override = addInput('override', override);
    anotherOverride = addInput('another_override', anotherOverride);
    addOutput('gatedClk');

    // simulation-only behavior
    gatedClk <= clk & flop(~clk, en | override | anotherOverride);
  }

  // define how to instantiate this custom SystemVerilog
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

Future<void> main({bool noPrint = false}) async {
  // Build a custom version of the clock gating control interface which uses our
  // custom macro.
  final customClockGateControlIntf = ClockGateControlInterface(
    hasEnableOverride: true,
    additionalPorts: [
      // we add an additional override port, for example, which is passed
      // automatically down the hierarchy
      Logic.port('anotherOverride'),
    ],
    gatedClockGenerator: (intf, clk, enable) => CustomClockGateMacro(
      clk: clk,
      en: enable,
      override: intf.enableOverride!,
      anotherOverride: intf.port('anotherOverride'),
    ).gatedClk,
  );

  // Generate a simple clock. This will run along by itself as
  // the Simulator goes.
  final clk = SimpleClockGenerator(10).clk;

  // ... and some additional signals
  final reset = Logic();
  final incr = Logic();

  final counter = CounterWithSimpleClockGate(
    clk: clk,
    reset: reset,
    incr: incr,
    cgIntf: customClockGateControlIntf,
  );

  // build the module and attach a waveform viewer for debug
  await counter.build();

  // Let's see what this module looks like as SystemVerilog, so we can pass it
  // to other tools.
  final systemVerilogCode = counter.generateSynth();
  if (!noPrint) {
    print(systemVerilogCode);
  }

  // Now let's try simulating!

  // Attach a waveform dumper so we can see what happens.
  if (!noPrint) {
    WaveDumper(counter);
  }

  // Start off with a disabled counter and asserting reset at the start.
  incr.inject(0);
  reset.inject(1);

  // leave overrides turned off
  customClockGateControlIntf.enableOverride!.inject(0);
  customClockGateControlIntf.port('anotherOverride').inject(0);

  Simulator.setMaxSimTime(1000);
  unawaited(Simulator.run());

  // wait a bit before dropping reset
  await clk.waitCycles(3);
  reset.inject(0);

  // wait a bit before raising incr
  await clk.waitCycles(5);
  incr.inject(1);

  // leave it high for a bit, then drop it
  await clk.waitCycles(5);
  incr.inject(0);

  // wait a little longer, then end the test
  await clk.waitCycles(5);
  await Simulator.endSimulation();

  // Now we can review the waves to see how the gated clock does not toggle
  // while gated!
}
