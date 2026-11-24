// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// p02_core_functor_test.dart
// Tests direct P02 routing cores without transport shells.
//
// 2026 November 23
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(Simulator.reset);

  test('policy mux returns the granted data and accepts only on service',
      () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(1);
    final service = Logic()..put(0);
    final first = Logic()..put(0);
    final second = Logic()..put(1);
    final binding = PolicyMuxCoreFunctor<Logic>(
      inputCount: 2,
      policy: fixedPriorityArbitrationPolicy,
    ).construct(
      PolicyMuxCoreRequest(
        clk: clk,
        reset: reset,
        payloads: [Logic(width: 8)..put(0x12), Logic(width: 8)..put(0x34)],
        requests: [first, second],
        service: service,
      ),
      name: 'mux',
    );
    await binding.module.build();
    unawaited(Simulator.run());
    await clk.nextNegedge;
    reset.inject(0);
    await clk.nextNegedge;
    expect(binding.grant.value.toInt(), 2);
    expect(binding.selectedData.value.toInt(), 0x34);
    expect(binding.accepted.value, LogicValue.zero);
    first.inject(1);
    service.inject(1);
    await clk.nextNegedge;
    expect(binding.grant.value.toInt(), 1);
    expect(binding.selectedData.value.toInt(), 0x12);
    expect(binding.acceptedGrant.value.toInt(), 1);
    await Simulator.endSimulation();
  });

  test('policy mux rejects a score width that differs from its configuration',
      () {
    final functor = PolicyMuxCoreFunctor<Logic>(
      inputCount: 2,
      policy: highestScoreArbitrationPolicy,
      policyInputWidths: const [3, 3],
    );
    expect(
      () => functor.construct(
        PolicyMuxCoreRequest(
          clk: Logic(),
          reset: Logic(),
          payloads: [Logic(width: 8), Logic(width: 8)],
          requests: [Logic(), Logic()],
          service: Logic(),
          policyInputs: [Logic(width: 2), Logic(width: 3)],
        ),
        name: 'mux',
      ),
      throwsArgumentError,
    );
  });

  test('selective fork rejects a mask that differs from its output count', () {
    final functor = SelectiveForkCoreFunctor<Logic>(outputCount: 4);
    expect(
      () => functor.construct(
        SelectiveForkCoreRequest(
          clk: Logic(),
          reset: Logic(),
          payload: Logic(width: 8),
          selection: Logic(width: 3),
          load: Logic(),
          advance: Logic(width: 4),
        ),
        name: 'fork',
      ),
      throwsArgumentError,
    );
  });
}
