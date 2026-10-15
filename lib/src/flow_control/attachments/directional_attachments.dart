// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// directional_attachments.dart
// Typed protocol attachments for action-driven cores.
//
// 2026 October 15
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/transport/ready_valid_interface.dart';

/// Construction-time behavior of one directional protocol attachment.
@immutable
class DirectionalAttachmentCapabilities {
  /// Explicit storage owned outside this attachment.
  final int storageDepth;

  /// Cycles of latency inherently added by the attachment itself.
  final int addedLatency;

  /// Whether payload must be retained until egress occurs.
  final bool requiresRetention;

  /// Whether final dequeue and replacement may share an edge.
  final bool supportsSameCycleReplacement;

  /// Whether credit return may participate in same-cycle eligibility.
  final bool supportsSameCycleCreditReuse;

  /// Whether static credit metadata is required.
  final bool requiresCreditContract;

  /// Whether the attachment creates a combinational backward dependency.
  final bool hasBackwardCombinationalDependency;

  /// Creates immutable attachment metadata.
  const DirectionalAttachmentCapabilities({
    required this.storageDepth,
    required this.addedLatency,
    required this.requiresRetention,
    required this.supportsSameCycleReplacement,
    required this.supportsSameCycleCreditReuse,
    required this.requiresCreditContract,
    required this.hasBackwardCombinationalDependency,
  })  : assert(storageDepth >= 0, 'Storage depth must not be negative.'),
        assert(addedLatency >= 0, 'Added latency must not be negative.');
}

/// Validates direct caller-owned synchronous action controls.
@immutable
class SynchronousActionAttachmentPolicy {
  /// Static action behavior.
  final DirectionalAttachmentCapabilities capabilities;

  /// Creates a synchronous action policy.
  const SynchronousActionAttachmentPolicy({
    this.capabilities = const DirectionalAttachmentCapabilities(
      storageDepth: 0,
      addedLatency: 0,
      requiresRetention: false,
      supportsSameCycleReplacement: true,
      supportsSameCycleCreditReuse: false,
      requiresCreditContract: false,
      hasBackwardCombinationalDependency: false,
    ),
  });

  /// Requires a one-bit action.
  void validateAction(Logic action, {required String name}) {
    if (action.width != 1) {
      throw ArgumentError.value(action, name, 'Action must be one bit.');
    }
  }
}

/// Returned ReadyValid-ingress action mapping.
@immutable
class ReadyValidIngressAttachmentBinding<LogicType extends Logic> {
  /// Accepted input action.
  final Logic accept;

  /// Wrapper-owned payload signal.
  final LogicType payload;

  /// Creates a typed ReadyValid ingress binding.
  const ReadyValidIngressAttachmentBinding({
    required this.accept,
    required this.payload,
  });
}

/// Maps ReadyValid ingress onto an explicit core admission action.
@immutable
class ReadyValidIngressAttachmentPolicy<LogicType extends Logic> {
  /// Static ingress behavior.
  final DirectionalAttachmentCapabilities capabilities;

  /// Creates a ReadyValid ingress policy.
  ReadyValidIngressAttachmentPolicy({
    required bool supportsSameCycleReplacement,
    int storageDepth = 0,
  }) : capabilities = DirectionalAttachmentCapabilities(
          storageDepth: _validatedStorageDepth(storageDepth),
          addedLatency: 0,
          requiresRetention: false,
          supportsSameCycleReplacement: supportsSameCycleReplacement,
          supportsSameCycleCreditReuse: false,
          requiresCreditContract: false,
          hasBackwardCombinationalDependency: true,
        );

  static int _validatedStorageDepth(int storageDepth) {
    if (storageDepth < 0) {
      throw ArgumentError.value(
        storageDepth,
        'storageDepth',
        'Must not be negative.',
      );
    }
    return storageDepth;
  }

  /// Connects [upstream] to wrapper-owned [accept] and [payload].
  ReadyValidIngressAttachmentBinding<LogicType> attach({
    required ReadyValidInterface<LogicType> upstream,
    required Logic canAccept,
    required Logic accept,
    required LogicType payload,
  }) {
    accept <= upstream.valid & canAccept;
    payload <= upstream.data;
    upstream.ready <= canAccept;
    return ReadyValidIngressAttachmentBinding(accept: accept, payload: payload);
  }
}

/// Returned ReadyValid-egress transfer mapping.
@immutable
class ReadyValidEgressAttachmentBinding {
  /// Accepted output action.
  final Logic transfer;

  /// Creates a ReadyValid egress binding.
  const ReadyValidEgressAttachmentBinding({required this.transfer});
}

/// Maps retained core output onto ReadyValid egress.
@immutable
class ReadyValidEgressAttachmentPolicy<LogicType extends Logic> {
  /// Static egress behavior.
  final DirectionalAttachmentCapabilities capabilities;

  /// Creates a ReadyValid egress policy.
  ReadyValidEgressAttachmentPolicy({bool requiresRetention = true})
      : capabilities = DirectionalAttachmentCapabilities(
          storageDepth: 0,
          addedLatency: 0,
          requiresRetention: requiresRetention,
          supportsSameCycleReplacement: true,
          supportsSameCycleCreditReuse: false,
          requiresCreditContract: false,
          hasBackwardCombinationalDependency: true,
        );

  /// Connects an output offer to [downstream].
  ReadyValidEgressAttachmentBinding attach({
    required ReadyValidInterface<LogicType> downstream,
    required Logic offerValid,
    required LogicType payload,
    required Logic transfer,
  }) {
    transfer <= offerValid & downstream.ready;
    downstream.valid <= offerValid;
    downstream.data <= payload;
    return ReadyValidEgressAttachmentBinding(transfer: transfer);
  }
}
