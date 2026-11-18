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

class _NamedPayload extends LogicStructure {
  final String suffix;

  _NamedPayload({required String name, this.suffix = 'payload'})
      : super([Logic(name: '${name}_$suffix', width: 8)], name: name);

  @override
  _NamedPayload clone({String? name}) =>
      _NamedPayload(name: name ?? this.name, suffix: suffix);
}

class _NamedAttachments extends Module {
  _NamedAttachments() {
    final upstream = ReadyValidInterface(_NamedPayload(name: 'incoming'));
    final downstream = ReadyValidInterface(_NamedPayload(name: 'outgoing'));
    final payload = _NamedPayload(name: 'internal');
    final accept = Logic();
    final transfer = Logic();
    upstream.data <= addInput('data', Logic(width: 8), width: 8);
    upstream.valid <= addInput('valid', Logic());
    downstream.ready <= addInput('ready', Logic());
    ReadyValidIngressAttachmentPolicy<_NamedPayload>(
            supportsSameCycleReplacement: true)
        .attach(
            upstream: upstream,
            canAccept: downstream.ready,
            accept: accept,
            payload: payload);
    ReadyValidEgressAttachmentPolicy<_NamedPayload>().attach(
        downstream: downstream,
        offerValid: upstream.valid,
        payload: payload,
        transfer: transfer);
    addOutput('out', width: 8) <= downstream.data;
    addOutput('accept') <= accept;
    addOutput('transfer') <= transfer;
  }
}

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

  test('ready-valid attachments accept parent-renamed payloads', () async {
    final dut = _NamedAttachments();
    await dut.build();
    final vectors = [
      Vector({'data': 37, 'valid': 1, 'ready': 0},
          {'out': 37, 'accept': 0, 'transfer': 0}),
      Vector({'ready': 1}, {'out': 37, 'accept': 1, 'transfer': 1}),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
    expect(
        () => ReadyValidIngressAttachmentPolicy<_NamedPayload>(
                supportsSameCycleReplacement: true)
            .attach(
                upstream: ReadyValidInterface(_NamedPayload(name: 'incoming')),
                canAccept: Logic(),
                accept: Logic(),
                payload: _NamedPayload(name: 'internal', suffix: 'different')),
        throwsA(isA<PortTypeException>()));
    expect(
        () => ReadyValidEgressAttachmentPolicy<_NamedPayload>().attach(
              downstream: ReadyValidInterface(_NamedPayload(name: 'outgoing')),
              offerValid: Logic(),
              payload: _NamedPayload(name: 'internal', suffix: 'different'),
              transfer: Logic(),
            ),
        throwsA(isA<PortTypeException>()));
  });

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
