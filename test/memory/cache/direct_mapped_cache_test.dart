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
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

import 'cache_test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  group('DirectMappedCache', () {
    // Note: 'cache miss then hit' test is in cache_test.dart

    test('different addresses map to different lines', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final cp =
          CachePorts.fresh(32, 8, numFills: 1, numReads: 1, numEvictions: 0);
      final cache = cp.createCache(clk, reset, directMappedFactory());

      await cache.build();
      unawaited(Simulator.run());

      // Reset
      await cp.resetCache(clk, reset);

      // Fill multiple addresses
      final addresses = [0x00, 0x01, 0x02, 0x03];
      final dataValues = [0x1111, 0x2222, 0x3333, 0x4444];

      for (var i = 0; i < addresses.length; i++) {
        final fillPort = cp.fillPorts[0];
        fillPort.en.inject(1);
        fillPort.addr.inject(addresses[i]);
        fillPort.data.inject(dataValues[i]);
        fillPort.valid.inject(1);

        await clk.nextPosedge;
      }

      cp.fillPorts[0].en.inject(0);
      await clk.nextPosedge;

      // Read back all addresses
      for (var i = 0; i < addresses.length; i++) {
        final readPort = cp.readPorts[0];
        readPort.en.inject(1);
        readPort.addr.inject(addresses[i]);

        await clk.nextPosedge;
        expect(readPort.valid.value.toBool(), true,
            reason: 'Address 0x${addresses[i].toRadixString(16)} should hit');
        expect(readPort.data.value.toInt(), dataValues[i],
            reason: 'Data should match for address '
                '0x${addresses[i].toRadixString(16)}');
      }

      cp.readPorts[0].en.inject(0);
      await clk.nextPosedge;

      await Simulator.endSimulation();
    });

    test('conflict miss - same line index, different tag', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final cp =
          CachePorts.fresh(32, 8, numFills: 1, numReads: 1, numEvictions: 0);
      final cache = cp.createCache(clk, reset, directMappedFactory());

      await cache.build();
      unawaited(Simulator.run());

      // Reset
      await cp.resetCache(clk, reset);

      // Fill address 0x10 (line 0, tag 1)
      final fillPort = cp.fillPorts[0];
      final readPort = cp.readPorts[0];

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
      final cp = CachePorts.fresh(8, 8,
          numFills: 1,
          numReads: 1,
          numEvictions: 1,
          attachEvictionsToFills: true);
      final cache = cp.createCache(clk, reset, directMappedFactory());

      await cache.build();
      unawaited(Simulator.run());

      // Reset
      await cp.resetCache(clk, reset);

      // First fill: address 0x10 with data 0xAA
      // Line index = 0x10 & 0x3 = 0
      final fillPort = cp.fillPorts[0];
      final readPort = cp.readPorts[0];
      final evictionPort = cp.evictionPorts[0];

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

      final cp = CachePorts.fresh(8, 8,
          numFills: 1,
          numReads: 1,
          numEvictions: 1,
          attachEvictionsToFills: true);
      final cache = cp.createCache(clk, reset, directMappedFactory());

      await cache.build();
      unawaited(Simulator.run());

      // Reset using centralized helper
      await cp.resetCache(clk, reset);

      // Fill all 4 lines with different data
      final addresses = [0x00, 0x01, 0x02, 0x03];
      final dataValues = [0x11, 0x22, 0x33, 0x44];

      for (var i = 0; i < 4; i++) {
        final fillPort = cp.fillPorts[0];
        final evictionPort = cp.evictionPorts[0];

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
      final fillPort = cp.fillPorts[0];
      final readPort = cp.readPorts[0];
      final evictionPort = cp.evictionPorts[0];

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

  group('DirectMappedCache simultaneous read/write tests (merged)', () {
    test('simultaneous read hit and fill miss to different lines', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final cp =
          CachePorts.fresh(8, 8, numReads: 1, numFills: 1, numEvictions: 0);
      final cache = cp.createCache(clk, reset, directMappedFactory());
      await cache.build();
      unawaited(Simulator.run());

      await cp.resetCache(clk, reset);
      final fillPort = cp.fillPorts[0];
      final readPort = cp.readPorts[0];

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

    test('simultaneous fills to different lines', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final cp = CachePorts.fresh(8, 8, numReads: 1, numEvictions: 0);
      final cache = cp.createCache(clk, reset, directMappedFactory());
      await cache.build();
      unawaited(Simulator.run());

      await cp.resetCache(clk, reset);
      final fillPort0 = cp.fillPorts[0];
      final fillPort1 = cp.fillPorts[1];
      final readPort = cp.readPorts[0];

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

      final cp = CachePorts.fresh(8, 8, numReads: 1, numEvictions: 0);
      final cache = cp.createCache(clk, reset, directMappedFactory());
      await cache.build();
      unawaited(Simulator.run());

      await cp.resetCache(clk, reset);
      final fillPort0 = cp.fillPorts[0];
      final fillPort1 = cp.fillPorts[1];
      final readPort = cp.readPorts[0];

      // Simultaneously fill same line with different addresses
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

      // Port 1 should win the conflict
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

    test('simultaneous fill with eviction and read to same line', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final cp = CachePorts.fresh(8, 8,
          numFills: 1,
          numReads: 1,
          numEvictions: 1,
          attachEvictionsToFills: true);
      final cache = cp.createCache(clk, reset, directMappedFactory());
      await cache.build();
      unawaited(Simulator.run());

      await cp.resetCache(clk, reset);
      final fillPort = cp.fillPorts[0];
      final readPort = cp.readPorts[0];
      final evictionPort = cp.evictionPorts[0];

      // Pre-fill line 0
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x10);
      fillPort.data.inject(0xAA);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.waitCycles(1);

      // Simultaneously: Fill to same line (causing eviction) and read from that
      readPort.en.inject(1);
      readPort.addr.inject(0x10); // Read old entry
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x14); // Conflicts with 0x10
      fillPort.data.inject(0xCC);

      Simulator.registerAction(Simulator.time + 1, () {
        expect(evictionPort.valid.value.toBool(), isTrue,
            reason: 'Fill should trigger eviction');
        expect(evictionPort.addr.value.toInt(), equals(0x10),
            reason: 'Should evict 0x10');
        expect(evictionPort.data.value.toInt(), equals(0xAA),
            reason: 'Should evict data 0xAA');
      });

      await clk.nextPosedge;

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

      final cp =
          CachePorts.fresh(8, 8, numReads: 1, attachEvictionsToFills: true);
      final cache = cp.createCache(clk, reset, directMappedFactory());
      await cache.build();
      unawaited(Simulator.run());

      await cp.resetCache(clk, reset);
      final fillPort0 = cp.fillPorts[0];
      final fillPort1 = cp.fillPorts[1];
      final readPort = cp.readPorts[0];
      final evictionPort0 = cp.evictionPorts[0];
      final evictionPort1 = cp.evictionPorts[1];

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

    test('stress test: many simultaneous operations', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final cp = CachePorts.fresh(8, 8, attachEvictionsToFills: true);
      final cache = cp.createCache(clk, reset, directMappedFactory(lines: 8));
      await cache.build();
      unawaited(Simulator.run());

      await cp.resetCache(clk, reset);
      final fillPort0 = cp.fillPorts[0];
      final fillPort1 = cp.fillPorts[1];
      final readPort0 = cp.readPorts[0];
      final readPort1 = cp.readPorts[1];
      final evictionPort0 = cp.evictionPorts[0];
      final evictionPort1 = cp.evictionPorts[1];

      // Perform 30 cycles of simultaneous operations
      var evictionCount = 0;
      for (var cycle = 0; cycle < 30; cycle++) {
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

      expect(evictionCount, greaterThan(0),
          reason: 'Should have some evictions during stress test');

      await Simulator.endSimulation();
    });

    test('simultaneous fill hit and read miss to same line', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final cp =
          CachePorts.fresh(8, 8, numFills: 1, numReads: 1, numEvictions: 0);
      final cache = cp.createCache(clk, reset, directMappedFactory());
      await cache.build();
      unawaited(Simulator.run());

      await cp.resetCache(clk, reset);
      final fillPort = cp.fillPorts[0];
      final readPort = cp.readPorts[0];

      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x10);
      fillPort.data.inject(0xAA);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.waitCycles(1);

      // Simultaneously: Fill to same address (hit) and read different address
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x10);
      fillPort.data.inject(0xBB); // Update

      readPort.en.inject(1);
      readPort.addr.inject(0x14); // Same line, different tag (miss)

      await clk.nextPosedge;

      expect(readPort.valid.value.toBool(), isFalse,
          reason: 'Read should miss (different tag)');

      fillPort.en.inject(0);
      readPort.en.inject(0);
      await clk.waitCycles(1);

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

  group('DirectMappedCache extensive eviction tests (merged)', () {
    test('sequential evictions across all lines', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final cp = CachePorts.fresh(8, 8, attachEvictionsToFills: true);
      final cache = cp.createCache(clk, reset, directMappedFactory(lines: 8));
      await cache.build();
      unawaited(Simulator.run());

      await cp.resetCache(clk, reset);

      final fillPort = cp.fillPorts[0];
      final evictionPort = cp.evictionPorts[0];
      for (var line = 0; line < 8; line++) {
        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(line);
        fillPort.data.inject(0x10 + line);

        Simulator.registerAction(Simulator.time + 1, () {
          expect(evictionPort.valid.value.toBool(), isFalse,
              reason: 'Initial fill of line $line should not evict');
        });

        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);
      }

      // overwrite each line and verify evictions
      for (var line = 0; line < 8; line++) {
        final originalAddr = line;
        final originalData = 0x10 + line;
        final conflictAddr = line + 0x08;
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

      final cp = CachePorts.fresh(8, 8,
          numReads: 1,
          numFills: 1,
          numEvictions: 1,
          attachEvictionsToFills: true);
      final cache = cp.createCache(clk, reset, directMappedFactory());
      await cache.build();
      unawaited(Simulator.run());

      await cp.resetCache(clk, reset);

      final fillPort = cp.fillPorts[0];
      final evictionPort = cp.evictionPorts[0];

      final addresses = [0x00, 0x04, 0x08, 0x0C];
      final dataValues = [0xAA, 0xBB, 0xCC, 0xDD];

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
  });
}
