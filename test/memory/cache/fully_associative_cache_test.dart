// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fully_associative_cache_test.dart
// Common tests for fully associative cache.
//
// 2025 November 7
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

import 'cache_test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('RWI with simultaneous fills on different addresses', () async {
    final clk = SimpleClockGenerator(2).clk;
    final reset = Logic();

    const ways = 16;

    final fillPorts = List.generate(2, (_) => ValidDataPortInterface(32, 32));
    final readPorts = List.generate(
        2, (_) => ValidDataPortInterface(32, 32, hasReadWithInvalidate: true));
    final cp = CachePorts(fillPorts, readPorts, <ValidDataPortInterface>[]);
    final cache = cp.createCache(
        clk,
        reset,
        fullyAssociativeFactory(
            ways: ways,
            replacementFactory: AvailableInvalidatedReplacement.new));

    await cache.build();
    unawaited(Simulator.run());
    await cp.resetCache(clk, reset);
    for (final readPort in readPorts) {
      if (readPort.hasReadWithInvalidate) {
        readPort.readWithInvalidate.inject(0);
      }
    }

    // Log suppressed: fill address 0x373 with data 0x10373
    fillPorts[0].addr.inject(0x373);
    fillPorts[0].data.inject(0x10373);
    fillPorts[0].valid.inject(1);
    fillPorts[0].en.inject(1);
    await clk.nextPosedge;
    fillPorts[0].en.inject(0);
    await clk.nextPosedge;

    // Log suppressed: verify 0x373 is in cache
    readPorts[0].addr.inject(0x373);
    readPorts[0].en.inject(1);
    await clk.nextPosedge;
    await clk.nextNegedge;
    var hit = readPorts[0].valid.value.toInt();
    var data = readPorts[0].data.value.toInt();
    expect(hit, 1, reason: 'Should hit after fill (hit=$hit)');
    expect(data, 0x10373,
        reason: 'Should return data=0x${0x10373.toRadixString(16)} '
            '(data=0x${data.toRadixString(16)})');
    readPorts[0].en.inject(0);
    await clk.nextPosedge;

    // Log suppressed: RWI simultaneously with fills description
    fillPorts[0].addr.inject(0x1fd1);
    fillPorts[0].data.inject(0x11fd1);
    fillPorts[0].valid.inject(1);
    fillPorts[0].en.inject(1);

    fillPorts[1].addr.inject(0x1b89);
    fillPorts[1].data.inject(0x11b89);
    fillPorts[1].valid.inject(1);
    fillPorts[1].en.inject(1);

    readPorts[0].addr.inject(0x373);
    readPorts[0].readWithInvalidate.inject(1);
    readPorts[0].en.inject(1);

    await clk.nextPosedge;
    await clk.nextNegedge;

    hit = readPorts[0].valid.value.toInt();
    data = readPorts[0].data.value.toInt();
    expect(hit, 1,
        reason:
            'RWI should hit on 0x373 despite simultaneous fills (hit=$hit)');
    expect(data, 0x10373,
        reason: 'RWI should return correct data 0x${0x10373.toRadixString(16)} '
            '(data=0x${data.toRadixString(16)})');

    for (final fillPort in fillPorts) {
      fillPort.en.inject(0);
    }
    readPorts[0].en.inject(0);
    readPorts[0].readWithInvalidate.inject(0);
    await clk.nextPosedge;

    // Success message implied by above expects.

    await Simulator.endSimulation();
  });

  group('FullyAssociativeCache RWI sequences', () {
    const ways = 32;

    CacheFactory makeFullyAssocFactory({bool generateOccupancy = false}) =>
        fullyAssociativeFactory(
            ways: ways,
            generateOccupancy: generateOccupancy,
            replacementFactory: AvailableInvalidatedReplacement.new);

    test('FullyAssoc 32-way RWI sequence', () async {
      final clk = SimpleClockGenerator(5).clk;
      final reset = Logic();

      final fillPort = ValidDataPortInterface(20, 12);
      final readPort =
          ValidDataPortInterface(20, 12, hasReadWithInvalidate: true);
      final cp = CachePorts([fillPort], [readPort], <ValidDataPortInterface>[]);
      final cache = cp.createCache(clk, reset, makeFullyAssocFactory());

      await cache.build();
      unawaited(Simulator.run());

      await cp.resetCache(clk, reset);
      readPort.readWithInvalidate.inject(0);

      // Helper to convert hex string to int
      int h(String s) => int.parse(s, radix: 16);

      // Helper to apply a cycle: optional fillAddr and optional rwiAddr.
      // Returns the read result (valid, data) if a read occurred.
      Future<(bool, int)?> cycle({String? fillAddr, String? rwiAddr}) async {
        if (fillAddr != null) {
          final addr = h(fillAddr);
          fillPort.addr.inject(addr);
          fillPort.data.inject(0x10000 + addr);
          fillPort.valid.inject(1);
          fillPort.en.inject(1);
        } else {
          fillPort.en.inject(0);
          fillPort.valid.inject(0);
        }

        if (rwiAddr != null) {
          final addr = h(rwiAddr);
          readPort.addr.inject(addr);
          readPort.readWithInvalidate.inject(1);
          readPort.en.inject(1);
        } else {
          readPort.en.inject(0);
          readPort.readWithInvalidate.inject(0);
        }

        await clk.nextPosedge;

        // Capture read result before clearing signals
        (bool, int)? result;
        if (rwiAddr != null) {
          final valid = readPort.valid.value.toBool();
          final data = readPort.data.value.toInt();
          result = (valid, data);
        }

        // Clear signals
        fillPort.en.inject(0);
        fillPort.valid.inject(0);
        readPort.en.inject(0);
        readPort.readWithInvalidate.inject(0);

        return result;
      }

      // Sequence from user: each line is a cycle. "Axxx" is a RWI for xxx.
      final seq = <List<String>>[
        ['301'], // Cycle 0: Fill 301
        ['10e'], // Cycle 1: Fill 10e
        [], // Cycle 2: Empty
        ['310'], // Cycle 3: Fill 310
        [], // Cycle 4: Empty
        ['120', 'A301'], // Cycle 5: Fill 120 + RWI @301 (simultaneous)
        ['121', 'A10e'], // Cycle 6: Fill 121 + RWI @10e (simultaneous)
        ['123'], // Cycle 7: Fill 123
        [], // Cycle 8: Empty
        ['A121'], // Cycle 9: RWI @121
        [], // Cycle 10: Empty
        ['A123'], // Cycle 11: RWI @123
        [], // Cycle 12: Empty
      ];

      for (final line in seq) {
        String? fillAddr;
        String? rwiAddr;
        for (final tok in line) {
          final t = tok.trim();
          if (t.isEmpty) {
            continue;
          }
          if (t.startsWith('A') || t.startsWith('a')) {
            var rest = t.substring(1);
            rest = rest.replaceAll(RegExp('[^0-9a-fA-F]'), '');
            if (rest.isEmpty) {
              continue;
            }
            rwiAddr = rest.toLowerCase();
          } else {
            final cleaned = t.replaceAll(RegExp('[^0-9a-fA-F]'), '');
            if (cleaned.isEmpty) {
              continue;
            }
            fillAddr = cleaned.toLowerCase();
          }
        }
        final result = await cycle(fillAddr: fillAddr, rwiAddr: rwiAddr);

        // Check that reads of filled addresses succeed
        if (rwiAddr == '301') {
          expect(result, isNotNull);
          expect(result!.$1, isTrue, reason: 'RWI @301 should hit');
          expect(result.$2, equals(0x10301),
              reason: 'RWI @301 should return correct data');
        }
        if (rwiAddr == '10e') {
          expect(result, isNotNull);
          expect(result!.$1, isTrue, reason: 'RWI @10e should hit');
          expect(result.$2, equals(0x1010e),
              reason: 'RWI @10e should return correct data');
        }
        if (rwiAddr == '121') {
          expect(result, isNotNull);
          expect(result!.$1, isTrue, reason: 'RWI @121 should hit');
          expect(result.$2, equals(0x10121),
              reason: 'RWI @121 should return correct data');
        }
        if (rwiAddr == '123') {
          expect(result, isNotNull);
          expect(result!.$1, isTrue, reason: 'RWI @123 should hit');
          expect(result.$2, equals(0x10123),
              reason: 'RWI @123 should return correct data');
        }
      }

      await Simulator.endSimulation();
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('FullyAssoc 32-way RWI sequence (copy)', () async {
      final clk = SimpleClockGenerator(5).clk;
      final reset = Logic();

      final fillPort = ValidDataPortInterface(20, 12);
      final readPort =
          ValidDataPortInterface(20, 12, hasReadWithInvalidate: true);
      final cp = CachePorts([fillPort], [readPort], <ValidDataPortInterface>[]);
      final cache = cp.createCache(
          clk, reset, makeFullyAssocFactory(generateOccupancy: true));

      await cache.build();
      unawaited(Simulator.run());

      await cp.resetCache(clk, reset);
      readPort.readWithInvalidate.inject(0);

      int h(String s) => int.parse(s, radix: 16);

      Future<((bool, int)?, bool)> cycle(
          {String? fillAddr, String? rwiAddr}) async {
        if (fillAddr != null) {
          final addr = h(fillAddr);
          fillPort.addr.inject(addr);
          fillPort.data.inject(0x10000 + addr);
          fillPort.valid.inject(1);
          fillPort.en.inject(1);
        } else {
          fillPort.en.inject(0);
          fillPort.valid.inject(0);
        }

        if (rwiAddr != null) {
          final addr = h(rwiAddr);
          readPort.addr.inject(addr);
          readPort.readWithInvalidate.inject(1);
          readPort.en.inject(1);
        } else {
          readPort.en.inject(0);
          readPort.readWithInvalidate.inject(0);
        }

        await clk.nextPosedge;

        // Capture whether read enable was asserted at the posedge for this
        // cycle. The read data/valid becomes stable by the following
        // negedge, so wait one more half-cycle before sampling them.
        final readEn = rwiAddr != null && readPort.en.value.toBool();
        await clk.nextNegedge;

        (bool, int)? result;
        if (rwiAddr != null) {
          final valid = readPort.valid.value.toBool();
          final data = readPort.data.value.toInt();
          result = (valid, data);
        }

        fillPort.en.inject(0);
        fillPort.valid.inject(0);
        readPort.en.inject(0);
        readPort.readWithInvalidate.inject(0);

        return (result, readEn);
      }

      final seq = <List<String>>[
        ['200'],
        ['280'],
        [],
        ['300'],
        [],
        [],
        ['301'],
        ['102'],
        [],
        ['303'],
        ['304'],
        ['305'],
        ['306'],
        ['107'],
        ['10B'],
        ['309'],
        ['30a'],
        [],
        ['30b'],
        ['10c'],
        ['10d'],
        ['10e'],
        [],
        ['310'],
        ['111'],
        ['112'],
        ['113', 'A102'],
        [],
        ['115'],
        ['316'],
        ['317'],
        ['118', 'A305'],
        ['319'],
        ['31a'],
        ['31b'],
        ['31c'],
        [],
        ['A301'],
        ['31f'],
        ['120'],
        ['121', 'A10b'],
        ['A107'],
        ['123'],
        ['124'],
        [],
        ['327'],
        ['32B'],
        [],
        ['32A', 'A200'],
        [],
        ['12C'],
        ['11B'],
        [],
        ['A303'],
        ['A3-00'],
        ['A280'],
        ['A120'],
        [],
        ['A304'],
        ['A306'],
        ['A317'],
        ['A30a'],
        [],
        ['A30b'],
        ['A309'],
        [],
        ['A10d'],
        ['A112'],
        [],
        ['A31c'],
        ['A111'],
        ['A11B'],
        ['A32B'],
        ['A31b'],
        ['A123'],
        ['A310'],
        ['A10c'],
        ['A10e'],
        [],
        ['A32a'],
        [],
        ['A124'],
        ['A115'],
        ['A31a'],
        [],
        ['A319'],
        ['12d'],
        ['A12d'],
        [],
        ['A121'],
        ['A31f'],
        ['A327'],
        [],
        ['12f'],
        ['A12f'],
        ['12e'],
        ['A12e'],
        [],
        ['12c'],
        ['A12c'],
      ];

      var cycleIx = 0;
      for (final line in seq) {
        String? fillAddr;
        String? rwiAddr;
        for (final tok in line) {
          final t = tok.trim();
          if (t.isEmpty) {
            continue;
          }
          if (t.startsWith('A') || t.startsWith('a')) {
            var rest = t.substring(1);
            rest = rest.replaceAll(RegExp('[^0-9a-fA-F]'), '');
            if (rest.isEmpty) {
              continue;
            }
            rwiAddr = rest.toLowerCase();
          } else {
            final cleaned = t.replaceAll(RegExp('[^0-9a-fA-F]'), '');
            if (cleaned.isEmpty) {
              continue;
            }
            fillAddr = cleaned.toLowerCase();
          }
        }

        final pair = await cycle(fillAddr: fillAddr, rwiAddr: rwiAddr);
        final readRes = pair.$1;
        final readEn = pair.$2;

        if (readEn) {
          // When read enable was asserted, read valid should be high.
          expect(readRes, isNotNull,
              reason: 'Cycle $cycleIx: Read enable asserted but '
                  'no result captured');
          expect(readRes!.$1, isTrue,
              reason:
                  'Cycle $cycleIx: read_valid should be high when read_en is '
                  'high (Addr: $rwiAddr)');
        }

        if (rwiAddr != null) {
          // If the read should have hit, assert correct data when applicable.
          if (readRes != null && readRes.$1) {
            final expected = 0x10000 + h(rwiAddr);
            expect(readRes.$2, equals(expected),
                reason: 'RWI @$rwiAddr should return correct data');
          }
        }
        cycleIx++;
      }

      await Simulator.endSimulation();
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
