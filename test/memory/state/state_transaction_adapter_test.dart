// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// state_transaction_adapter_test.dart
// Tests shared software snapshot and restore transactions.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  test('adapter validates current capabilities before invoking callbacks', () {
    var value = 'first';
    var snapshots = 0;
    var restores = 0;
    var capabilities = StateTransactionCapabilities.software;
    final endpoint = SoftwareStateTransactionAdapter<String>(
      snapshot: () {
        snapshots++;
        return value;
      },
      restore: (image) {
        restores++;
        value = image;
      },
      capabilities: () => capabilities,
    );
    final snapshot = StateTransactionRequest<String>.snapshot(transactionId: 7);
    final image = endpoint.transact(snapshot);
    expect(image.transactionId, 7);
    expect(image.image, 'first');
    value = 'second';
    final restored = endpoint.transact(StateTransactionRequest<String>.restore(
        transactionId: 8, image: image.image!));
    expect(restored.transactionId, 8);
    expect(value, 'first');
    capabilities = StateTransactionCapabilities.unsupported;
    expect(() => endpoint.transact(snapshot), throwsUnsupportedError);
    expect(snapshots, 1);
    expect(restores, 1);
    capabilities = StateTransactionCapabilities(
      transport: StateTransactionTransport.software,
      supportsSnapshot: true,
      supportsRestore: true,
      snapshotQuiescence: StateTransactionQuiescence.required,
      restoreQuiescence: StateTransactionQuiescence.required,
      completionMode: StateTransactionCompletionMode.immediate,
      atomicRestore: true,
    );
    expect(() => endpoint.transact(snapshot), throwsStateError);
    expect(snapshots, 1);
    expect(endpoint.transact(snapshot, quiescent: true).image, 'first');
    expect(snapshots, 2);
  });

  test('widened adapters reject incompatible images before callbacks', () {
    var restored = false;
    final SoftwareStateTransactionAdapter<Object> endpoint =
        SoftwareStateTransactionAdapter<String>(
      snapshot: () => 'value',
      restore: (_) => restored = true,
    );
    expect(() => endpoint.load(42), throwsA(isA<TypeError>()));
    expect(restored, isFalse);
  });
}
