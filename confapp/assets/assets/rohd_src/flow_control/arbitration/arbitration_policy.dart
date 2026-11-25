// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// arbitration_policy.dart
// Composable arbitration selection policies.
//
// 2026 October 6
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/bit_operations/shifting/rotate.dart';
import 'package:rohd_hcl/src/flow_control/arbitration/priority_arbiter.dart';

/// Builds a one-hot candidate selection for an arbitration point.
///
/// [completedGrant] is a one-hot event identifying the owner whose service
/// completed. Stateful policies must update only from that event. Runtime
/// policy inputs, such as age or occupancy scores, are provided through
/// [policyInputs] so the containing module can register them as ports.
typedef ArbitrationPolicyBuilder = Logic Function({
  required List<Logic> requests,
  required Logic completedGrant,
  required List<Logic> policyInputs,
  required Logic clk,
  required Logic reset,
  required String name,
});

/// A reusable arbitration selection policy.
///
/// A policy chooses a candidate but does not decide when ownership is retained
/// or when a transfer is accepted. Those mechanisms are composed by
/// `PolicyArbiter`.
class ArbitrationPolicy {
  /// Stable identifier used in generated module definition names.
  final String identity;

  final ArbitrationPolicyBuilder _builder;

  /// Creates an arbitration selection policy.
  const ArbitrationPolicy({
    required this.identity,
    required ArbitrationPolicyBuilder build,
  }) : _builder = build;

  /// Builds and validates the candidate selection hardware.
  Logic build({
    required List<Logic> requests,
    required Logic completedGrant,
    required List<Logic> policyInputs,
    required Logic clk,
    required Logic reset,
    required String name,
  }) {
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(identity)) {
      throw ArgumentError.value(
        identity,
        'identity',
        'Must be a valid SystemVerilog identifier fragment.',
      );
    }
    if (requests.isEmpty) {
      throw ArgumentError.value(requests, 'requests', 'Must not be empty.');
    }
    if (requests.any((request) => request.width != 1)) {
      throw ArgumentError.value(
        requests,
        'requests',
        'Every arbitration request must be one bit.',
      );
    }
    if (completedGrant.width != requests.length) {
      throw ArgumentError.value(
        completedGrant,
        'completedGrant',
        'Must provide one completion bit per request.',
      );
    }
    final candidate = _builder(
      requests: requests,
      completedGrant: completedGrant,
      policyInputs: policyInputs,
      clk: clk,
      reset: reset,
      name: name,
    );
    if (candidate.width != requests.length) {
      throw ArgumentError.value(
        candidate,
        'candidate',
        'The policy must produce one candidate bit per request.',
      );
    }
    return candidate;
  }
}

Logic _fixedPriorityPolicy({
  required List<Logic> requests,
  required Logic completedGrant,
  required List<Logic> policyInputs,
  required Logic clk,
  required Logic reset,
  required String name,
}) {
  if (policyInputs.isNotEmpty) {
    throw ArgumentError.value(
      policyInputs,
      'policyInputs',
      'Fixed priority does not accept runtime policy inputs.',
    );
  }
  return PriorityArbiter(requests, name: '${name}_priority').grants.rconcat();
}

Logic _maskRoundRobinPolicy({
  required List<Logic> requests,
  required Logic completedGrant,
  required List<Logic> policyInputs,
  required Logic clk,
  required Logic reset,
  required String name,
}) {
  if (policyInputs.isNotEmpty) {
    throw ArgumentError.value(
      policyInputs,
      'policyInputs',
      'Mask round robin does not accept runtime policy inputs.',
    );
  }
  final count = requests.length;
  final requestMask = List.generate(
    count,
    (index) => Logic(name: '${name}_request_mask_$index'),
  );
  final maskedRequests = List.generate(
    count,
    (index) => Logic(name: '${name}_masked_request_$index'),
  );
  final candidates = List.generate(
    count,
    (index) => Logic(name: '${name}_candidate_$index'),
  );

  Combinational([
    for (var index = 0; index < count; index++)
      maskedRequests[index] < requestMask[index] & requests[index],
    CaseZ(
      maskedRequests.rconcat(),
      conditionalType: ConditionalType.priority,
      [
        for (var index = 0; index < count; index++)
          CaseItem(
            Const(
              LogicValue.filled(count, LogicValue.z)
                  .withSet(index, LogicValue.one),
            ),
            [
              for (var candidate = 0; candidate < count; candidate++)
                candidates[candidate] < (candidate == index ? 1 : 0),
            ],
          ),
      ],
      defaultItem: [
        CaseZ(
          requests.rconcat(),
          conditionalType: ConditionalType.priority,
          [
            for (var index = 0; index < count; index++)
              CaseItem(
                Const(
                  LogicValue.filled(count, LogicValue.z)
                      .withSet(index, LogicValue.one),
                ),
                [
                  for (var candidate = 0; candidate < count; candidate++)
                    candidates[candidate] < (candidate == index ? 1 : 0),
                ],
              ),
          ],
          defaultItem: [
            for (final candidate in candidates) candidate < 0,
          ],
        ),
      ],
    ),
  ]);

  Sequential(
    clk,
    reset: reset,
    resetValues: {
      for (final maskBit in requestMask) maskBit: 1,
    },
    [
      If(completedGrant.or(), then: [
        Case(
          completedGrant,
          conditionalType: ConditionalType.unique,
          [
            for (var completed = 0; completed < count; completed++)
              CaseItem(
                Const(1 << completed, width: count),
                [
                  for (var index = 0; index < count; index++)
                    requestMask[index] < (index > completed ? 1 : 0),
                ],
              ),
          ],
        ),
      ]),
    ],
  );
  return candidates.rconcat();
}

Logic _rotateRoundRobinPolicy({
  required List<Logic> requests,
  required Logic completedGrant,
  required List<Logic> policyInputs,
  required Logic clk,
  required Logic reset,
  required String name,
}) {
  if (policyInputs.isNotEmpty) {
    throw ArgumentError.value(
      policyInputs,
      'policyInputs',
      'Rotate round robin does not accept runtime policy inputs.',
    );
  }
  final count = requests.length;
  final preferenceWidth = max(1, count.log2Ceil);
  final preference = Logic(name: '${name}_preference', width: preferenceWidth);
  final rotatedRequests =
      requests.rconcat().rotateRight(preference, maxAmount: count - 1).elements;
  final rotatedGrant =
      PriorityArbiter(rotatedRequests, name: '${name}_priority')
          .grants
          .rconcat();
  final candidate = rotatedGrant.rotateLeft(preference, maxAmount: count - 1);

  Sequential(
    clk,
    reset: reset,
    resetValues: {preference: 0},
    [
      If(completedGrant.or(), then: [
        Case(
          completedGrant,
          conditionalType: ConditionalType.unique,
          [
            for (var completed = 0; completed < count; completed++)
              CaseItem(
                Const(1 << completed, width: count),
                [
                  preference <
                      Const((completed + 1) % count, width: preferenceWidth),
                ],
              ),
          ],
        ),
      ]),
    ],
  );
  return candidate;
}

Logic _highestScorePolicy({
  required List<Logic> requests,
  required Logic completedGrant,
  required List<Logic> policyInputs,
  required Logic clk,
  required Logic reset,
  required String name,
}) {
  if (policyInputs.length != requests.length || policyInputs.isEmpty) {
    throw ArgumentError.value(
      policyInputs,
      'policyInputs',
      'Highest-score arbitration requires one score per request.',
    );
  }
  if (policyInputs.map((input) => input.width).toSet().length != 1) {
    throw ArgumentError.value(
      policyInputs,
      'policyInputs',
      'Highest-score arbitration requires equally sized scores.',
    );
  }
  final candidates = <Logic>[];
  for (var index = 0; index < requests.length; index++) {
    var selected = requests[index];
    for (var other = 0; other < requests.length; other++) {
      if (other == index) {
        continue;
      }
      final wins = other < index
          ? policyInputs[other].lt(policyInputs[index])
          : ~policyInputs[index].lt(policyInputs[other]);
      selected = (selected & (~requests[other] | wins))
          .named('${name}_candidate_${index}_through_$other');
    }
    candidates.add(selected);
  }
  return candidates.rconcat();
}

int _maxInt(int left, int right) => max(left, right);

/// Selects the lowest-indexed active request.
const fixedPriorityArbitrationPolicy = ArbitrationPolicy(
  identity: 'fixedPriority',
  build: _fixedPriorityPolicy,
);

/// Selects requests fairly using a mask-based round-robin implementation.
const maskRoundRobinArbitrationPolicy = ArbitrationPolicy(
  identity: 'maskRoundRobin',
  build: _maskRoundRobinPolicy,
);

/// Selects requests fairly using rotation around a priority selector.
const rotateRoundRobinArbitrationPolicy = ArbitrationPolicy(
  identity: 'rotateRoundRobin',
  build: _rotateRoundRobinPolicy,
);

/// Default logical round-robin selection policy.
const roundRobinArbitrationPolicy = maskRoundRobinArbitrationPolicy;

/// Selects the valid request with the highest runtime score.
const highestScoreArbitrationPolicy = ArbitrationPolicy(
  identity: 'highestScore',
  build: _highestScorePolicy,
);

/// Creates a static weighted-priority policy.
///
/// Equal weights resolve toward the lowest request index. This is not weighted
/// round robin; weights establish a fixed ordering.
ArbitrationPolicy weightedPriorityArbitrationPolicy(List<int> weights) {
  if (weights.isEmpty || weights.any((weight) => weight < 1)) {
    throw ArgumentError.value(
      weights,
      'weights',
      'Must provide positive weights.',
    );
  }
  final capturedWeights = List<int>.unmodifiable(weights);
  return ArbitrationPolicy(
    identity: 'weightedPriority_${capturedWeights.join('_')}',
    build: (
        {required requests,
        required completedGrant,
        required policyInputs,
        required clk,
        required reset,
        required name}) {
      if (capturedWeights.length != requests.length ||
          policyInputs.isNotEmpty) {
        throw ArgumentError.value(
          capturedWeights,
          'weights',
          'Must provide one static weight per request and no policy inputs.',
        );
      }
      final maxWeight = capturedWeights.reduce(_maxInt);
      final width = max(1, (maxWeight + 1).log2Ceil);
      return _highestScorePolicy(
        requests: requests,
        completedGrant: completedGrant,
        policyInputs: [
          for (final weight in capturedWeights) Const(weight, width: width),
        ],
        clk: clk,
        reset: reset,
        name: name,
      );
    },
  );
}
