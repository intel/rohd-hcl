// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// resettable_entries_test.dart
// Tests for resettable entries
//
// 2025 September 3
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/exceptions.dart';
import 'package:rohd_hcl/src/memory/memories.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  group('resettable entries on rf', () {
    Future<List<LogicValue>> setupAndDumpRf(dynamic resetValue,
        {bool dumpWaves = false}) async {
      const numEntries = 4;
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();
      final rdPort = DataPortInterface(32, 8);
      final rf = RegisterFile(clk, reset, [], [rdPort],
          resetValue: resetValue, numEntries: numEntries);

      await rf.build();

      if (dumpWaves) {
        WaveDumper(rf);
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

    group('list', () {
      test('list applies to corresponding entries', () async {
        final vals = await setupAndDumpRf(
            [null, true, Const(5, width: 32), LogicValue.ofInt(0xa5a5, 32)]);
        expect(vals.map((e) => e.toInt()).toList(), [0, 1, 5, 0xa5a5]);
      });

      test('missized list throws', () async {
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

      test('too big key throws', () async {
        expect(setupAndDumpRf({5: 2}), throwsA(isA<RohdHclException>()));
      });

      test('too small key throws', () async {
        expect(setupAndDumpRf({-1: 2}), throwsA(isA<RohdHclException>()));
      });
    });
  });
}
