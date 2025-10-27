// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// read_with_invalidate_test.dart
// Test for readWithInvalidate functionality in FullyAssociativeCache.
//
// 2025 October 26

import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  group('ReadWithInvalidate tests', () {
    test('basic readWithInvalidate functionality', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      // Create interfaces with readWithInvalidate capability
      final readIntf =
          ValidDataPortInterface(8, 8, hasReadWithInvalidate: true);
      final fillIntf = ValidDataPortInterface(8, 8);

      final cache = FullyAssociativeCache(
        clk,
        reset,
        [fillIntf], // Fill ports
        [readIntf], // Read ports
      );

      await cache.build();

      WaveDumper(cache, outputPath: 'read_with_invalidate_test.vcd');

      Simulator.setMaxSimTime(500);
      unawaited(Simulator.run());

      // Reset sequence
      reset.inject(1);
      readIntf.en.inject(0);
      readIntf.addr.inject(0);
      readIntf.readWithInvalidate.inject(0);
      fillIntf.en.inject(0);
      fillIntf.valid.inject(0);
      fillIntf.addr.inject(0);
      fillIntf.data.inject(0);
      await clk.waitCycles(2);

      reset.inject(0);
      await clk.waitCycles(1);

      print('=== ReadWithInvalidate Test ===');

      // Step 1: Fill cache with data
      print('Step 1: Filling cache entry');
      fillIntf.en.inject(1);
      fillIntf.valid.inject(1);
      fillIntf.addr.inject(0x42);
      fillIntf.data.inject(0xAB);
      await clk.nextPosedge;

      fillIntf.en.inject(0);
      await clk.nextPosedge;

      // Step 2: Normal read (should hit)
      print('Step 2: Normal read (should hit)');
      readIntf.en.inject(1);
      readIntf.addr.inject(0x42);
      readIntf.readWithInvalidate.inject(0);
      await clk.nextPosedge;

      expect(readIntf.valid.value.toBool(), isTrue,
          reason: 'Should hit on normal read');
      expect(readIntf.data.value.toInt(), equals(0xAB),
          reason: 'Should return correct data');
      print('✅ Normal read hit with data: '
          '0x${readIntf.data.value.toInt().toRadixString(16)}');

      readIntf.en.inject(0);
      await clk.nextPosedge;

      // Step 3: Read with invalidate (should hit and invalidate)
      print('Step 3: Read with invalidate (should hit and invalidate)');
      readIntf.en.inject(1);
      readIntf.addr.inject(0x42);
      readIntf.readWithInvalidate.inject(1);
      await clk.nextPosedge;

      expect(readIntf.valid.value.toBool(), isTrue,
          reason: 'Should hit on readWithInvalidate');
      expect(readIntf.data.value.toInt(), equals(0xAB),
          reason: 'Should return correct data');
      print('✅ ReadWithInvalidate hit with data: '
          '0x${readIntf.data.value.toInt().toRadixString(16)}');

      readIntf.en.inject(0);
      readIntf.readWithInvalidate.inject(0);
      await clk.nextPosedge;

      // Step 4: Read again (should miss after invalidation)
      print('Step 4: Reading again after invalidation (should miss)');
      readIntf.en.inject(1);
      readIntf.addr.inject(0x42);
      await clk.nextPosedge;

      expect(readIntf.valid.value.toBool(), isFalse,
          reason: 'Should miss after invalidation');
      print('✅ Read missed after invalidation as expected');

      readIntf.en.inject(0);
      await clk.nextPosedge;

      await Simulator.endSimulation();
      print('=== ReadWithInvalidate Test Complete ===');
    });

    test('readWithInvalidate with multiple entries', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final readIntf =
          ValidDataPortInterface(8, 8, hasReadWithInvalidate: true);
      final fillIntf = ValidDataPortInterface(8, 8);

      final cache = FullyAssociativeCache(
        clk,
        reset,
        [fillIntf],
        [readIntf],
      );

      await cache.build();

      WaveDumper(cache, outputPath: 'read_with_invalidate_multi_test.vcd');

      Simulator.setMaxSimTime(800);
      unawaited(Simulator.run());

      // Reset
      reset.inject(1);
      readIntf.en.inject(0);
      readIntf.addr.inject(0);
      readIntf.readWithInvalidate.inject(0);
      fillIntf.en.inject(0);
      fillIntf.valid.inject(0);
      fillIntf.addr.inject(0);
      fillIntf.data.inject(0);
      await clk.waitCycles(2);

      reset.inject(0);
      await clk.waitCycles(1);

      print('=== Multiple Entry ReadWithInvalidate Test ===');

      // Fill multiple entries
      final addresses = [0x10, 0x20, 0x30];
      final dataValues = [0xAA, 0xBB, 0xCC];

      for (var i = 0; i < addresses.length; i++) {
        print('Filling address 0x${addresses[i].toRadixString(16)} with '
            'data 0x${dataValues[i].toRadixString(16)}');
        fillIntf.en.inject(1);
        fillIntf.valid.inject(1);
        fillIntf.addr.inject(addresses[i]);
        fillIntf.data.inject(dataValues[i]);
        await clk.nextPosedge;

        fillIntf.en.inject(0);
        await clk.nextPosedge;
      }

      // Verify all entries can be read
      for (var i = 0; i < addresses.length; i++) {
        readIntf.en.inject(1);
        readIntf.addr.inject(addresses[i]);
        await clk.nextPosedge;

        expect(readIntf.valid.value.toBool(), isTrue);
        expect(readIntf.data.value.toInt(), equals(dataValues[i]));
        print('✅ Entry $i: addr=0x${addresses[i].toRadixString(16)}, '
            'data=0x${readIntf.data.value.toInt().toRadixString(16)}');

        readIntf.en.inject(0);
        await clk.nextPosedge;
      }

      // Invalidate middle entry
      print('Invalidating middle entry (0x20)');
      readIntf.en.inject(1);
      readIntf.addr.inject(0x20);
      readIntf.readWithInvalidate.inject(1);
      await clk.nextPosedge;

      expect(readIntf.valid.value.toBool(), isTrue);
      expect(readIntf.data.value.toInt(), equals(0xBB));

      readIntf.en.inject(0);
      readIntf.readWithInvalidate.inject(0);
      await clk.nextPosedge;

      // Verify first and third entries still exist, middle is gone
      final expectedResults = [true, false, true];
      for (var i = 0; i < addresses.length; i++) {
        readIntf.en.inject(1);
        readIntf.addr.inject(addresses[i]);
        await clk.nextPosedge;

        final shouldHit = expectedResults[i];
        expect(readIntf.valid.value.toBool(), equals(shouldHit),
            reason: 'Entry $i (addr=0x${addresses[i].toRadixString(16)}) '
                'should ${shouldHit ? "hit" : "miss"}');

        if (shouldHit) {
          expect(readIntf.data.value.toInt(), equals(dataValues[i]));
          print('✅ Entry $i still valid: '
              'addr=0x${addresses[i].toRadixString(16)}, '
              'data=0x${readIntf.data.value.toInt().toRadixString(16)}');
        } else {
          print('✅ Entry $i invalidated as expected: '
              'addr=0x${addresses[i].toRadixString(16)}');
        }

        readIntf.en.inject(0);
        await clk.nextPosedge;
      }

      await Simulator.endSimulation();
      print('=== Multiple Entry ReadWithInvalidate Test Complete ===');
    });

    test('readWithInvalidate validation - should reject on fill ports', () {
      expect(() {
        ValidDataPortInterface(8, 8, hasReadWithInvalidate: true);
        final fillIntf =
            ValidDataPortInterface(8, 8, hasReadWithInvalidate: true);

        FullyAssociativeCache(
          Logic(),
          Logic(),
          [fillIntf], // This should throw
          [],
        );
      }, throwsA(isA<ArgumentError>()));

      print('✅ Correctly rejected readWithInvalidate on fill port');
    });
  });
}
