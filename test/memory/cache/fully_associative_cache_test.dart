// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fully_associative_cache_test.dart
// All tests for FullyAssociativeCache component.
//
// Test categories (within single group):
// 1. Replacement - PseudoLRU replacement policy
// 2. Invalidation - cache invalidation (without eviction port)
// 3. Eviction timing - eviction latency is one cycle
// 4. Multiple fill ports - simultaneous fill port behavior
// 5. ReadWithInvalidate - basic functionality, multiple entries, validation
// 6. ReadWithInvalidate - simultaneous fill + readWithInvalidate operations
//
// Tests covered in cache_test.dart (not duplicated here):
// - basic read miss and hit (cache miss then hit)
// - cache update on hit (no eviction on hit update)
// - multiple read ports (simultaneous reads from multiple ports)
// - complete fill then eviction (eviction on capacity full)
// - invalidation with eviction ports (invalidation eviction)
// - read/write same-cycle precedence (simultaneous read and fill to same
//   address)
// - multiple read ports with simultaneous write (simultaneous reads from
//   multiple ports)
// - fill port invalidation (valid=0)
// - readWithInvalidate comparison
//
// Related test files:
// - cache_test.dart - Common tests for all caches (15 tests for
//   FullyAssociativeCache)
//   * 4 basic functionality tests (miss/hit, multi-port, simultaneous)
//   * 6 eviction tests (invalidation, hit update, stress, capacity, sequential)
//   * 3 simultaneous operation tests
//   * 2 invalidation comparison tests (fill port vs readWithInvalidate)
//
// Total: 8 (specific in this file) + 15 (common in cache_test.dart) = 23 tests
//
// 2025 October 20 Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  group('FullyAssociativeCache', () {
    // Note: Many tests have been moved to cache_test.dart (see header for list)

    test('cache replacement with PseudoLRU', () async {
      const dataWidth = 16;
      const addrWidth = 8;
      const ways = 4;

      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort = ValidDataPortInterface(dataWidth, addrWidth);
      final readPort = ValidDataPortInterface(dataWidth, addrWidth);
      final evictPort = ValidDataPortInterface(dataWidth, addrWidth);

      final cache = FullyAssociativeCache(clk, reset, [fillPort], [readPort],
          evictions: [evictPort]);

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

      // Fill cache to capacity
      final addresses = [0x10, 0x20, 0x30, 0x40];
      final data = [0xDEAD, 0xBEEF, 0xCAFE, 0xBABE];

      for (var i = 0; i < ways; i++) {
        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(addresses[i]);
        fillPort.data.inject(data[i]);
        readPort.en.inject(0);
        await clk.nextPosedge;
      }

      fillPort.en.inject(0);

      // Verify all entries are present
      for (var i = 0; i < ways; i++) {
        readPort.en.inject(1);
        readPort.addr.inject(addresses[i]);
        await clk.nextPosedge;
        expect(readPort.valid.value.toInt(), equals(1),
            reason: 'Entry $i should be present');
        expect(readPort.data.value.toInt(), equals(data[i]),
            reason: 'Entry $i should have correct data');
      }

      // Add one more entry to trigger replacement
      const newAddr = 0x50;
      const newData = 0x1234;

      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(newAddr);
      fillPort.data.inject(newData);
      await clk.nextPosedge;
      fillPort.en.inject(0);

      // Verify new entry is present
      readPort.en.inject(1);
      readPort.addr.inject(newAddr);
      await clk.nextPosedge;
      expect(readPort.valid.value.toInt(), equals(1),
          reason: 'New entry should be present');
      expect(readPort.data.value.toInt(), equals(newData),
          reason: 'New entry should have correct data');

      // Check that one of the original entries was evicted
      var hitCount = 0;
      for (var i = 0; i < ways; i++) {
        readPort.addr.inject(addresses[i]);
        await clk.nextPosedge;
        if (readPort.valid.value.toInt() == 1) {
          hitCount++;
        }
      }
      expect(hitCount, equals(ways - 1),
          reason: 'Should have evicted exactly one entry');

      await Simulator.endSimulation();
    });

    test('cache invalidation', () async {
      const dataWidth = 16;
      const addrWidth = 8;

      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort = ValidDataPortInterface(dataWidth, addrWidth);
      final readPort = ValidDataPortInterface(dataWidth, addrWidth);
      final evictPort = ValidDataPortInterface(dataWidth, addrWidth);

      final cache = FullyAssociativeCache(clk, reset, [fillPort], [readPort],
          evictions: [evictPort]);

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

      // Fill an entry
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x10);
      fillPort.data.inject(0xBEEF);
      readPort.en.inject(0);
      await clk.nextPosedge;

      // Verify entry is present
      fillPort.en.inject(0);
      readPort.en.inject(1);
      readPort.addr.inject(0x10);
      await clk.nextPosedge;
      expect(readPort.valid.value.toInt(), equals(1),
          reason: 'Entry should be present after fill');

      // Request cycle: assert invalidate and sample on the negedge so the
      // eviction outputs (which are combinational) can be observed.
      fillPort.en.inject(1);
      fillPort.valid.inject(0); // Invalid fill = invalidate
      fillPort.addr.inject(0x10);
      readPort.en.inject(0);

      await clk.nextNegedge;
      expect(evictPort.en.value.toInt(), equals(1),
          reason: 'Eviction port should be active during invalidation');
      expect(evictPort.valid.value.toInt(), equals(1),
          reason: 'Eviction should be valid during invalidation');
      expect(evictPort.addr.value.toInt(), equals(0x10),
          reason: 'Eviction port should output the invalidated address');
      expect(evictPort.data.value.toInt(), equals(0xBEEF),
          reason: 'Eviction port should output the invalidated data');

      // Advance to posedge to commit the invalidation write, then disable the
      // fill enable. This keeps the write enable asserted through the
      // posedge so the register file will be updated as expected.
      await clk.nextPosedge;
      fillPort.en.inject(0);

      expect(evictPort.en.value.toInt(), equals(0),
          reason: 'Eviction port should be inactive after invalidation');

      // Verify entry is now invalid
      readPort.en.inject(1);
      readPort.addr.inject(0x10);
      await clk.nextPosedge;
      expect(readPort.valid.value.toInt(), equals(0),
          reason: 'Entry should be invalid after invalidation');

      await Simulator.endSimulation();
    });

    test('eviction latency is one cycle', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fills = List.generate(1, (_) => ValidDataPortInterface(8, 8));
      final reads = List.generate(1, (_) => ValidDataPortInterface(8, 8));
      final evicts = [ValidDataPortInterface(8, 8)];

      final cache = FullyAssociativeCache(clk, reset, fills, reads,
          ways: 2, evictions: evicts);

      await cache.build();
      unawaited(Simulator.run());

      // Reset sequence
      reset.inject(1);
      for (final f in fills) {
        f.en.inject(0);
      }
      for (final r in reads) {
        r.en.inject(0);
      }
      await clk.nextPosedge;
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;

      final fillPort = fills[0];
      final readPort = reads[0];
      final evictPort = evicts[0];

      // Helper: fill an entry
      void fillEntry(int addr, int data) {
        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(addr);
        fillPort.data.inject(data);
      }

      // Fill cache fully
      final addresses = [0x10, 0x20];
      final datas = [0x11, 0x22];
      for (var i = 0; i < 2; i++) {
        fillEntry(addresses[i], datas[i]);
        await clk.nextPosedge;
        fillPort.en.inject(0);
        // verify present
        readPort.en.inject(1);
        readPort.addr.inject(addresses[i]);
        await clk.nextPosedge;
        expect(readPort.valid.value.toInt(), equals(1));
        readPort.en.inject(0);
      }

      // Case A: Invalidation should produce eviction next cycle.
      await clk.nextPosedge;
      expect(evictPort.en.value.toInt(), equals(0));

      // Trigger invalidation (fill.valid = 0) for addresses[0],
      fillPort.en.inject(1);
      fillPort.valid.inject(0);
      fillPort.addr.inject(addresses[0]);

      // Eviction outputs are combinational in the trigger cycle; sample on the
      // negedge so external logic can capture the victim data before the
      // posedge write.
      await clk.nextNegedge;
      expect(evictPort.en.value.toInt(), equals(1));
      expect(evictPort.valid.value.toInt(), equals(1));
      expect(evictPort.addr.value.toInt(), equals(addresses[0]));
      expect(evictPort.data.value.toInt(), equals(datas[0]));

      // Keep the fill enable asserted through the posedge so the invalidate
      // commits, then clear it after the posedge.
      await clk.nextPosedge;
      fillPort.en.inject(0);
      expect(evictPort.en.value.toInt(), equals(0));

      // Re-fill the invalidated entry so the cache is full again before
      // forcing a replacement eviction.
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(addresses[0]);
      fillPort.data.inject(datas[0]);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.nextPosedge;

      // Case B: Allocation-induced eviction should appear one cycle later.
      const newAddr = 0x90;
      const newData = 0x33;

      await clk.nextPosedge;
      expect(evictPort.en.value.toInt(), equals(0));

      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(newAddr);
      fillPort.data.inject(newData);

      // Eviction should be available combinationally in the trigger cycle;
      // sample on the negedge so external logic can capture the victim data
      // before the posedge write.
      await clk.nextNegedge;
      final evAddr = evictPort.addr.value.toInt();
      final evData = evictPort.data.value.toInt();
      expect(addresses.contains(evAddr), isTrue);
      final idx = addresses.indexOf(evAddr);
      expect(evData, equals(datas[idx]));

      fillPort.en.inject(0);
      await clk.nextPosedge;

      await Simulator.endSimulation();
    });

    test('multiple fill ports committing same-cycle', () async {
      const dataWidth = 16;
      const addrWidth = 8;

      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort1 = ValidDataPortInterface(dataWidth, addrWidth);
      final fillPort2 = ValidDataPortInterface(dataWidth, addrWidth);
      final readPort = ValidDataPortInterface(dataWidth, addrWidth);

      final cache =
          FullyAssociativeCache(clk, reset, [fillPort1, fillPort2], [readPort]);

      await cache.build();
      unawaited(Simulator.run());

      // Reset
      reset.inject(1);
      fillPort1.en.inject(0);
      fillPort2.en.inject(0);
      readPort.en.inject(0);

      await clk.nextPosedge;
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;

      // Prepare two distinct addresses
      const a1 = 0x10;
      const a2 = 0x20;
      const d1 = 0xAAAA;
      const d2 = 0xBBBB;

      // Issue two fills in the same cycle to different addresses.
      fillPort1.en.inject(1);
      fillPort1.valid.inject(1);
      fillPort1.addr.inject(a1);
      fillPort1.data.inject(d1);

      fillPort2.en.inject(1);
      fillPort2.valid.inject(1);
      fillPort2.addr.inject(a2);
      fillPort2.data.inject(d2);

      // Advance: both writes should commit.
      await clk.nextPosedge;
      fillPort1.en.inject(0);
      fillPort2.en.inject(0);

      // Verify reads see committed values.
      readPort.en.inject(1);
      readPort.addr.inject(a1);
      await clk.nextPosedge;
      expect(readPort.valid.value.toInt(), equals(1));
      expect(readPort.data.value.toInt(), equals(d1));

      readPort.addr.inject(a2);
      await clk.nextPosedge;
      expect(readPort.valid.value.toInt(), equals(1));
      expect(readPort.data.value.toInt(), equals(d2));

      // cleanup
      readPort.en.inject(0);
      await clk.nextPosedge;
      await Simulator.endSimulation();
    });

    test('basic readWithInvalidate functionality', () async {
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

      Simulator.setMaxSimTime(1000);
      unawaited(Simulator.run());

      // Initialize
      fillIntf.en.inject(0);
      fillIntf.valid.inject(0);
      fillIntf.addr.inject(0);
      fillIntf.data.inject(0);
      readIntf.en.inject(0);
      readIntf.addr.inject(0);
      readIntf.readWithInvalidate.inject(0);
      reset.inject(0);
      await clk.nextPosedge;
      await clk.nextPosedge;

      reset.inject(1);
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;
      await clk.nextPosedge;

      // Fill an entry
      fillIntf.en.inject(1);
      fillIntf.valid.inject(1);
      fillIntf.addr.inject(0x10);
      fillIntf.data.inject(0xAA);
      await clk.nextPosedge;
      fillIntf.en.inject(0);
      await clk.nextPosedge;

      // Read the entry normally (should hit)
      readIntf.en.inject(1);
      readIntf.addr.inject(0x10);
      await clk.nextPosedge;
      expect(readIntf.valid.value.toInt(), equals(1),
          reason: 'Should hit on normal read');
      expect(readIntf.data.value.toInt(), equals(0xAA),
          reason: 'Should return correct data');
      readIntf.en.inject(0);
      await clk.nextPosedge;

      // Read with invalidate (should hit and then invalidate)
      readIntf.en.inject(1);
      readIntf.addr.inject(0x10);
      readIntf.readWithInvalidate.inject(1);
      await clk.nextPosedge;
      expect(readIntf.valid.value.toInt(), equals(1),
          reason: 'Should hit on readWithInvalidate');
      expect(readIntf.data.value.toInt(), equals(0xAA),
          reason: 'Should return data before invalidation');
      readIntf.en.inject(0);
      readIntf.readWithInvalidate.inject(0);
      await clk.nextPosedge;

      // Try to read again (should miss because entry was invalidated)
      readIntf.en.inject(1);
      readIntf.addr.inject(0x10);
      await clk.nextPosedge;
      expect(readIntf.valid.value.toInt(), equals(0),
          reason: 'Should miss after readWithInvalidate');
      readIntf.en.inject(0);

      await Simulator.endSimulation();
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

      Simulator.setMaxSimTime(1000);
      unawaited(Simulator.run());

      // Initialize
      fillIntf.en.inject(0);
      fillIntf.valid.inject(0);
      fillIntf.addr.inject(0);
      fillIntf.data.inject(0);
      readIntf.en.inject(0);
      readIntf.addr.inject(0);
      readIntf.readWithInvalidate.inject(0);
      reset.inject(0);
      await clk.nextPosedge;
      await clk.nextPosedge;

      reset.inject(1);
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;
      await clk.nextPosedge;

      // Fill three entries
      final addresses = [0x10, 0x20, 0x30];
      final dataValues = [0xAA, 0xBB, 0xCC];

      for (var i = 0; i < 3; i++) {
        fillIntf.en.inject(1);
        fillIntf.valid.inject(1);
        fillIntf.addr.inject(addresses[i]);
        fillIntf.data.inject(dataValues[i]);
        await clk.nextPosedge;
        fillIntf.en.inject(0);
        await clk.nextPosedge;
      }

      // Invalidate the middle entry (0x20) using readWithInvalidate
      readIntf.en.inject(1);
      readIntf.addr.inject(0x20);
      readIntf.readWithInvalidate.inject(1);
      await clk.nextPosedge;
      expect(readIntf.valid.value.toInt(), equals(1),
          reason: 'Should hit on readWithInvalidate');
      expect(readIntf.data.value.toInt(), equals(0xBB),
          reason: 'Should return correct data');
      readIntf.en.inject(0);
      readIntf.readWithInvalidate.inject(0);
      await clk.nextPosedge;

      // Verify first entry is still present
      readIntf.en.inject(1);
      readIntf.addr.inject(0x10);
      await clk.nextPosedge;
      expect(readIntf.valid.value.toInt(), equals(1),
          reason: 'First entry should still be present');
      expect(readIntf.data.value.toInt(), equals(0xAA),
          reason: 'First entry should have correct data');
      readIntf.en.inject(0);
      await clk.nextPosedge;

      // Verify middle entry is now invalid
      readIntf.en.inject(1);
      readIntf.addr.inject(0x20);
      await clk.nextPosedge;
      expect(readIntf.valid.value.toInt(), equals(0),
          reason: 'Middle entry should be invalid');
      readIntf.en.inject(0);
      await clk.nextPosedge;

      // Verify third entry is still present
      readIntf.en.inject(1);
      readIntf.addr.inject(0x30);
      await clk.nextPosedge;
      expect(readIntf.valid.value.toInt(), equals(1),
          reason: 'Third entry should still be present');
      expect(readIntf.data.value.toInt(), equals(0xCC),
          reason: 'Third entry should have correct data');
      readIntf.en.inject(0);

      await Simulator.endSimulation();
    });

    test('readWithInvalidate validation - should reject on fill ports',
        () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      // Create fill port with readWithInvalidate (should be invalid)
      final fillIntf =
          ValidDataPortInterface(8, 8, hasReadWithInvalidate: true);
      final readIntf = ValidDataPortInterface(8, 8);

      expect(
          () => FullyAssociativeCache(
                clk,
                reset,
                [fillIntf], // Fill port should not have readWithInvalidate
                [readIntf],
              ),
          throwsA(isA<ArgumentError>()));
    });

    test('readWithInvalidate with proper 8-bit addresses', () async {
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
        generateOccupancy: true,
      );

      await cache.build();

      Simulator.setMaxSimTime(1000);
      unawaited(Simulator.run());

      // Initialize properly
      fillIntf.en.inject(0);
      fillIntf.valid.inject(0);
      fillIntf.addr.inject(0);
      fillIntf.data.inject(0);
      readIntf.en.inject(0);
      readIntf.addr.inject(0);
      readIntf.readWithInvalidate.inject(0);
      reset.inject(0);
      await clk.nextPosedge;
      await clk.nextPosedge;

      reset.inject(1);
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;
      await clk.nextPosedge;

      // Wait for occupancy to stabilize
      var cycles = 0;
      while (!cache.occupancy!.value.isValid && cycles < 10) {
        await clk.nextPosedge;
        cycles++;
      }

      // === ReadWithInvalidate Test with Proper 8-bit Addresses ===

      // Fill two entries
      const addr1 = 0x10;
      const addr2 = 0x20;

      // Fill first entry
      fillIntf.en.inject(1);
      fillIntf.valid.inject(1);
      fillIntf.addr.inject(addr1);
      fillIntf.data.inject(0xAA);
      await clk.nextPosedge;
      fillIntf.en.inject(0);
      await clk.nextPosedge;

      // Fill second entry
      fillIntf.en.inject(1);
      fillIntf.valid.inject(1);
      fillIntf.addr.inject(addr2);
      fillIntf.data.inject(0xBB);
      await clk.nextPosedge;
      fillIntf.en.inject(0);
      await clk.nextPosedge;

      if (cache.occupancy!.value.isValid) {
        expect(cache.occupancy!.value.toInt(), equals(2),
            reason: 'Occupancy should be 2 after filling 2 entries');
      }

      // Test simultaneous fill + readWithInvalidate (the key test case)
      // This should fill addr2=0x30 while invalidating addr1=0x10

      // Simultaneous operations: fill new entry while invalidating existing
      // entry.
      fillIntf.en.inject(1);
      fillIntf.valid.inject(1);
      fillIntf.addr.inject(0x30); // New address
      fillIntf.data.inject(0xCC);

      readIntf.en.inject(1);
      readIntf.addr.inject(addr1); // Read existing address 0x10
      readIntf.readWithInvalidate.inject(1); // And invalidate it

      await clk.nextPosedge;

      // Stop operations
      fillIntf.en.inject(0);
      readIntf.en.inject(0);
      readIntf.readWithInvalidate.inject(0);
      await clk.nextPosedge;

      // Check results
      if (cache.occupancy!.value.isValid) {
        final occupancy = cache.occupancy!.value.toInt();
        // Should still be 2: added 0x30, but invalidated 0x10
        expect(occupancy, equals(2),
            reason: 'Occupancy should remain 2 (add one, invalidate one)');
      }

      // Verify addr1 (0x10) is now invalid
      readIntf.en.inject(1);
      readIntf.addr.inject(addr1);
      await clk.nextPosedge;
      final addr1Hit = readIntf.valid.value.toInt();
      readIntf.en.inject(0);
      await clk.nextPosedge;

      expect(addr1Hit, equals(0),
          reason: 'Invalidated address 0x10 should miss');

      // Verify addr2 (0x20) is still valid
      readIntf.en.inject(1);
      readIntf.addr.inject(addr2);
      await clk.nextPosedge;
      final addr2Hit = readIntf.valid.value.toInt();
      final addr2Data = readIntf.data.value.toInt();
      readIntf.en.inject(0);
      await clk.nextPosedge;

      expect(addr2Hit, equals(1),
          reason: 'Untouched address 0x20 should still hit');
      expect(addr2Data, equals(0xBB),
          reason: 'Should return original data 0xBB');

      // Verify new addr3 (0x30) is valid
      readIntf.en.inject(1);
      readIntf.addr.inject(0x30);
      await clk.nextPosedge;
      final addr3Hit = readIntf.valid.value.toInt();
      final addr3Data = readIntf.data.value.toInt();
      readIntf.en.inject(0);
      await clk.nextPosedge;

      expect(addr3Hit, equals(1), reason: 'New address 0x30 should hit');
      expect(addr3Data, equals(0xCC), reason: 'Should return new data 0xCC');

      await Simulator.endSimulation();
    });
  });
}
