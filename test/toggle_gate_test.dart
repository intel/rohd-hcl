// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// toggle_gate_test.dart
// Tests for the toggle gate.
//
// 2024 October
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  for (final withClockGating in [true, false]) {
    for (final resetValue in [null, Const(0x12, width: 8), 0x34]) {
      test(
          'gates data toggles to only when enabled,'
          ' withClockGating=$withClockGating, resetValue=$resetValue',
          () async {
        final enable = Logic()..inject(0);
        final data = Logic(width: 8)..inject(0xab);
        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic()..inject(0);
        final toggleGate = ToggleGate(
          enable: enable,
          data: data,
          clk: clk,
          reset: reset,
          resetValue: resetValue,
          clockGateControlIntf: withClockGating
              ? null
              : ClockGateControlInterface(isPresent: false),
        );

        await toggleGate.build();

        Simulator.setMaxSimTime(1000);
        unawaited(Simulator.run());

        reset.inject(1);
        await clk.waitCycles(3);

        if (resetValue == null) {
          expect(toggleGate.gatedData.value.toInt(), 0);
        } else if (resetValue is Logic) {
          expect(toggleGate.gatedData.value, resetValue.value);
        } else {
          expect(toggleGate.gatedData.value.toInt(), resetValue);
        }

        enable.inject(1);

        LogicValue? lastEnabledVal;
        clk.posedge.listen((_) {
          if (enable.value.toBool()) {
            expect(toggleGate.gatedData.value, data.value);
            lastEnabledVal = data.value;
          } else {
            expect(toggleGate.gatedData.value, lastEnabledVal);
          }
        });

        await clk.waitCycles(3);

        reset.inject(0);

        await clk.waitCycles(2);

        for (var i = 0; i < 5; i++) {
          data.inject(i + 7);
          await clk.waitCycles(1);
        }

        await clk.waitCycles(2);

        for (var i = 0; i < 20; i++) {
          data.inject(2 * i + 9);
          enable.inject(i % 7 > 2);
          await clk.waitCycles(1);
        }

        await clk.waitCycles(2);

        await Simulator.endSimulation();
      });
    }
  }
}
