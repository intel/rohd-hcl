// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// behavioral_replacement_test.dart
// State and wide-mask tests for software replacement policies.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(Simulator.reset);

  test('replacement state snapshots restore compatible policy state', () async {
    final clk = Logic()..put(0);
    final reset = Logic()..put(1);
    final valid = Logic(width: 4)..put(15);
    final eligible = Logic(width: 4)..put(15);
    final allocation = ReplacementAllocationInterface(4)
      ..en.put(1)
      ..commit.put(1);
    final policy = BehavioralReplacementPolicy(
      clk: clk,
      reset: reset,
      validMask: valid,
      eligibleMask: eligible,
      accesses: [],
      allocations: [allocation],
      entryCount: 4,
      kind: BehavioralReplacementKind.roundRobin,
    );
    final incompatible = BehavioralReplacementPolicy(
      clk: Logic(),
      reset: Logic(),
      validMask: Logic(width: 4),
      eligibleMask: Logic(width: 4),
      accesses: [],
      allocations: [ReplacementAllocationInterface(4)],
      entryCount: 4,
      kind: BehavioralReplacementKind.treePseudoLru,
    );
    await policy.build();
    expect(policy.description.inputPorts.keys,
        unorderedEquals(policy.inputs.keys));
    expect(policy.description.outputPorts.keys,
        unorderedEquals(policy.outputs.keys));
    expect(generateBehavioralSystemC(policy, 'Replacement'),
        contains('SC_MODULE(Replacement)'));
    Simulator.registerAction(1, () => clk.put(1));
    Simulator.registerAction(2, () {
      clk.put(0);
      reset.put(0);
      final saved = policy.stateTransactions
          .transact(
              StateTransactionRequest<BehavioralReplacementImage>.snapshot(
                  transactionId: 7))
          .image!;
      expect(() => incompatible.restore(saved), throwsArgumentError);
      Simulator.registerAction(3, () => clk.put(1));
      Simulator.registerAction(4, () {
        expect(allocation.index.value.toInt(), 1);
        policy.stateTransactions.transact(
            StateTransactionRequest<BehavioralReplacementImage>.restore(
                transactionId: 8, image: saved));
        expect(allocation.index.value.toInt(), 0);
      });
    });
    await Simulator.run();
  });

  test('round robin handles eligibility above native integer width', () async {
    const count = 70;
    final allocation = ReplacementAllocationInterface(count)
      ..en.put(1)
      ..commit.put(0);
    final policy = BehavioralReplacementPolicy(
      clk: Logic()..put(0),
      reset: Logic()..put(0),
      validMask: Logic(width: count)..put(0),
      eligibleMask: Logic(width: count)
        ..put(LogicValue.ofBigInt(BigInt.one << 68, count)),
      accesses: [],
      allocations: [allocation],
      entryCount: count,
      kind: BehavioralReplacementKind.roundRobin,
    );
    await policy.build();
    Simulator.registerAction(1, () {
      expect(allocation.valid.value, LogicValue.one);
      expect(allocation.index.value.toInt(), 68);
      expect(allocation.evict.value, LogicValue.zero);
    });
    await Simulator.run();
  });

  test('snapshot retains unknown replacement state across reset', () async {
    final clk = Logic()..put(0);
    final reset = Logic()..put(0);
    final allocation = ReplacementAllocationInterface(3)
      ..en.put(1)
      ..commit.put(0);
    final policy = BehavioralReplacementPolicy(
      clk: clk,
      reset: reset,
      validMask: Logic(width: 3)..put(7),
      eligibleMask: Logic(width: 3)..put(7),
      accesses: [],
      allocations: [allocation],
      entryCount: 3,
      kind: BehavioralReplacementKind.roundRobin,
    );
    await policy.build();
    late BehavioralReplacementImage image;
    late LogicValue before;
    Simulator.registerAction(1, () {
      before = allocation.index.value;
      expect(before.isValid, isFalse);
      image = policy.snapshot();
      reset.put(1);
    });
    Simulator.registerAction(2, () => clk.put(1));
    Simulator.registerAction(3, () {
      expect(allocation.index.value.isValid, isTrue);
      clk.put(0);
      reset.put(0);
      policy.restore(image);
      expect(allocation.index.value, before);
    });
    await Simulator.run();
  });
}
