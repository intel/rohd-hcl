// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// policy_arbiter_test.dart
// Tests orthogonal arbitration policy, advancement, and retention.
//
// 2026 October 6
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _PolicyArbiterHarness extends Module {
  Logic get grant => output('grant');

  _PolicyArbiterHarness({
    required Logic clk,
    required Logic reset,
    required Logic requests,
    required Logic advance,
  }) : super(definitionName: 'PolicyArbiterHarness') {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    requests = addInput('requests', requests, width: requests.width);
    advance = addInput('advance', advance);
    final arbiter = PolicyArbiter(
      requests.elements,
      clk: clk,
      reset: reset,
      policy: roundRobinArbitrationPolicy,
      advanceMode: ArbitrationAdvanceMode.onAccepted,
      accepted: advance,
    );
    addOutput('grant', width: requests.width) <= arbiter.grants.rconcat();
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  final policies = <(String, ArbitrationPolicy)>[
    ('fixed', fixedPriorityArbitrationPolicy),
    ('maskRoundRobin', maskRoundRobinArbitrationPolicy),
    ('rotateRoundRobin', rotateRoundRobinArbitrationPolicy),
  ];

  // Elaborate and exercise every built-in policy, advancement, and retention
  // combination with an active request after reset.
  for (final (policyName, policy) in policies) {
    for (final advanceMode in ArbitrationAdvanceMode.values) {
      for (final retentionPolicy in ArbitrationRetentionPolicy.values) {
        test(
            '$policyName ${advanceMode.name} ${retentionPolicy.name} '
            'selects an active request', () async {
          final clk = SimpleClockGenerator(10).clk;
          final reset = Logic(name: 'reset');
          final accepted = Logic(name: 'accepted');
          final complete = Logic(name: 'complete');
          final capture = Logic(name: 'capture');
          final release = Logic(name: 'release');
          final requests = List.generate(
            3,
            (index) => Logic(name: 'request_$index'),
          );
          final usesCompletion =
              advanceMode == ArbitrationAdvanceMode.onCompletion;
          final usesLock =
              retentionPolicy == ArbitrationRetentionPolicy.lockUntilRelease;
          final arbiter = PolicyArbiter(
            requests,
            clk: clk,
            reset: reset,
            policy: policy,
            advanceMode: advanceMode,
            retentionPolicy: retentionPolicy,
            accepted: accepted,
            complete: usesCompletion ? complete : null,
            captureOwner: usesLock ? capture : null,
            releaseOwner: usesLock ? release : null,
          );
          await arbiter.build();
          unawaited(Simulator.run());

          reset.inject(1);
          accepted.inject(0);
          complete.inject(0);
          capture.inject(0);
          release.inject(0);
          for (final request in requests) {
            request.inject(0);
          }
          await clk.nextPosedge;
          reset.inject(0);
          await clk.nextNegedge;
          expect(arbiter.grants.rconcat().value, LogicValue.ofInt(0, 3));

          requests[0].inject(1);
          if (usesLock) {
            capture.inject(1);
          }
          await clk.nextNegedge;
          expect(arbiter.grants.rconcat().value, LogicValue.ofInt(1, 3));
          await clk.nextPosedge;
          await clk.nextNegedge;
          expect(arbiter.grants.rconcat().value, LogicValue.ofInt(1, 3));
          final shouldRetain = usesLock ||
              retentionPolicy == ArbitrationRetentionPolicy.holdUntilAccepted;
          expect(
            arbiter.locked.value,
            shouldRetain ? LogicValue.one : LogicValue.zero,
          );

          await Simulator.endSimulation();
        });
      }
    }
  }

  for (final policy in [
    maskRoundRobinArbitrationPolicy,
    rotateRoundRobinArbitrationPolicy,
  ]) {
    // Exercise the minimum legal requester count, including the rotate
    // policy's zero-rotation datapath.
    test('${policy.identity} supports one requestor', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic(name: 'reset');
      final request = Logic(name: 'request');
      final arbiter = PolicyArbiter(
        [request],
        clk: clk,
        reset: reset,
        policy: policy,
      );
      await arbiter.build();
      unawaited(Simulator.run());

      reset.inject(1);
      request.inject(0);
      await clk.nextPosedge;
      reset.inject(0);
      request.inject(1);
      await clk.nextNegedge;
      expect(arbiter.grants.single.value, LogicValue.one);

      await Simulator.endSimulation();
    });
  }

  // Stall acceptance, remove the selected request, then restore and accept it
  // to prove that hold retention separates owner identity from active grant.
  test('hold-until-accepted masks a withdrawn retained request', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic(name: 'reset');
    final advance = Logic(name: 'advance');
    final requests = List.generate(3, (index) => Logic(name: 'request_$index'));
    final arbiter = PolicyArbiter(
      requests,
      clk: clk,
      reset: reset,
      policy: maskRoundRobinArbitrationPolicy,
      advanceMode: ArbitrationAdvanceMode.onAccepted,
      retentionPolicy: ArbitrationRetentionPolicy.holdUntilAccepted,
      accepted: advance,
    );
    await arbiter.build();
    unawaited(Simulator.run());

    reset.inject(1);
    advance.inject(0);
    for (final request in requests) {
      request.inject(1);
    }
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextPosedge;
    await clk.nextNegedge;
    expect(arbiter.selection.value, LogicValue.ofInt(1, 3));
    expect(arbiter.locked.value, LogicValue.one);

    requests[0].inject(0);
    await clk.nextNegedge;
    expect(arbiter.selection.value, LogicValue.ofInt(1, 3));
    expect(arbiter.grants.rconcat().value, LogicValue.ofInt(0, 3));

    requests[0].inject(1);
    advance.inject(1);
    await clk.nextPosedge;
    await clk.nextNegedge;
    expect(arbiter.locked.value, LogicValue.zero);
    expect(arbiter.grants.rconcat().value, LogicValue.ofInt(2, 3));

    await Simulator.endSimulation();
  });

  // Capture request zero, release it while its request is absent, and verify
  // that round-robin state advances from the retained owner rather than the
  // currently visible candidate.
  test('explicit release advances from an absent retained owner', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic(name: 'reset');
    final accepted = Logic(name: 'accepted');
    final complete = Logic(name: 'complete');
    final capture = Logic(name: 'capture');
    final release = Logic(name: 'release');
    final requests = List.generate(3, (index) => Logic(name: 'request_$index'));
    final arbiter = PolicyArbiter(
      requests,
      clk: clk,
      reset: reset,
      policy: maskRoundRobinArbitrationPolicy,
      advanceMode: ArbitrationAdvanceMode.onCompletion,
      retentionPolicy: ArbitrationRetentionPolicy.lockUntilRelease,
      accepted: accepted,
      complete: complete,
      captureOwner: capture,
      releaseOwner: release,
    );
    await arbiter.build();
    unawaited(Simulator.run());

    reset.inject(1);
    accepted.inject(1);
    complete.inject(0);
    capture.inject(1);
    release.inject(0);
    for (final request in requests) {
      request.inject(1);
    }
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextPosedge;
    await clk.nextNegedge;
    expect(arbiter.selection.value, LogicValue.ofInt(1, 3));
    expect(arbiter.locked.value, LogicValue.one);

    capture.inject(0);
    accepted.inject(0);
    requests[0].inject(0);
    await clk.nextNegedge;
    expect(arbiter.selection.value, LogicValue.ofInt(1, 3));
    expect(arbiter.grants.rconcat().value, LogicValue.ofInt(0, 3));

    complete.inject(1);
    release.inject(1);
    await clk.nextPosedge;
    complete.inject(0);
    release.inject(0);
    await clk.nextNegedge;
    expect(arbiter.locked.value, LogicValue.zero);
    expect(arbiter.selection.value, LogicValue.ofInt(2, 3));
    expect(arbiter.grants.rconcat().value, LogicValue.ofInt(2, 3));

    requests[0].inject(1);
    await clk.nextNegedge;
    expect(arbiter.grants.rconcat().value, LogicValue.ofInt(2, 3));

    await Simulator.endSimulation();
  });

  // Keep three contenders active to cover a non-power-of-two request count and
  // verify that grant-driven round robin visits each exactly once per cycle.
  test('grant-driven round robin covers three requestors fairly', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic(name: 'reset');
    final requests = List.generate(3, (index) => Logic(name: 'request_$index'));
    final arbiter = PolicyArbiter(
      requests,
      clk: clk,
      reset: reset,
      policy: rotateRoundRobinArbitrationPolicy,
    );
    await arbiter.build();
    unawaited(Simulator.run());

    reset.inject(1);
    for (final request in requests) {
      request.inject(1);
    }
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextNegedge;
    expect(arbiter.grants.rconcat().value, LogicValue.ofInt(1, 3));
    for (final expected in [2, 4, 1]) {
      await clk.nextPosedge;
      await clk.nextNegedge;
      expect(arbiter.grants.rconcat().value, LogicValue.ofInt(expected, 3));
    }

    await Simulator.endSimulation();
  });

  // Reset an actively retained owner and verify that ownership state clears
  // even while requests remain asserted.
  test('reset clears retained ownership', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic(name: 'reset');
    final advance = Logic(name: 'advance');
    final requests = List.generate(2, (index) => Logic(name: 'request_$index'));
    final arbiter = PolicyArbiter(
      requests,
      clk: clk,
      reset: reset,
      policy: roundRobinArbitrationPolicy,
      advanceMode: ArbitrationAdvanceMode.onAccepted,
      retentionPolicy: ArbitrationRetentionPolicy.holdUntilAccepted,
      accepted: advance,
    );
    await arbiter.build();
    unawaited(Simulator.run());

    reset.inject(1);
    advance.inject(0);
    for (final request in requests) {
      request.inject(1);
    }
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextPosedge;
    await clk.nextNegedge;
    expect(arbiter.locked.value, LogicValue.one);

    reset.inject(1);
    await clk.nextPosedge;
    await clk.nextNegedge;
    expect(arbiter.locked.value, LogicValue.zero);

    await Simulator.endSimulation();
  });

  // Build the arbiter under a parent and generate SystemVerilog to exercise all
  // parent-to-child and child-to-parent hierarchy boundaries.
  test('builds and synthesizes under a parent harness', () async {
    final harness = _PolicyArbiterHarness(
      clk: Logic(name: 'clk'),
      reset: Logic(name: 'reset'),
      requests: Logic(name: 'requests', width: 3),
      advance: Logic(name: 'advance'),
    );
    await harness.build();
    final systemVerilog = harness.dumpSystemVerilog();
    expect(systemVerilog, contains('module PolicyArbiterHarness'));
    expect(systemVerilog, contains('module PolicyArbiter_W3'));
  });
}
