// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_clock_gating.dart
// Configurators for clock and toggle gating.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Shared controls for optional clock-gate interfaces.
abstract class _ClockControlConfigurator extends Configurator {
  /// Whether to expose a clock-gate control interface.
  final ToggleConfigKnob includeControlInterfaceKnob =
      ToggleConfigKnob(value: false);

  /// Whether the control interface includes an enable override input.
  final ToggleConfigKnob enableOverrideKnob = ToggleConfigKnob(value: false);

  /// Creates the selected optional clock-gate control interface.
  ClockGateControlInterface? createControlInterface() =>
      includeControlInterfaceKnob.value
          ? ClockGateControlInterface(
              hasEnableOverride: enableOverrideKnob.value)
          : null;

  /// Adds common clock-control knobs to [knobs].
  Map<String, ConfigKnob<dynamic>> withClockControlKnobs(
          Map<String, ConfigKnob<dynamic>> knobs) =>
      {
        ...knobs,
        'Generate Control Interface': includeControlInterfaceKnob,
        if (includeControlInterfaceKnob.value)
          'Generate Enable Override': enableOverrideKnob,
      };
}

/// A [Configurator] for [ClockGate].
class ClockGateConfigurator extends _ClockControlConfigurator {
  /// Whether controlled signals are delayed by a cycle.
  final ToggleConfigKnob delayControlledSignalsKnob =
      ToggleConfigKnob(value: false);

  /// Whether to generate a reset input.
  final ToggleConfigKnob includeResetKnob = ToggleConfigKnob(value: false);

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => withClockControlKnobs({
        'Delay Controlled Signals': delayControlledSignalsKnob,
        'Generate Reset Input': includeResetKnob,
      });

  @override
  Module createModule() => ClockGate(
        Logic(),
        enable: Logic(),
        reset: includeResetKnob.value ? Logic() : null,
        controlIntf: createControlInterface(),
        delayControlledSignals: delayControlledSignalsKnob.value,
      );

  @override
  String get name => 'Clock Gate';
}

/// A [Configurator] for [ToggleGate].
class ToggleGateConfigurator extends _ClockControlConfigurator {
  /// Width of the gated data.
  final IntConfigKnob dataWidthKnob = IntConfigKnob(value: 8);

  /// Optional reset value for the gated data.
  final IntOptionalConfigKnob resetValueKnob =
      IntOptionalConfigKnob(value: null);

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => withClockControlKnobs({
        'Data Width': dataWidthKnob,
        'Reset Value': resetValueKnob,
      });

  @override
  Module createModule() => ToggleGate(
        enable: Logic(),
        data: Logic(width: dataWidthKnob.value),
        clk: Logic(),
        reset: Logic(),
        resetValue: resetValueKnob.value,
        clockGateControlIntf: createControlInterface(),
      );

  @override
  String get name => 'Toggle Gate';
}
