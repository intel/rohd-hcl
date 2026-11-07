// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// toggle_gate.dart
// A gate to reduce toggling for power savings.
//
// 2024 October
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/clock_gating.dart';

/// A gate for signals to avoid toggling when not needed.
class ToggleGate extends Module {
  /// The gated version of original data which will only toggle when the gate is
  /// enabled.
  Logic get gatedData => output('gatedData');

  /// Constructs a [ToggleGate] to reduce power consumption by reducing toggling
  /// of the [gatedData] signal when [enable] is not asserted.
  ///
  /// When [enable] is high, the [gatedData] signal will be the same as the
  /// [data] signal. When [enable] is low, the [gatedData] signal will be the
  /// same as the last value of [data] when [enable] was high.
  ///
  /// If [resetValue] is provided, then the [gatedData] signal will be set to
  /// that when [reset].
  ///
  /// If no [clockGateControlIntf] is provided (left `null`), then a default
  /// clock gating implementation will be included for the internal sequential
  /// elements.
  ToggleGate(
      {required Logic enable,
      required Logic data,
      required Logic clk,
      required Logic reset,
      dynamic resetValue,
      ClockGateControlInterface? clockGateControlIntf,
      super.name = 'toggle_gate',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(definitionName: definitionName ?? 'ToggleGate_W${data.width}') {
    enable = addInput('enable', enable);
    data = addInput('data', data, width: data.width);
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    if (resetValue != null && resetValue is Logic) {
      resetValue = addInput('resetValue', resetValue, width: resetValue.width);
    }

    if (clockGateControlIntf != null) {
      clockGateControlIntf = clockGateControlIntf.clone()
        ..pairConnectIO(this, clockGateControlIntf, PairRole.consumer);
    }

    addOutput('gatedData', width: data.width);

    final lastData = Logic(name: 'lastData', width: data.width);

    final gateEnable = enable & (lastData.neq(data));

    final clkGate = ClockGate(
      clk,
      enable: gateEnable,
      reset: reset,
      controlIntf: clockGateControlIntf,
    );

    lastData <=
        flop(
            clkGate.gatedClk,
            en: clkGate.isPresent ? null : gateEnable,
            reset: reset,
            resetValue: resetValue,
            data);

    gatedData <=
        mux(
          enable,
          data,
          lastData,
        );
  }
}
