// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// direct_mapped_cache_test.dart
// All tests for DirectMappedCache component.
//
// Test Groups:
// 1. DirectMapped-specific tests (4 tests)
//    - different addresses map to different lines
//    - conflict miss - same line index, different tag
//    - eviction on overwrite same line
//    - multiple fills to different lines, then conflicts
//
// Additional DirectMappedCache test files:
// - direct_mapped_cache_extensive_eviction_test.dart - 9 comprehensive eviction
//   edge cases
// - direct_mapped_cache_simultaneous_test.dart - 11 simultaneous operation
//   tests
//
// Related test files:
// - cache_test.dart - Common tests for all caches (10 tests for
//   DirectMappedCache)
//   * 4 basic functionality tests (miss/hit, multi-port, simultaneous)
//   * 6 eviction tests (invalidation, hit update, stress, capacity, sequential)
//
// Total: 4 (specific) + 9 (extensive) + 11 (simultaneous) + 10 (common) = 34
// tests
//
// 2025 October 15
// Authors: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>
//          GitHub Copilot <github-copilot@github.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  group('DirectMappedCache', () {
    // Note: 'cache miss then hit' test is in cache_test.dart

    test('different addresses map to different lines', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort = ValidDataPortInterface(32, 8);
      final readPort = ValidDataPortInterface(32, 8);

      final cache = DirectMappedCache(
        clk,
        reset,
        [fillPort],
        [readPort],
      );

      await cache.build();
      unawaited(Simulator.run());

      // Reset
      reset.inject(1);
      fillPort.en.inject(0);
      readPort.en.inject(0);

      await clk.nextPosedge;
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;

      // Fill multiple addresses
      final addresses = [0x00, 0x01, 0x02, 0x03];
      final dataValues = [0x1111, 0x2222, 0x3333, 0x4444];

      for (var i = 0; i < addresses.length; i++) {
        fillPort.en.inject(1);
        fillPort.addr.inject(addresses[i]);
        fillPort.data.inject(dataValues[i]);
        fillPort.valid.inject(1);

        await clk.nextPosedge;
      }

      fillPort.en.inject(0);
      await clk.nextPosedge;

      // Read back all addresses
      for (var i = 0; i < addresses.length; i++) {
        readPort.en.inject(1);
        readPort.addr.inject(addresses[i]);

        await clk.nextPosedge;
        expect(readPort.valid.value.toBool(), true,
            reason: 'Address 0x${addresses[i].toRadixString(16)} should hit');
        expect(readPort.data.value.toInt(), dataValues[i],
            reason: 'Data should match for address '
                '0x${addresses[i].toRadixString(16)}');
      }

      readPort.en.inject(0);
      await clk.nextPosedge;

      await Simulator.endSimulation();
    });

    test('conflict miss - same line index, different tag', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort = ValidDataPortInterface(32, 8);
      final readPort = ValidDataPortInterface(32, 8);

      final cache = DirectMappedCache(
        clk,
        reset,
        [fillPort],
        [readPort],
      );

      await cache.build();
      unawaited(Simulator.run());

      // Reset
      reset.inject(1);
      fillPort.en.inject(0);
      readPort.en.inject(0);

      await clk.nextPosedge;
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;

      // Fill address 0x10 (line 0, tag 1)
      fillPort.en.inject(1);
      fillPort.addr.inject(0x10);
      fillPort.data.inject(0xAAAA);
      fillPort.valid.inject(1);

      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.nextPosedge;

      // Read address 0x10 (should hit)
      readPort.en.inject(1);
      readPort.addr.inject(0x10);

      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), true);
      expect(readPort.data.value.toInt(), 0xAAAA);

      readPort.en.inject(0);
      await clk.nextPosedge;

      // Fill address 0x00 (line 0, tag 0) - conflicts with 0x10
      fillPort.en.inject(1);
      fillPort.addr.inject(0x00);
      fillPort.data.inject(0xBBBB);
      fillPort.valid.inject(1);

      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.nextPosedge;

      // Read address 0x10 again (should miss now - evicted by 0x00)
      readPort.en.inject(1);
      readPort.addr.inject(0x10);

      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), false); // Miss due to conflict

      readPort.en.inject(0);
      await clk.nextPosedge;

      // Read address 0x00 (should hit)
      readPort.en.inject(1);
      readPort.addr.inject(0x00);

      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), true);
      expect(readPort.data.value.toInt(), 0xBBBB);

      readPort.en.inject(0);
      await clk.nextPosedge;

      await Simulator.endSimulation();
    });

    // Note: 'multiple read and fill ports' test is in cache_test.dart
  });

  group('DirectMappedCache eviction tests', () {
    // Note: 'eviction on invalidate' and 'no eviction on hit' are in
    // cache_test.dart DirectMapped-specific eviction tests:
    test('eviction on overwrite same line', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort = ValidDataPortInterface(8, 8);
      final readPort = ValidDataPortInterface(8, 8);
      final evictionPort = ValidDataPortInterface(8, 8);

      final cache = DirectMappedCache(clk, reset, [fillPort], [readPort],
          evictions: [evictionPort], lines: 4);

      await cache.build();
      unawaited(Simulator.run());

      // Reset
      reset.inject(1);
      fillPort.en.inject(0);
      fillPort.valid.inject(0);
      fillPort.addr.inject(0);
      fillPort.data.inject(0);
      readPort.en.inject(0);
      readPort.addr.inject(0);
      await clk.waitCycles(2);

      reset.inject(0);
      await clk.waitCycles(1);

      // First fill: address 0x10 with data 0xAA
      // Line index = 0x10 & 0x3 = 0
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x10);
      fillPort.data.inject(0xAA);

      // Check eviction in the same simulation time
      Simulator.registerAction(Simulator.time + 1, () {
        expect(evictionPort.valid.value.toBool(), isFalse,
            reason: 'First fill should not evict (line was empty)');
      });

      await clk.nextPosedge;

      fillPort.en.inject(0);
      await clk.waitCycles(1);

      // Verify first entry exists
      readPort.en.inject(1);
      readPort.addr.inject(0x10);
      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), isTrue,
          reason: 'First entry should exist');
      expect(readPort.data.value.toInt(), equals(0xAA),
          reason: 'First entry data should be 0xAA');

      readPort.en.inject(0);
      await clk.waitCycles(1);

      // Second fill: different address (0x14) mapping to same line with data
      // 0xBB Line index = 0x14 & 0x3 = 0 (same line as 0x10).
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x14);
      fillPort.data.inject(0xBB);

      // Wait a bit for combinational logic to settle
      Simulator.registerAction(Simulator.time + 1, () {
        expect(evictionPort.valid.value.toBool(), isTrue,
            reason: 'Second fill should evict first entry (line conflict)');
        expect(evictionPort.addr.value.toInt(), equals(0x10),
            reason: 'Evicted address should be 0x10');
        expect(evictionPort.data.value.toInt(), equals(0xAA),
            reason: 'Evicted data should be 0xAA (first entry data)');
      });

      await clk.nextPosedge;

      fillPort.en.inject(0);
      await clk.waitCycles(1);

      // Verify second entry now exists and first is gone
      readPort.en.inject(1);
      readPort.addr.inject(0x14);
      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), isTrue,
          reason: 'Second entry should exist');
      expect(readPort.data.value.toInt(), equals(0xBB),
          reason: 'Second entry data should be 0xBB');

      readPort.en.inject(0);
      await clk.waitCycles(1);

      // Verify first entry is evicted
      readPort.en.inject(1);
      readPort.addr.inject(0x10);
      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), isFalse,
          reason: 'First entry should be evicted (miss)');

      readPort.en.inject(0);
      await Simulator.endSimulation();
    });

    test('multiple fills to different lines, then conflicts', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort = ValidDataPortInterface(8, 8);
      final readPort = ValidDataPortInterface(8, 8);
      final evictionPort = ValidDataPortInterface(8, 8);

      final cache = DirectMappedCache(clk, reset, [fillPort], [readPort],
          evictions: [evictionPort], lines: 4);

      await cache.build();
      unawaited(Simulator.run());

      // Reset
      reset.inject(1);
      fillPort.en.inject(0);
      fillPort.valid.inject(0);
      fillPort.addr.inject(0);
      fillPort.data.inject(0);
      readPort.en.inject(0);
      readPort.addr.inject(0);
      await clk.waitCycles(2);

      reset.inject(0);
      await clk.waitCycles(1);

      // Fill all 4 lines with different data
      final addresses = [0x00, 0x01, 0x02, 0x03];
      final dataValues = [0x11, 0x22, 0x33, 0x44];

      for (var i = 0; i < 4; i++) {
        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(addresses[i]);
        fillPort.data.inject(dataValues[i]);

        final captureI = i; // Capture for closure
        Simulator.registerAction(Simulator.time + 1, () {
          expect(evictionPort.valid.value.toBool(), isFalse,
              reason: 'Initial fill $captureI should not evict (line empty)');
        });

        await clk.nextPosedge;

        fillPort.en.inject(0);
        await clk.waitCycles(1);
      }

      // Now cause a conflict: address 0x04 maps to same line as 0x00 (line 0)
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x04);
      fillPort.data.inject(0x55);

      // Check eviction in the same simulation time
      Simulator.registerAction(Simulator.time + 1, () {
        expect(evictionPort.valid.value.toBool(), isTrue,
            reason: 'Conflict fill should evict');
        expect(evictionPort.addr.value.toInt(), equals(0x00),
            reason: 'Evicted address should be 0x00');
        expect(evictionPort.data.value.toInt(), equals(0x11),
            reason: 'Evicted data should be 0x11');
      });

      await clk.nextPosedge;

      fillPort.en.inject(0);
      await clk.waitCycles(1);

      // Verify new entry exists
      readPort.en.inject(1);
      readPort.addr.inject(0x04);
      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), isTrue,
          reason: 'New entry should exist');
      expect(readPort.data.value.toInt(), equals(0x55),
          reason: 'New entry data should be 0x55');

      readPort.en.inject(0);
      await clk.waitCycles(1);

      // Verify old entry is gone
      readPort.en.inject(1);
      readPort.addr.inject(0x00);
      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), isFalse,
          reason: 'Old entry should be evicted');

      readPort.en.inject(0);
      await Simulator.endSimulation();
    });
  });
}
