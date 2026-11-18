// Copyright (C) 2025-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// resettable_entries_test.dart
// Tests for resettable entries
//
// 2025 September 3
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart' show FixedPoint, FixedPointValue;
import 'package:rohd_hcl/src/exceptions.dart';
import 'package:rohd_hcl/src/memory/memories.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

class _ResetHarness extends Module with ResettableEntries {
  late final List<Logic> values;

  _ResetHarness(dynamic resetValue,
      {int count = 3, int width = 8, bool duplicateInput = false}) {
    if (duplicateInput) {
      addInput('resetValue', resetValue as Logic, width: width);
    }
    values = makeResetValues(resetValue, numEntries: count, entryWidth: width);
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('scalar typed reset shares one typed runtime input', () {
    final reset = LogicArray([2], 4);
    final module = _ResetHarness(reset);
    expect(module.inputs.keys, ['resetValue']);
    expect(module.input('resetValue'), isA<LogicArray>());
    expect(module.values.every((value) => identical(value, module.values[0])),
        isTrue);
    reset.put(0x5a);
    expect(
        module.values.map((value) => value.value.toInt()), [0x5a, 0x5a, 0x5a]);
  });

  test('mixed list and map resets retain typed indexed inputs and defaults',
      () {
    final listReset = LogicArray([2], 4);
    final mapReset = LogicArray([2], 4);
    final list =
        _ResetHarness([LogicValue.ofString('10xz0011'), listReset, null]);
    final map = _ResetHarness({0: mapReset, 2: 7});

    expect(list.inputs.keys, ['resetValue_1']);
    expect(map.inputs.keys, ['resetValue_0']);
    expect(list.input('resetValue_1'), isA<LogicArray>());
    expect(map.input('resetValue_0'), isA<LogicArray>());
    listReset.put(0x12);
    mapReset.put(0x34);
    expect(list.values[0].value, LogicValue.ofString('10xz0011'));
    expect(list.values[1].value.toInt(), 0x12);
    expect(list.values[2].value.toInt(), 0);
    expect(map.values.map((value) => value.value.toInt()), [0x34, 0, 7]);
  });

  test('reset entries reject mismatched signal and list value widths', () {
    expect(
        () => _ResetHarness(Logic(width: 7)), throwsA(isA<RohdHclException>()));
    expect(() => _ResetHarness([null, LogicValue.ofInt(1, 7), null]),
        throwsA(isA<RohdHclException>()));
    expect(() => _ResetHarness({1: Logic(width: 7)}),
        throwsA(isA<RohdHclException>()));
  });

  test('reset entries reject a duplicate input even with the same source', () {
    expect(() => _ResetHarness(Logic(width: 8), duplicateInput: true),
        throwsA(isA<UnavailableReservedNameException>()));
  });

  group('resettable entries on rf', () {
    Future<List<LogicValue>> setupAndDumpRf(dynamic resetValue,
        {bool dumpWaves = false}) async {
      const numEntries = 4;
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();
      final rdPort = DataPortInterface(32, 8);
      final rf = RegisterFile<Logic>(clk, reset, [], [rdPort],
          resetValue: resetValue, numEntries: numEntries);

      await rf.build();

      if (dumpWaves) {
        rf.dumpWaves();
      }

      unawaited(Simulator.run());

      // reset flow
      reset.inject(0);
      await clk.waitCycles(2);
      reset.inject(1);
      rdPort.addr.inject(0);
      rdPort.en.inject(1);
      await clk.waitCycles(2);
      reset.inject(0);
      await clk.waitCycles(2);

      final readValues = <LogicValue>[];
      for (var i = 0; i < numEntries; i++) {
        rdPort.addr.inject(i);
        await clk.nextPosedge;
        readValues.add(rdPort.data.previousValue!);
      }

      await Simulator.endSimulation();

      return readValues;
    }

    test('no reset value provided uses 0', () async {
      final vals = await setupAndDumpRf(null);
      expect(vals.every((e) => e.isZero), isTrue);
    });

    test('constant is applied to all', () async {
      final vals = await setupAndDumpRf(0xdeadbeef);
      expect(vals.every((e) => e.toInt() == 0xdeadbeef), isTrue);
    });

    test('logic is applied to all', () async {
      final vals = await setupAndDumpRf(Const(0xfeedbeef, width: 32));
      expect(vals.every((e) => e.toInt() == 0xfeedbeef), isTrue);
    });

    test('runtime logic is applied to all', () async {
      final resetValue = Logic(width: 32)..inject(0xcafef00d);
      final vals = await setupAndDumpRf(resetValue);
      expect(vals.every((e) => e.toInt() == 0xcafef00d), isTrue);
    });

    test('typed runtime logic is applied to all', () async {
      final resetValue = LogicArray([4], 8)..inject(0xcafef00d);
      final vals = await setupAndDumpRf(resetValue);
      expect(vals.every((e) => e.toInt() == 0xcafef00d), isTrue);
    });

    test('structured constant reset is applied as packed bits', () async {
      final resetValue = FixedPoint.constant(FixedPointValue.withSignedness(
          integer: LogicValue.ofInt(0x1234, 16),
          fraction: LogicValue.ofInt(0x5678, 16)));
      final vals = await setupAndDumpRf(resetValue);
      expect(vals.every((value) => value.toInt() == 0x12345678), isTrue);
    });

    group('list', () {
      test('list applies to corresponding entries', () async {
        final vals = await setupAndDumpRf(
            [null, true, Const(5, width: 32), LogicValue.ofInt(0xa5a5, 32)]);
        expect(vals.map((e) => e.toInt()).toList(), [0, 1, 5, 0xa5a5]);
      });

      test('missized list throws', () {
        expect(setupAndDumpRf([1, 2]), throwsA(isA<RohdHclException>()));
      });
    });

    group('map', () {
      test('map applies to specified entries', () async {
        final vals = await setupAndDumpRf({
          1: 1,
          3: BigInt.two,
        });
        expect(vals.map((e) => e.toInt()), [0, 1, 0, 2]);
      });

      test('too big key throws', () {
        expect(setupAndDumpRf({5: 2}), throwsA(isA<RohdHclException>()));
      });

      test('too small key throws', () {
        expect(setupAndDumpRf({-1: 2}), throwsA(isA<RohdHclException>()));
      });
    });
  });
}
