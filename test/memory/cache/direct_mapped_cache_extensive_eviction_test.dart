// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// direct_mapped_cache_extensive_eviction_test.dart
// Extensive tests for DirectMappedCache eviction port functionality.
//
// 2025 November 3

import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  group('DirectMappedCache extensive eviction tests', () {
    test('sequential evictions across all lines', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort = ValidDataPortInterface(8, 8);
      final readPort = ValidDataPortInterface(8, 8);
      final evictionPort = ValidDataPortInterface(8, 8);

      final cache = DirectMappedCache(clk, reset, [fillPort], [readPort],
          evictions: [evictionPort], lines: 8);

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

      // Fill all 8 lines with initial data
      for (var line = 0; line < 8; line++) {
        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(line); // Addresses 0x00-0x07 map to lines 0-7
        fillPort.data.inject(0x10 + line);

        Simulator.registerAction(Simulator.time + 1, () {
          expect(evictionPort.valid.value.toBool(), isFalse,
              reason: 'Initial fill of line $line should not evict');
        });

        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);
      }

      // Now overwrite each line and verify evictions
      for (var line = 0; line < 8; line++) {
        final originalAddr = line;
        final originalData = 0x10 + line;
        final conflictAddr = line + 0x08; // Same line, different tag
        final newData = 0x20 + line;

        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(conflictAddr);
        fillPort.data.inject(newData);

        final captureLine = line;
        final captureOriginalAddr = originalAddr;
        final captureOriginalData = originalData;
        Simulator.registerAction(Simulator.time + 1, () {
          expect(evictionPort.valid.value.toBool(), isTrue,
              reason: 'Overwriting line $captureLine should evict');
          expect(evictionPort.addr.value.toInt(), equals(captureOriginalAddr),
              reason: 'Evicted address should be original');
          expect(evictionPort.data.value.toInt(), equals(captureOriginalData),
              reason: 'Evicted data should be original');
        });

        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);
      }

      await Simulator.endSimulation();
    });

    test('rapid successive evictions to same line', () async {
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

      // Repeatedly write to addresses that map to line 0
      // Addresses: 0x00, 0x04, 0x08, 0x0C all map to line 0 (line = addr & 0x3)
      final addresses = [0x00, 0x04, 0x08, 0x0C];
      final dataValues = [0xAA, 0xBB, 0xCC, 0xDD];

      // First fill (no eviction)
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(addresses[0]);
      fillPort.data.inject(dataValues[0]);

      Simulator.registerAction(Simulator.time + 1, () {
        expect(evictionPort.valid.value.toBool(), isFalse,
            reason: 'First fill should not evict');
      });

      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.waitCycles(1);

      // Subsequent fills should each evict the previous entry
      for (var i = 1; i < addresses.length; i++) {
        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(addresses[i]);
        fillPort.data.inject(dataValues[i]);

        final captureI = i;
        Simulator.registerAction(Simulator.time + 1, () {
          expect(evictionPort.valid.value.toBool(), isTrue,
              reason: 'Fill $captureI should evict previous entry');
          expect(
              evictionPort.addr.value.toInt(), equals(addresses[captureI - 1]),
              reason: 'Should evict previous address');
          expect(
              evictionPort.data.value.toInt(), equals(dataValues[captureI - 1]),
              reason: 'Should evict previous data');
        });

        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);
      }

      await Simulator.endSimulation();
    });

    test('mixed hits, misses, and evictions', () async {
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

      // Scenario: Fill -> Hit (update) -> Miss (evict) -> Hit (update)

      // 1. Initial fill to line 0 (addr 0x10)
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x10);
      fillPort.data.inject(0x01);

      Simulator.registerAction(Simulator.time + 1, () {
        expect(evictionPort.valid.value.toBool(), isFalse,
            reason: 'Initial fill should not evict');
      });

      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.waitCycles(1);

      // 2. Hit: Update same address (no eviction)
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x10);
      fillPort.data.inject(0x02);

      Simulator.registerAction(Simulator.time + 1, () {
        expect(evictionPort.valid.value.toBool(), isFalse,
            reason: 'Hit (same address) should not evict');
      });

      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.waitCycles(1);

      // Verify data was updated
      readPort.en.inject(1);
      readPort.addr.inject(0x10);
      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), isTrue);
      expect(readPort.data.value.toInt(), equals(0x02),
          reason: 'Data should be updated to 0x02');
      readPort.en.inject(0);
      await clk.waitCycles(1);

      // 3. Miss: Fill different address to same line (eviction)
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x14); // Same line (0), different tag
      fillPort.data.inject(0x03);

      Simulator.registerAction(Simulator.time + 1, () {
        expect(evictionPort.valid.value.toBool(), isTrue,
            reason: 'Miss with conflict should evict');
        expect(evictionPort.addr.value.toInt(), equals(0x10),
            reason: 'Should evict 0x10');
        expect(evictionPort.data.value.toInt(), equals(0x02),
            reason: 'Should evict updated data 0x02');
      });

      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.waitCycles(1);

      // 4. Hit: Update the new entry (no eviction)
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x14);
      fillPort.data.inject(0x04);

      Simulator.registerAction(Simulator.time + 1, () {
        expect(evictionPort.valid.value.toBool(), isFalse,
            reason: 'Hit should not evict');
      });

      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.waitCycles(1);

      // Verify final state
      readPort.en.inject(1);
      readPort.addr.inject(0x14);
      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), isTrue);
      expect(readPort.data.value.toInt(), equals(0x04));
      readPort.en.inject(0);
      await clk.waitCycles(1);

      // Verify old entry is gone
      readPort.en.inject(1);
      readPort.addr.inject(0x10);
      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), isFalse);
      readPort.en.inject(0);

      await Simulator.endSimulation();
    });

    test('invalidation evictions across multiple lines', () async {
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

      // Fill multiple lines
      final addresses = [0x20, 0x31, 0x42, 0x53];
      final dataValues = [0xA0, 0xB1, 0xC2, 0xD3];

      for (var i = 0; i < addresses.length; i++) {
        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(addresses[i]);
        fillPort.data.inject(dataValues[i]);
        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);
      }

      // Invalidate each entry and verify eviction
      for (var i = 0; i < addresses.length; i++) {
        fillPort.en.inject(1);
        fillPort.valid.inject(0); // Invalidation
        fillPort.addr.inject(addresses[i]);

        final captureI = i;
        Simulator.registerAction(Simulator.time + 1, () {
          expect(evictionPort.valid.value.toBool(), isTrue,
              reason: 'Invalidation $captureI should evict');
          expect(evictionPort.addr.value.toInt(), equals(addresses[captureI]),
              reason: 'Evicted address should match invalidated address');
          expect(evictionPort.data.value.toInt(), equals(dataValues[captureI]),
              reason: 'Evicted data should match original data');
        });

        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);

        // Verify entry is now invalid
        readPort.en.inject(1);
        readPort.addr.inject(addresses[i]);
        await clk.nextPosedge;
        expect(readPort.valid.value.toBool(), isFalse,
            reason: 'Entry $i should be invalid after invalidation');
        readPort.en.inject(0);
        await clk.waitCycles(1);
      }

      await Simulator.endSimulation();
    });

    test('no eviction on invalidation of non-existent entry', () async {
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

      // Try to invalidate non-existent entry (should not evict)
      fillPort.en.inject(1);
      fillPort.valid.inject(0); // Invalidation
      fillPort.addr.inject(0x50);

      Simulator.registerAction(Simulator.time + 1, () {
        expect(evictionPort.valid.value.toBool(), isFalse,
            reason: 'Invalidating non-existent entry should not evict');
      });

      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.waitCycles(1);

      // Fill a valid entry to same line
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x50);
      fillPort.data.inject(0xEE);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.waitCycles(1);

      // Try to invalidate with wrong address (same line, different tag)
      fillPort.en.inject(1);
      fillPort.valid.inject(0);
      fillPort.addr.inject(0x54); // Different tag, same line

      Simulator.registerAction(Simulator.time + 1, () {
        expect(evictionPort.valid.value.toBool(), isFalse,
            reason: 'Invalidating wrong address should not evict');
      });

      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.waitCycles(1);

      // Verify original entry still exists
      readPort.en.inject(1);
      readPort.addr.inject(0x50);
      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), isTrue,
          reason: 'Original entry should still be valid');
      expect(readPort.data.value.toInt(), equals(0xEE));
      readPort.en.inject(0);

      await Simulator.endSimulation();
    });

    test('eviction with multiple fill ports', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort0 = ValidDataPortInterface(8, 8);
      final fillPort1 = ValidDataPortInterface(8, 8);
      final readPort = ValidDataPortInterface(8, 8);
      final evictionPort0 = ValidDataPortInterface(8, 8);
      final evictionPort1 = ValidDataPortInterface(8, 8);

      final cache = DirectMappedCache(
          clk, reset, [fillPort0, fillPort1], [readPort],
          evictions: [evictionPort0, evictionPort1], lines: 4);

      await cache.build();
      unawaited(Simulator.run());

      // Reset
      reset.inject(1);
      fillPort0.en.inject(0);
      fillPort0.valid.inject(0);
      fillPort0.addr.inject(0);
      fillPort0.data.inject(0);
      fillPort1.en.inject(0);
      fillPort1.valid.inject(0);
      fillPort1.addr.inject(0);
      fillPort1.data.inject(0);
      readPort.en.inject(0);
      readPort.addr.inject(0);
      await clk.waitCycles(2);

      reset.inject(0);
      await clk.waitCycles(1);

      // Fill using port 0
      fillPort0.en.inject(1);
      fillPort0.valid.inject(1);
      fillPort0.addr.inject(0x10);
      fillPort0.data.inject(0xAA);
      await clk.nextPosedge;
      fillPort0.en.inject(0);
      await clk.waitCycles(1);

      // Fill using port 1 to different line
      fillPort1.en.inject(1);
      fillPort1.valid.inject(1);
      fillPort1.addr.inject(0x21);
      fillPort1.data.inject(0xBB);
      await clk.nextPosedge;
      fillPort1.en.inject(0);
      await clk.waitCycles(1);

      // Evict using port 0 (should evict on port 0)
      fillPort0.en.inject(1);
      fillPort0.valid.inject(1);
      fillPort0.addr.inject(0x14); // Conflicts with 0x10
      fillPort0.data.inject(0xCC);

      Simulator.registerAction(Simulator.time + 1, () {
        expect(evictionPort0.valid.value.toBool(), isTrue,
            reason: 'Port 0 should evict');
        expect(evictionPort0.addr.value.toInt(), equals(0x10));
        expect(evictionPort0.data.value.toInt(), equals(0xAA));
        expect(evictionPort1.valid.value.toBool(), isFalse,
            reason: 'Port 1 should not evict');
      });

      await clk.nextPosedge;
      fillPort0.en.inject(0);
      await clk.waitCycles(1);

      // Evict using port 1 (should evict on port 1)
      fillPort1.en.inject(1);
      fillPort1.valid.inject(1);
      fillPort1.addr.inject(0x25); // Conflicts with 0x21
      fillPort1.data.inject(0xDD);

      Simulator.registerAction(Simulator.time + 1, () {
        expect(evictionPort1.valid.value.toBool(), isTrue,
            reason: 'Port 1 should evict');
        expect(evictionPort1.addr.value.toInt(), equals(0x21));
        expect(evictionPort1.data.value.toInt(), equals(0xBB));
        expect(evictionPort0.valid.value.toBool(), isFalse,
            reason: 'Port 0 should not evict');
      });

      await clk.nextPosedge;
      fillPort1.en.inject(0);
      await clk.waitCycles(1);

      await Simulator.endSimulation();
    });

    test('eviction address reconstruction with various tags', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort = ValidDataPortInterface(8, 8);
      final readPort = ValidDataPortInterface(8, 8);
      final evictionPort = ValidDataPortInterface(8, 8);

      // 8 lines means 3-bit line address, 5-bit tag
      final cache = DirectMappedCache(clk, reset, [fillPort], [readPort],
          evictions: [evictionPort], lines: 8);

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

      // Test various addresses to verify tag reconstruction
      final testCases = [
        {'addr': 0x08, 'conflictAddr': 0x10, 'data': 0x11}, // Line 0
        {'addr': 0x19, 'conflictAddr': 0x21, 'data': 0x22}, // Line 1
        {'addr': 0x2A, 'conflictAddr': 0x32, 'data': 0x33}, // Line 2
        {'addr': 0xFB, 'conflictAddr': 0x03, 'data': 0x44}, // Line 3
      ];

      for (final testCase in testCases) {
        final addr = testCase['addr']!;
        final conflictAddr = testCase['conflictAddr']!;
        final data = testCase['data']!;

        // Fill initial entry
        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(addr);
        fillPort.data.inject(data);
        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);

        // Create conflict and verify eviction address
        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(conflictAddr);
        fillPort.data.inject(data + 0x10);

        final captureAddr = addr;
        final captureData = data;
        Simulator.registerAction(Simulator.time + 1, () {
          expect(evictionPort.valid.value.toBool(), isTrue,
              reason:
                  'Should evict for addr 0x${captureAddr.toRadixString(16)}');
          expect(evictionPort.addr.value.toInt(), equals(captureAddr),
              reason: 'Evicted address should be correctly reconstructed');
          expect(evictionPort.data.value.toInt(), equals(captureData),
              reason: 'Evicted data should match');
        });

        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);
      }

      await Simulator.endSimulation();
    });

    test('stress test: alternating fills and invalidations', () async {
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

      // Perform 20 operations alternating between fills, invalidations, and
      // conflicts.
      for (var i = 0; i < 20; i++) {
        final addr = (i * 13) % 256; // Semi-random addresses
        final data = (i * 17) % 256;
        final isInvalidate = i % 3 == 2; // Every 3rd operation is invalidate

        if (isInvalidate) {
          // Invalidate: check if entry exists before invalidating
          readPort.en.inject(1);
          readPort.addr.inject(addr);
          await clk.nextPosedge;
          final entryExists = readPort.valid.value.toBool();
          readPort.en.inject(0);
          await clk.waitCycles(1);

          fillPort.en.inject(1);
          fillPort.valid.inject(0);
          fillPort.addr.inject(addr);

          final captureI = i;
          final captureExists = entryExists;
          Simulator.registerAction(Simulator.time + 1, () {
            expect(evictionPort.valid.value.toBool(), equals(captureExists),
                reason:
                    'Iteration $captureI: Invalidation should evict only if '
                    'entry existed');
          });

          await clk.nextPosedge;
        } else {
          // Valid fill
          fillPort.en.inject(1);
          fillPort.valid.inject(1);
          fillPort.addr.inject(addr);
          fillPort.data.inject(data);
          await clk.nextPosedge;
        }

        fillPort.en.inject(0);
        await clk.waitCycles(1);
      }

      await Simulator.endSimulation();
    });

    test('eviction port stays low when disabled', () async {
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

      // Fill entry
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x10);
      fillPort.data.inject(0xAA);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.waitCycles(1);

      // Evict the entry
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x14);
      fillPort.data.inject(0xBB);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.waitCycles(1);

      // Eviction port should go back to low
      await clk.waitCycles(2);
      expect(evictionPort.valid.value.toBool(), isFalse,
          reason: 'Eviction port should be low when no eviction occurring');
      expect(evictionPort.en.value.toBool(), isFalse,
          reason: 'Eviction enable should be low when no eviction occurring');

      // Perform operations that don't cause evictions
      // Cache has 4 lines. Line 0 has 0x14 in it.
      // Fill lines 1, 2, 3 which are currently empty
      final emptyLineAddrs = [0x21, 0x22, 0x23]; // Lines 1, 2, 3
      for (var i = 0; i < emptyLineAddrs.length; i++) {
        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(emptyLineAddrs[i]);
        fillPort.data.inject(0xC0 + i);

        Simulator.registerAction(Simulator.time + 1, () {
          expect(evictionPort.valid.value.toBool(), isFalse,
              reason: 'No eviction should occur for new line fills');
        });

        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);
      }

      await Simulator.endSimulation();
    });
  });
}
