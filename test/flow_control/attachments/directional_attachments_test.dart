// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// directional_attachments_test.dart
// Tests protocol-neutral directional attachment contracts.
//
// 2026 October 15
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  test('synchronous action attachment requires one-bit actions', () {
    const policy = SynchronousActionAttachmentPolicy();

    expect(policy.capabilities.storageDepth, 0);
    expect(policy.capabilities.addedLatency, 0);
    expect(policy.capabilities.requiresRetention, isFalse);
    expect(policy.capabilities.supportsSameCycleReplacement, isTrue);
    expect(policy.capabilities.hasBackwardCombinationalDependency, isFalse);
    expect(
      () => policy.validateAction(Logic(width: 2), name: 'enqueue'),
      throwsArgumentError,
    );
    expect(
      () => policy.validateAction(Logic(), name: 'enqueue'),
      returnsNormally,
    );
  });

  test('ready-valid attachment capabilities distinguish both directions', () {
    final ingress = ReadyValidIngressAttachmentPolicy<Logic>(
      supportsSameCycleReplacement: false,
      storageDepth: 4,
    );
    final egress = ReadyValidEgressAttachmentPolicy<Logic>();

    expect(ingress.capabilities.storageDepth, 4);
    expect(ingress.capabilities.requiresRetention, isFalse);
    expect(ingress.capabilities.supportsSameCycleReplacement, isFalse);
    expect(ingress.capabilities.hasBackwardCombinationalDependency, isTrue);
    expect(egress.capabilities.storageDepth, 0);
    expect(egress.capabilities.requiresRetention, isTrue);
    expect(egress.capabilities.supportsSameCycleReplacement, isTrue);
    expect(egress.capabilities.hasBackwardCombinationalDependency, isTrue);
    expect(
      () => ReadyValidIngressAttachmentPolicy<Logic>(
        supportsSameCycleReplacement: true,
        storageDepth: -1,
      ),
      throwsArgumentError,
    );
  });
}
