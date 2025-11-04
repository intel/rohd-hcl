// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// direct_mapped_cache_simultaneous_test.dart
// DirectMapped-specific tests for simultaneous read/write operations.
//
// These tests focus on line-based conflict behavior unique to
// DirectMappedCache.
// General simultaneous operation tests are in cache_test.dart.
//
// Tests in this file: 7 DirectMapped-specific
// Tests in cache_test.dart: 3 general simultaneous operation tests
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

  group('DirectMappedCache simultaneous read/write tests', () {
    test('simultaneous read hit and fill miss to different lines', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort = ValidDataPortInterface(8, 8);
      final readPort = ValidDataPortInterface(8, 8);

      final cache =
          DirectMappedCache(clk, reset, [fillPort], [readPort], lines: 4);

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

      // Pre-fill line 0
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x10);
      fillPort.data.inject(0xAA);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.waitCycles(1);

      // Simultaneously: Read from line 0 (hit) and fill line 1 (miss)
      readPort.en.inject(1);
      readPort.addr.inject(0x10); // Line 0
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x21); // Line 1
      fillPort.data.inject(0xBB);

      await clk.nextPosedge;

      // Check read hit
      expect(readPort.valid.value.toBool(), isTrue,
          reason: 'Read should hit on line 0');
      expect(readPort.data.value.toInt(), equals(0xAA),
          reason: 'Read data should be 0xAA');

      readPort.en.inject(0);
      fillPort.en.inject(0);
      await clk.waitCycles(1);

      // Verify both entries exist
      readPort.en.inject(1);
      readPort.addr.inject(0x21);
      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), isTrue,
          reason: 'Line 1 should have new entry');
      expect(readPort.data.value.toInt(), equals(0xBB));

      readPort.en.inject(0);
      await Simulator.endSimulation();
    });

    // Note: 'simultaneous read and fill to same address (update)' is in
    // cache_test.dart.

    test('simultaneous fills to different lines', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort0 = ValidDataPortInterface(8, 8);
      final fillPort1 = ValidDataPortInterface(8, 8);
      final readPort = ValidDataPortInterface(8, 8);

      final cache = DirectMappedCache(
          clk, reset, [fillPort0, fillPort1], [readPort],
          lines: 4);

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

      // Simultaneously fill two different lines
      fillPort0.en.inject(1);
      fillPort0.valid.inject(1);
      fillPort0.addr.inject(0x10); // Line 0
      fillPort0.data.inject(0xAA);

      fillPort1.en.inject(1);
      fillPort1.valid.inject(1);
      fillPort1.addr.inject(0x21); // Line 1
      fillPort1.data.inject(0xBB);

      await clk.nextPosedge;

      fillPort0.en.inject(0);
      fillPort1.en.inject(0);
      await clk.waitCycles(1);

      // Verify both writes succeeded
      readPort.en.inject(1);
      readPort.addr.inject(0x10);
      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), isTrue,
          reason: 'Port 0 write should succeed');
      expect(readPort.data.value.toInt(), equals(0xAA));
      readPort.en.inject(0);
      await clk.waitCycles(1);

      readPort.en.inject(1);
      readPort.addr.inject(0x21);
      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), isTrue,
          reason: 'Port 1 write should succeed');
      expect(readPort.data.value.toInt(), equals(0xBB));

      readPort.en.inject(0);
      await Simulator.endSimulation();
    });

    test('simultaneous fills to same line (conflict)', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort0 = ValidDataPortInterface(8, 8);
      final fillPort1 = ValidDataPortInterface(8, 8);
      final readPort = ValidDataPortInterface(8, 8);

      final cache = DirectMappedCache(
          clk, reset, [fillPort0, fillPort1], [readPort],
          lines: 4);

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

      // Simultaneously fill same line with different addresses
      // Note: The behavior here depends on write port priority in RegisterFile
      fillPort0.en.inject(1);
      fillPort0.valid.inject(1);
      fillPort0.addr.inject(0x10); // Line 0
      fillPort0.data.inject(0xAA);

      fillPort1.en.inject(1);
      fillPort1.valid.inject(1);
      fillPort1.addr.inject(0x14); // Line 0, different tag
      fillPort1.data.inject(0xBB);

      await clk.nextPosedge;

      fillPort0.en.inject(0);
      fillPort1.en.inject(0);
      await clk.waitCycles(1);

      // Check which one won (RegisterFile processes writes in order)
      // Port 0 writes first, then port 1 overwrites
      readPort.en.inject(1);
      readPort.addr.inject(0x14);
      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), isTrue,
          reason: 'Port 1 (later) should win the conflict');
      expect(readPort.data.value.toInt(), equals(0xBB));
      readPort.en.inject(0);
      await clk.waitCycles(1);

      // Port 0's write should be overwritten
      readPort.en.inject(1);
      readPort.addr.inject(0x10);
      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), isFalse,
          reason: 'Port 0 write was overwritten');

      readPort.en.inject(0);
      await Simulator.endSimulation();
    });

    // Note: 'simultaneous reads from multiple ports' is in cache_test.dart

    test('simultaneous fill with eviction and read to same line', () async {
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

      // Pre-fill line 0
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x10);
      fillPort.data.inject(0xAA);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.waitCycles(1);

      // Simultaneously: Fill to same line (causing eviction) and read from that
      // line/
      readPort.en.inject(1);
      readPort.addr.inject(0x10); // Read old entry
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x14); // Conflicts with 0x10
      fillPort.data.inject(0xCC);

      // Check eviction in same simulation time
      Simulator.registerAction(Simulator.time + 1, () {
        expect(evictionPort.valid.value.toBool(), isTrue,
            reason: 'Fill should trigger eviction');
        expect(evictionPort.addr.value.toInt(), equals(0x10),
            reason: 'Should evict 0x10');
        expect(evictionPort.data.value.toInt(), equals(0xAA),
            reason: 'Should evict data 0xAA');
      });

      await clk.nextPosedge;

      // Read will MISS because the fill happens on the same cycle, updating
      // the tag/data synchronously. The read's tag comparison happens
      // combinationally with the NEW tag already written.
      expect(readPort.valid.value.toBool(), isFalse,
          reason: 'Read misses because fill updates line simultaneously');

      readPort.en.inject(0);
      fillPort.en.inject(0);
      await clk.waitCycles(1);

      // Next read should see NEW data
      readPort.en.inject(1);
      readPort.addr.inject(0x14);
      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), isTrue,
          reason: 'New entry should exist');
      expect(readPort.data.value.toInt(), equals(0xCC));
      readPort.en.inject(0);
      await clk.waitCycles(1);

      // Old entry should be gone
      readPort.en.inject(1);
      readPort.addr.inject(0x10);
      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), isFalse,
          reason: 'Old entry should be evicted');
      readPort.en.inject(0);

      await Simulator.endSimulation();
    });

    test('simultaneous fills causing multiple evictions', () async {
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

      // Pre-fill two lines
      fillPort0.en.inject(1);
      fillPort0.valid.inject(1);
      fillPort0.addr.inject(0x10); // Line 0
      fillPort0.data.inject(0xAA);
      await clk.nextPosedge;
      fillPort0.en.inject(0);
      await clk.waitCycles(1);

      fillPort1.en.inject(1);
      fillPort1.valid.inject(1);
      fillPort1.addr.inject(0x21); // Line 1
      fillPort1.data.inject(0xBB);
      await clk.nextPosedge;
      fillPort1.en.inject(0);
      await clk.waitCycles(1);

      // Simultaneously fill both lines, causing evictions
      fillPort0.en.inject(1);
      fillPort0.valid.inject(1);
      fillPort0.addr.inject(0x14); // Line 0, conflicts with 0x10
      fillPort0.data.inject(0xCC);

      fillPort1.en.inject(1);
      fillPort1.valid.inject(1);
      fillPort1.addr.inject(0x25); // Line 1, conflicts with 0x21
      fillPort1.data.inject(0xDD);

      // Check both evictions
      Simulator.registerAction(Simulator.time + 1, () {
        expect(evictionPort0.valid.value.toBool(), isTrue,
            reason: 'Port 0 should evict');
        expect(evictionPort0.addr.value.toInt(), equals(0x10));
        expect(evictionPort0.data.value.toInt(), equals(0xAA));

        expect(evictionPort1.valid.value.toBool(), isTrue,
            reason: 'Port 1 should evict');
        expect(evictionPort1.addr.value.toInt(), equals(0x21));
        expect(evictionPort1.data.value.toInt(), equals(0xBB));
      });

      await clk.nextPosedge;

      fillPort0.en.inject(0);
      fillPort1.en.inject(0);
      await clk.waitCycles(1);

      // Verify new entries exist
      readPort.en.inject(1);
      readPort.addr.inject(0x14);
      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), isTrue);
      expect(readPort.data.value.toInt(), equals(0xCC));
      readPort.en.inject(0);
      await clk.waitCycles(1);

      readPort.en.inject(1);
      readPort.addr.inject(0x25);
      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), isTrue);
      expect(readPort.data.value.toInt(), equals(0xDD));
      readPort.en.inject(0);

      await Simulator.endSimulation();
    });

    // Note: 'simultaneous read and invalidation' is in cache_test.dart Note:
    // 'simultaneous operations with readWithInvalidate' is in cache_test.dart.

    test('stress test: many simultaneous operations', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort0 = ValidDataPortInterface(8, 8);
      final fillPort1 = ValidDataPortInterface(8, 8);
      final readPort0 = ValidDataPortInterface(8, 8);
      final readPort1 = ValidDataPortInterface(8, 8);
      final evictionPort0 = ValidDataPortInterface(8, 8);
      final evictionPort1 = ValidDataPortInterface(8, 8);

      final cache = DirectMappedCache(
          clk, reset, [fillPort0, fillPort1], [readPort0, readPort1],
          evictions: [evictionPort0, evictionPort1], lines: 8);

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
      readPort0.en.inject(0);
      readPort0.addr.inject(0);
      readPort1.en.inject(0);
      readPort1.addr.inject(0);
      await clk.waitCycles(2);

      reset.inject(0);
      await clk.waitCycles(1);

      // Perform 30 cycles of simultaneous operations
      var evictionCount = 0;
      for (var cycle = 0; cycle < 30; cycle++) {
        // Generate pseudo-random addresses
        final fillAddr0 = (cycle * 7 + 0x10) % 256;
        final fillAddr1 = (cycle * 11 + 0x20) % 256;
        final readAddr0 = ((cycle - 2) * 7 + 0x10) % 256;
        final readAddr1 = ((cycle - 2) * 11 + 0x20) % 256;
        final fillData0 = (cycle * 3) % 256;
        final fillData1 = (cycle * 5) % 256;

        final doFill0 = cycle % 3 != 0;
        final doFill1 = cycle % 3 != 1;
        final doRead0 = cycle >= 2 && cycle.isEven;
        final doRead1 = cycle >= 2 && cycle.isOdd;

        // Perform operations
        if (doFill0) {
          fillPort0.en.inject(1);
          fillPort0.valid.inject(1);
          fillPort0.addr.inject(fillAddr0);
          fillPort0.data.inject(fillData0);
        } else {
          fillPort0.en.inject(0);
        }

        if (doFill1) {
          fillPort1.en.inject(1);
          fillPort1.valid.inject(1);
          fillPort1.addr.inject(fillAddr1);
          fillPort1.data.inject(fillData1);
        } else {
          fillPort1.en.inject(0);
        }

        if (doRead0) {
          readPort0.en.inject(1);
          readPort0.addr.inject(readAddr0);
        } else {
          readPort0.en.inject(0);
        }

        if (doRead1) {
          readPort1.en.inject(1);
          readPort1.addr.inject(readAddr1);
        } else {
          readPort1.en.inject(0);
        }

        // Count evictions
        Simulator.registerAction(Simulator.time + 1, () {
          if (evictionPort0.valid.value.toBool()) {
            evictionCount++;
          }
          if (evictionPort1.valid.value.toBool()) {
            evictionCount++;
          }
        });

        await clk.nextPosedge;
        await clk.waitCycles(1);
      }

      // Should have had some evictions due to conflicts
      expect(evictionCount, greaterThan(0),
          reason: 'Should have some evictions during stress test');

      await Simulator.endSimulation();
    });

    test('simultaneous fill hit and read miss to same line', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort = ValidDataPortInterface(8, 8);
      final readPort = ValidDataPortInterface(8, 8);

      final cache =
          DirectMappedCache(clk, reset, [fillPort], [readPort], lines: 4);

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

      // Pre-fill entry
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x10);
      fillPort.data.inject(0xAA);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.waitCycles(1);

      // Simultaneously: Fill to same address (hit) and read different address
      // in same line (miss).
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x10);
      fillPort.data.inject(0xBB); // Update

      readPort.en.inject(1);
      readPort.addr.inject(0x14); // Same line, different tag (miss)

      await clk.nextPosedge;

      // Read should miss (wrong tag)
      expect(readPort.valid.value.toBool(), isFalse,
          reason: 'Read should miss (different tag)');

      fillPort.en.inject(0);
      readPort.en.inject(0);
      await clk.waitCycles(1);

      // Verify fill updated the entry
      readPort.en.inject(1);
      readPort.addr.inject(0x10);
      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), isTrue);
      expect(readPort.data.value.toInt(), equals(0xBB),
          reason: 'Fill should have updated data');
      readPort.en.inject(0);

      await Simulator.endSimulation();
    });
  });
}
