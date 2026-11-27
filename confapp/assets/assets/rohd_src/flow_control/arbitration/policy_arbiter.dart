// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// policy_arbiter.dart
// Orthogonal arbitration policy, advancement, and ownership retention.
//
// 2026 October 6
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/flow_control/arbitration/arbitration_policy.dart';
import 'package:rohd_hcl/src/flow_control/arbitration/grant_retainer.dart';
import 'package:rohd_hcl/src/flow_control/arbitration/stateful_arbiter.dart';

/// Determines what event advances arbitration policy state.
enum ArbitrationAdvanceMode {
  /// Every cycle with an active grant completes one unit of service.
  onGrant,

  /// An accepted active grant completes one unit of service.
  onAccepted,

  /// The external `complete` event completes the selected owner's service.
  ///
  /// Unlike [onAccepted], this mode may complete a retained owner while its
  /// request is inactive.
  onCompletion,
}

/// Determines how ownership is retained independently of selection policy.
enum ArbitrationRetentionPolicy {
  /// Re-evaluate the selection policy continuously.
  none,

  /// Retain a selected owner across cycles until one grant is accepted.
  holdUntilAccepted,

  /// Retain an owner from an explicit capture until an explicit release.
  lockUntilRelease,
}

/// Composes selection, advancement, and retention into an arbiter.
///
/// [candidate] is produced by [policy]. [selection] may retain that owner,
/// while inherited [grants] are always masked by live requests. Stateful
/// policies advance from the explicit one-hot [completedGrant], so releasing a
/// retained owner cannot accidentally advance from a different live candidate.
/// {@category Flow Control}
class PolicyArbiter extends StatefulArbiter {
  /// Selection algorithm used to propose a candidate.
  final ArbitrationPolicy policy;

  /// Event used to advance [policy].
  final ArbitrationAdvanceMode advanceMode;

  /// Ownership-retention behavior.
  final ArbitrationRetentionPolicy retentionPolicy;

  /// Number of runtime policy inputs.
  final int policyInputCount;

  /// One-hot candidate proposed by [policy].
  Logic get candidate => output('candidate');

  /// One-hot selected owner, retained according to [retentionPolicy].
  Logic get selection => output('selection');

  /// Registered owner captured by the active retention policy.
  ///
  /// This is zero for [ArbitrationRetentionPolicy.none] and is meaningful only
  /// while [locked] is high.
  Logic get retainedOwner => output('retainedOwner');

  /// One-hot accepted active grant for the current cycle.
  Logic get acceptedGrant => output('acceptedGrant');

  /// One-hot owner completion used to advance [policy].
  Logic get completedGrant => output('completedGrant');

  /// High while [selection] is retained.
  Logic get locked => output('locked');

  /// Creates a composed policy arbiter.
  PolicyArbiter(
    super.requests, {
    required super.clk,
    required super.reset,
    required this.policy,
    this.advanceMode = ArbitrationAdvanceMode.onGrant,
    this.retentionPolicy = ArbitrationRetentionPolicy.none,
    Logic? accepted,
    Logic? complete,
    Logic? captureOwner,
    Logic? releaseOwner,
    List<Logic> policyInputs = const [],
    super.name = 'policy_arbiter',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  })  : policyInputCount = policyInputs.length,
        super(
          definitionName: definitionName ??
              'PolicyArbiter_W${requests.length}_P${policy.identity}_'
                  'A${advanceMode.name}_R${retentionPolicy.name}_'
                  'Q${accepted == null ? 0 : 1}_'
                  'I${policyInputs.map((input) => input.width).join('_')}',
        ) {
    if (requests.isEmpty) {
      throw ArgumentError.value(requests, 'requests', 'Must not be empty.');
    }
    for (final control in {
      'accepted': accepted,
      'complete': complete,
      'captureOwner': captureOwner,
      'releaseOwner': releaseOwner,
    }.entries) {
      if (control.value != null && control.value!.width != 1) {
        throw ArgumentError.value(
          control.value,
          control.key,
          'Arbitration controls must be one bit.',
        );
      }
    }
    if ((advanceMode == ArbitrationAdvanceMode.onAccepted ||
            retentionPolicy == ArbitrationRetentionPolicy.holdUntilAccepted) &&
        accepted == null) {
      throw ArgumentError(
        'Accepted advancement and hold retention require an accepted '
        'qualifier.',
      );
    }
    if (advanceMode == ArbitrationAdvanceMode.onCompletion &&
        complete == null) {
      throw ArgumentError(
        'onCompletion advancement requires a complete event.',
      );
    }
    if (advanceMode != ArbitrationAdvanceMode.onCompletion &&
        complete != null) {
      throw ArgumentError(
        'A complete event is valid only with onCompletion advancement.',
      );
    }
    if (retentionPolicy == ArbitrationRetentionPolicy.lockUntilRelease &&
        (captureOwner == null || releaseOwner == null)) {
      throw ArgumentError(
        'lockUntilRelease retention requires capture and release controls.',
      );
    }
    if (retentionPolicy != ArbitrationRetentionPolicy.lockUntilRelease &&
        (captureOwner != null || releaseOwner != null)) {
      throw ArgumentError(
        'Capture and release controls are valid only with lockUntilRelease '
        'retention.',
      );
    }

    final acceptedQualifier =
        accepted == null ? Const(1) : addInput('accepted', accepted);
    final completionEvent = advanceMode == ArbitrationAdvanceMode.onCompletion
        ? addInput('complete', complete!)
        : Const(0);
    final captureRequest =
        retentionPolicy == ArbitrationRetentionPolicy.lockUntilRelease
            ? addInput('captureOwner', captureOwner!)
            : Const(0);
    final releaseRequest =
        retentionPolicy == ArbitrationRetentionPolicy.lockUntilRelease
            ? addInput('releaseOwner', releaseOwner!)
            : Const(0);
    final localPolicyInputs = [
      for (var index = 0; index < policyInputs.length; index++)
        addInput(
          'policyInput_$index',
          policyInputs[index],
          width: policyInputs[index].width,
        ),
    ];

    addOutput('candidate', width: count);
    addOutput('selection', width: count);
    addOutput('retainedOwner', width: count);
    addOutput('acceptedGrant', width: count);
    addOutput('completedGrant', width: count);
    addOutput('locked');

    final completedGrantFeedback =
        Logic(name: '${name}_completed_grant_feedback', width: count);
    final candidateSelection = policy.build(
      requests: requests,
      completedGrant: completedGrantFeedback,
      policyInputs: localPolicyInputs,
      clk: clk,
      reset: reset,
      name: '${name}_${policy.identity}',
    );
    candidate <= candidateSelection;

    late final Logic captureControl;
    late final Logic releaseControl;
    late final Logic ownerSelection;
    late final Logic registeredOwner;
    late final Logic activeGrant;
    late final Logic retentionLocked;
    if (retentionPolicy == ArbitrationRetentionPolicy.none) {
      captureControl = Const(0);
      releaseControl = Const(0);
      ownerSelection = candidateSelection;
      registeredOwner = Const(0, width: count);
      activeGrant = candidateSelection & requests.rconcat();
      retentionLocked = Const(0);
    } else {
      captureControl = Logic(name: '${name}_capture_control');
      releaseControl = Logic(name: '${name}_release_control');
      final retainer = GrantRetainer(
        clk: clk,
        reset: reset,
        candidate: candidateSelection,
        requests: requests.rconcat(),
        capture: captureControl,
        release: releaseControl,
        name: '${name}_retainer',
      );
      ownerSelection = retainer.selection;
      registeredOwner = retainer.retainedOwner;
      activeGrant = retainer.grant;
      retentionLocked = retainer.locked;
    }
    selection <= ownerSelection;
    retainedOwner <= registeredOwner;
    locked <= retentionLocked;
    for (var index = 0; index < count; index++) {
      grants[index] <= activeGrant[index];
    }

    final acceptedBits = [
      for (var index = 0; index < count; index++)
        (activeGrant[index] & acceptedQualifier)
            .named('${name}_accepted_$index'),
    ].rconcat();
    acceptedGrant <= acceptedBits;

    switch (retentionPolicy) {
      case ArbitrationRetentionPolicy.none:
        break;
      case ArbitrationRetentionPolicy.holdUntilAccepted:
        captureControl <=
            ~retentionLocked & activeGrant.or() & ~acceptedQualifier;
        releaseControl <=
            retentionLocked & activeGrant.or() & acceptedQualifier;
      case ArbitrationRetentionPolicy.lockUntilRelease:
        captureControl <= captureRequest;
        releaseControl <= retentionLocked & releaseRequest;
    }
    switch (advanceMode) {
      case ArbitrationAdvanceMode.onGrant:
        completedGrantFeedback <= activeGrant;
      case ArbitrationAdvanceMode.onAccepted:
        completedGrantFeedback <= acceptedBits;
      case ArbitrationAdvanceMode.onCompletion:
        completedGrantFeedback <=
            ownerSelection & completionEvent.replicate(count);
    }
    completedGrant <= completedGrantFeedback;
  }
}
