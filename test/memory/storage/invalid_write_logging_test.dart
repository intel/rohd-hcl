// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// invalid_write_logging_test.dart
// Default and custom uncertain-write reporting.
//
// 2026 November
// Author: ROHD-HCL contributors

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart' as vf;
import 'package:test/test.dart';

class _VerificationTest extends vf.Test {
  _VerificationTest()
      : super('memory_verification',
            printLevel: Level.OFF, failLevel: Level.WARNING);
}

void main() {
  tearDown(vf.Test.reset);

  test('default warning prints without an active verification test', () {
    expect(vf.Test.instance, isNull);
    final messages = <String>[];
    final storage = SparseMemoryStorage(addrWidth: 2, dataWidth: 8);
    runZoned(
      () => storage.writeUncertainAddress(
          LogicValue.ofString('0x'), LogicValue.ofInt(0xff, 8)),
      zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => messages.add(line)),
    );
    expect(messages, ['WARNING: Memory received an uncertain write!']);
  });

  test('default warning uses the active verification test logger', () async {
    final verification = _VerificationTest();
    final records = <LogRecord>[];
    final subscription = Logger.root.onRecord.listen(records.add);
    try {
      SparseMemoryStorage(addrWidth: 2, dataWidth: 8).writeUncertainAddress(
          LogicValue.ofString('0x'), LogicValue.ofInt(0xff, 8));
      final warnings = records.where(
          (record) => record.message == 'Memory received an uncertain write!');
      expect(warnings, hasLength(1));
      expect(warnings.single.level, Level.WARNING);
      expect(warnings.single.loggerName, 'memory_verification');
      expect(verification.failureDetected, isTrue);
    } finally {
      verification
        ..failureDetected = false
        ..failLevel = Level.SEVERE;
      await verification.start();
      await subscription.cancel();
    }
    expect(vf.Test.instance, isNull);
  });

  test('custom invalid-write callback replaces the default warning', () {
    var calls = 0;
    final messages = <String>[];
    final storage = SparseMemoryStorage(
      addrWidth: 2,
      dataWidth: 8,
      onInvalidWrite: () => calls++,
    );
    runZoned(
      () => storage.writeUncertainAddress(
          LogicValue.ofString('0x'), LogicValue.ofInt(0xff, 8)),
      zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => messages.add(line)),
    );
    expect(calls, 1);
    expect(messages, isEmpty);
  });

  test('custom invalid-write callback can throw without rolling back state',
      () {
    final storage = SparseMemoryStorage(
      addrWidth: 2,
      dataWidth: 8,
      onInvalidWrite: () => throw StateError('uncertain write'),
      onInvalidRead: (_, width) => LogicValue.ofInt(0, width),
    );
    expect(
        () => storage.writeUncertainAddress(
            LogicValue.ofString('0x'), LogicValue.ofInt(0xff, 8)),
        throwsStateError);
    expect(storage.readData(LogicValue.ofInt(0, 2)),
        LogicValue.filled(8, LogicValue.x));
  });
}
