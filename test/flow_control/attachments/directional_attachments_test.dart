// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// directional_attachments_test.dart
// Tests protocol-neutral directional attachment contracts.
//
// 2026 October 15
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _ConstantEgress extends Module {
  _ConstantEgress() {
    final downstream = ReadyValidInterface<Logic>(
        FixedPoint(integerWidth: 3, fractionWidth: 4));
    downstream.ready <= addInput('ready', Logic());
    final payload = FixedPoint.constant(FixedPointValue.withSignedness(
        integer: LogicValue.ofInt(3, 4), fraction: LogicValue.ofInt(1, 4)));
    final transfer = Logic();
    ReadyValidEgressAttachmentPolicy<Logic>().attach(
        downstream: downstream,
        offerValid: addInput('valid', Logic()),
        payload: payload,
        transfer: transfer);
    addOutput('data', width: 8) <= downstream.data;
    addOutput('transfer') <= transfer;
  }
}

void main() {
  tearDown(Simulator.reset);

  test('ready-valid egress accepts a compatible structured constant', () async {
    final dut = _ConstantEgress();
    await dut.build();
    final vectors = [
      Vector({'ready': 0, 'valid': 1}, {'data': 0x31, 'transfer': 0}),
      Vector({'ready': 1}, {'data': 0x31, 'transfer': 1}),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
    expect(
        () => ReadyValidEgressAttachmentPolicy<Logic>().attach(
              downstream: ReadyValidInterface<Logic>(
                  FixedPoint(integerWidth: 3, fractionWidth: 4)),
              offerValid: Logic(),
              payload:
                  FixedPoint(integerWidth: 4, fractionWidth: 4, signed: false),
              transfer: Logic(),
            ),
        throwsA(isA<PortTypeException>()));
  });

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
