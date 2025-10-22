// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fully_associative_cache_test.dart
// Tests for fully associative cache implementation.
//
// 2025 October 20
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  group('FullyAssociativeCache', () {
    test('basic read miss and hit', () async {
      // Narrowed widths for faster, smaller RFs in tests
      const dataWidth = 16;
      const addrWidth = 8;

      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      // Create interfaces
      final fillPort = ValidDataPortInterface(dataWidth, addrWidth);
      final readPort = ValidDataPortInterface(dataWidth, addrWidth);

      // Create cache
      final cache = FullyAssociativeCache(clk, reset, [fillPort], [readPort]);

      await cache.build();
      unawaited(Simulator.run());

      // Reset the cache
      reset.inject(1);
      fillPort.en.inject(0);
      readPort.en.inject(0);

      await clk.nextPosedge;
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;
      // Fill the cache
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x10);
      fillPort.data.inject(0xBEEF);
      readPort.en.inject(0); // Disable read
      await clk.nextPosedge;

      // Disable fill
      fillPort.en.inject(0);

      // Test read hit
      readPort.en.inject(1);
      readPort.addr.inject(0x10);
      await clk.nextPosedge;
      expect(readPort.valid.value.toInt(), equals(1),
          reason: 'Should hit after fill');
      expect(readPort.data.value.toInt(), equals(0xBEEF),
          reason: 'Should return correct data');

      // Test read miss for different address
      readPort.addr.inject(0x20);
      await clk.nextPosedge;
      expect(readPort.valid.value.toInt(), equals(0),
          reason: 'Should miss for different address');

      await Simulator.endSimulation();
    });

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

    test('cache update on hit', () async {
      const dataWidth = 16;
      const addrWidth = 8;

      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort = ValidDataPortInterface(dataWidth, addrWidth);
      final readPort = ValidDataPortInterface(dataWidth, addrWidth);

      final cache = FullyAssociativeCache(clk, reset, [fillPort], [readPort]);

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

      // Verify original data
      fillPort.en.inject(0);
      readPort.en.inject(1);
      readPort.addr.inject(0x10);
      await clk.nextPosedge;
      expect(readPort.valid.value.toInt(), equals(1));
      expect(readPort.data.value.toInt(), equals(0xBEEF));

      // Update the same entry with new data
      readPort.en.inject(0);
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x10);
      fillPort.data.inject(0xBABE);
      await clk.nextPosedge;

      // Verify updated data
      fillPort.en.inject(0);
      readPort.en.inject(1);
      readPort.addr.inject(0x10);
      await clk.nextPosedge;
      expect(readPort.valid.value.toInt(), equals(1));
      expect(readPort.data.value.toInt(), equals(0xBABE),
          reason: 'Data should be updated on hit');

      await Simulator.endSimulation();
    });

    test('multiple read ports', () async {
      const dataWidth = 16;
      const addrWidth = 8;

      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort = ValidDataPortInterface(dataWidth, addrWidth);
      final readPort1 = ValidDataPortInterface(dataWidth, addrWidth);
      final readPort2 = ValidDataPortInterface(dataWidth, addrWidth);

      final cache =
          FullyAssociativeCache(clk, reset, [fillPort], [readPort1, readPort2]);

      await cache.build();
      unawaited(Simulator.run());

      // Reset
      reset.inject(1);
      fillPort.en.inject(0);
      readPort1.en.inject(0);
      readPort2.en.inject(0);

      await clk.nextPosedge;
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;

      // Fill two entries
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x10);
      fillPort.data.inject(0xBEEF);
      await clk.nextPosedge;

      fillPort.addr.inject(0x20);
      fillPort.data.inject(0xBABE);
      await clk.nextPosedge;
      fillPort.en.inject(0);

      // Read from both ports simultaneously
      readPort1.en.inject(1);
      readPort1.addr.inject(0x10);
      readPort2.en.inject(1);
      readPort2.addr.inject(0x20);
      await clk.nextPosedge;

      expect(readPort1.valid.value.toInt(), equals(1));
      expect(readPort1.data.value.toInt(), equals(0xBEEF));
      expect(readPort2.valid.value.toInt(), equals(1));
      expect(readPort2.data.value.toInt(), equals(0xBABE));

      await Simulator.endSimulation();
    });

    test('complete fill then eviction', () async {
      const dataWidth = 16;
      const addrWidth = 8;
      const ways = 8; // Use more ways to really test the concept

      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort = ValidDataPortInterface(dataWidth, addrWidth);
      final readPort = ValidDataPortInterface(dataWidth, addrWidth);
      final evictPort = ValidDataPortInterface(dataWidth, addrWidth);

      final cache = FullyAssociativeCache(clk, reset, [fillPort], [readPort],
          ways: ways, evictions: [evictPort]);

      await cache.build();
      WaveDumper(cache, outputPath: 'eviction.vcd');
      unawaited(Simulator.run());

      // Reset
      reset.inject(1);
      fillPort.en.inject(0);
      readPort.en.inject(0);

      await clk.nextPosedge;
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;

      // Generate unique addresses and data for complete fill
      final addresses = <int>[];
      final data = <int>[];
      for (var i = 0; i < ways; i++) {
        addresses.add(0x10 + i); // Unique addresses (narrowed)
        data.add(0x10 + i); // Unique data patterns (narrowed)
      }

      // Phase 1: Complete fill test

      //  Fill cache completely - each write should be a miss initially, then
      // allocate
      for (var i = 0; i < ways; i++) {
        // Fill entry and verify immediately
        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(addresses[i]);
        fillPort.data.inject(data[i]);
        await clk.nextPosedge;

        // After filling, verify this entry can be read
        fillPort.en.inject(0);
        readPort.en.inject(1);
        readPort.addr.inject(addresses[i]);
        await clk.nextPosedge;

        expect(readPort.valid.value.toInt(), equals(1),
            reason: 'Entry $i should be readable immediately after fill');
        expect(readPort.data.value.toInt(), equals(data[i]),
            reason: 'Entry $i should return correct data');
      }

      fillPort.en.inject(0);
      // Cache is now full with $ways entries

      // Phase 2: Complete hit test - all entries should hit

      // Test that all entries are present and hit
      var hitCount = 0;
      for (var i = 0; i < ways; i++) {
        readPort.en.inject(1);
        readPort.addr.inject(addresses[i]);
        await clk.nextPosedge;

        final isHit = readPort.valid.value.toInt() == 1;
        final readData = readPort.data.value.toInt();

        if (isHit) {
          hitCount++;
          expect(readData, equals(data[i]),
              reason: 'Entry $i should return correct data on hit');
        }

        //   Read entry summary: HIT/MISS and returned data
      }

      expect(hitCount, equals(ways),
          reason: 'All $ways entries should hit when cache is full');
      // All entries hit successfully

      // Phase 3: Write-hit test - overwriting existing entries should hit

      // Test write-hits by updating existing entries with new data
      final newData = <int>[];
      for (var i = 0; i < ways; i++) {
        newData.add(0x2000 + i); // New data patterns
      }

      for (var i = 0; i < ways; i++) {
        //   Updating entry $i with new data

        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(addresses[i]); // Same address
        fillPort.data.inject(newData[i]); // New data
        await clk.nextPosedge;

        // Verify the update worked
        fillPort.en.inject(0);
        readPort.en.inject(1);
        readPort.addr.inject(addresses[i]);
        await clk.nextPosedge;

        expect(readPort.valid.value.toInt(), equals(1),
            reason: 'Entry $i should still hit after update');
        expect(readPort.data.value.toInt(), equals(newData[i]),
            reason: 'Entry $i should return updated data');
      }

      fillPort.en.inject(0);
      // All entries updated successfully (write-hits)

      // Phase 4: Eviction test - overfill the cache and verify evictions

      // Clear any enables
      fillPort.en.inject(0);
      readPort.en.inject(0);
      evictPort.en.inject(0);

      // Overfill cache by writing 'ways' entries already present plus
      // additional entries to force evictions. Track expected evicted
      // addresses/data in order.
      const extraAdds = 3;

      // We'll record any observed evictions from the eviction port and
      // assert their contents are consistent with the originally-filled
      // addresses and their latest data (from `newData`).
      final observedEvictions = <int>[];

      for (var i = 0; i < extraAdds; i++) {
        final addr = 0x90 + i; // addresses not previously used (narrowed)
        final d = 0xDEAD + i;

        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(addr);
        fillPort.data.inject(d);
        // Eviction outputs are combinational in the trigger cycle. Sample
        // on clk.negedge to avoid races with the committing posedge write
        // and record any observed evictions.
        await clk.nextNegedge;
        if (evictPort.en.value.toInt() == 1) {
          expect(evictPort.valid.value.toInt(), equals(1),
              reason: 'Eviction port should present valid data when enabled');

          final evAddr = evictPort.addr.value.toInt();
          final evData = evictPort.data.value.toInt();

          final idx = addresses.indexOf(evAddr);
          expect(idx != -1, isTrue,
              reason: 'Evicted address 0x${evAddr.toRadixString(16)} should be '
                  'one of the original addresses');
          expect(evData, equals(newData[idx]),
              reason: 'Evicted data for 0x${evAddr.toRadixString(16)} should '
                  'equal the most recent stored data');

          if (!observedEvictions.contains(evAddr)) {
            observedEvictions.add(evAddr);
          }
        }

        // Advance to commit the fill
        await clk.nextPosedge;
      }

      // Disable fill
      fillPort.en.inject(0);

      // Fail fast: require at least one eviction observed on the eviction port.
      expect(observedEvictions.isNotEmpty, isTrue,
          reason: 'Overfilling must produce at least one eviction signalled on '
              'the eviction port');

      await Simulator.endSimulation();
    });

    test('invalidation with eviction ports', () async {
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
      WaveDumper(cache, outputPath: 'invalidate.vcd');
      unawaited(Simulator.run());

      // Reset
      reset.inject(1);
      fillPort.en.inject(0);
      readPort.en.inject(0);

      await clk.nextPosedge;
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;

      // Test data
      final testAddresses = [0x10, 0x20, 0x30];
      final testData = [0xBEEF, 0xBABE, 0x5678];

      // Phase 1: Fill cache with test data.
      for (var i = 0; i < testAddresses.length; i++) {
        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(testAddresses[i]);
        fillPort.data.inject(testData[i]);
        await clk.nextPosedge;

        // Verify no eviction during fill (new allocations)
        expect(evictPort.en.value.toInt(), equals(0),
            reason: 'Should not evict during new allocation');
      }

      fillPort.en.inject(0);
      // Cache filled with ${testAddresses.length} entries

      // Phase 2: Verify all entries are present

      // Verify all entries hit
      for (var i = 0; i < testAddresses.length; i++) {
        readPort.en.inject(1);
        readPort.addr.inject(testAddresses[i]);
        await clk.nextPosedge;

        expect(readPort.valid.value.toInt(), equals(1),
            reason: 'Entry $i should be present');
        expect(readPort.data.value.toInt(), equals(testData[i]),
            reason: 'Entry $i should return correct data');
      }

      readPort.en.inject(0);
      // All entries verified present.

      // Phase 3: Test invalidation with eviction output

      // Test invalidation of each entry and verify eviction port output.
      for (var i = 0; i < testAddresses.length; i++) {
        final addr = testAddresses[i];
        final expectedData = testData[i];

        // Clear eviction port state before invalidation.
        await clk.nextPosedge;
        expect(evictPort.en.value.toInt(), equals(0),
            reason: 'Eviction port should be inactive before invalidation');

        // Invalidate the entry.
        fillPort.en.inject(1);
        fillPort.valid.inject(0); // Invalid fill = invalidate.
        fillPort.addr.inject(addr);
        await clk.nextNegedge;

        expect(evictPort.en.value.toInt(), equals(1),
            reason: 'Eviction port should be active during invalidation,');
        expect(evictPort.valid.value.toInt(), equals(1),
            reason: 'Eviction should be valid during invalidation');
        expect(evictPort.addr.value.toInt(), equals(addr),
            reason: 'Eviction port should output the invalidated address');
        expect(evictPort.data.value.toInt(), equals(expectedData),
            reason: 'Eviction port should output the invalidated data');

        await clk.nextPosedge;
        fillPort.en.inject(0);

        expect(evictPort.en.value.toInt(), equals(0),
            reason: 'Eviction port should be inactive after invalidation');

        // Verify entry is now invalid.
        readPort.en.inject(1);
        readPort.addr.inject(addr);
        await clk.nextPosedge;
        expect(readPort.valid.value.toInt(), equals(0),
            reason: 'Entry should be invalid after invalidation');
        readPort.en.inject(0);
      }

      // Phase 4: Test invalidation of non-existent entry.

      const nonExistentAddr = 0x99;

      fillPort.en.inject(1);
      fillPort.valid.inject(0);
      fillPort.addr.inject(nonExistentAddr);
      await clk.nextPosedge;

      // Should not evict anything since entry doesn't exist.
      expect(evictPort.en.value.toInt(), equals(0),
          reason: 'Should not evict when invalidating non-existent entry');

      fillPort.en.inject(0);

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

    test('read/write same-cycle precedence observation', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fills = List.generate(1, (_) => ValidDataPortInterface(8, 8));
      final reads = List.generate(1, (_) => ValidDataPortInterface(8, 8));

      final cache = FullyAssociativeCache(clk, reset, fills, reads, ways: 2);

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

      // Fill an entry with initial data.
      const addr = 0x10;
      const oldData = 0xAA;
      const newData = 0xBB;

      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(addr);
      fillPort.data.inject(oldData);
      await clk.nextPosedge;
      fillPort.en.inject(0);

      // Sanity check read returns oldData on next cycle.
      readPort.en.inject(1);
      readPort.addr.inject(addr);
      await clk.nextPosedge;
      expect(readPort.valid.value.toInt(), equals(1));
      expect(readPort.data.value.toInt(), equals(oldData));
      readPort.en.inject(0);

      // Now in the same cycle, issue a read and a write to the same address.
      readPort.en.inject(1);
      readPort.addr.inject(addr);

      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(addr);
      fillPort.data.inject(newData);

      // SAMPLE BEFORE CLOCK EDGE: combinational read should return oldData
      final preObserved = readPort.data.value.toInt();
      final preValid = readPort.valid.value.toInt();
      expect(preValid, equals(1));
      expect(preObserved, equals(oldData));

      // Advance one clock: write commits.
      await clk.nextPosedge;

      final postObserved = readPort.data.value.toInt();
      final postValid = readPort.valid.value.toInt();
      expect(postValid, equals(1));
      expect(postObserved, equals(newData));

      // Clean up and end
      fillPort.en.inject(0);
      readPort.en.inject(0);
      await clk.nextPosedge;

      await Simulator.endSimulation();
    });

    test('multiple read ports with simultaneous write', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fills = List.generate(1, (_) => ValidDataPortInterface(8, 8));
      final reads = List.generate(2, (_) => ValidDataPortInterface(8, 8));

      final cache = FullyAssociativeCache(clk, reset, fills, reads, ways: 2);

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
      final readPort1 = reads[0];
      final readPort2 = reads[1];

      const addr = 0x10;
      const oldData = 0x11;
      const newData = 0x22;

      // Fill initial value
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(addr);
      fillPort.data.inject(oldData);
      await clk.nextPosedge;
      fillPort.en.inject(0);

      // Sanity: both read ports see oldData.
      readPort1.en.inject(1);
      readPort1.addr.inject(addr);
      readPort2.en.inject(1);
      readPort2.addr.inject(addr);
      await clk.nextPosedge;
      expect(readPort1.data.value.toInt(), equals(oldData));
      expect(readPort2.data.value.toInt(), equals(oldData));
      readPort1.en.inject(0);
      readPort2.en.inject(0);

      // Now issue simultaneous reads and a write to same address in same
      // cycle. Pre-edge both reads should see oldData.
      readPort1.en.inject(1);
      readPort1.addr.inject(addr);
      readPort2.en.inject(1);
      readPort2.addr.inject(addr);

      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(addr);
      fillPort.data.inject(newData);

      // Sample pre-edge combinationally.
      await clk.nextNegedge;
      final pre1 = readPort1.data.value.toInt();
      final pre2 = readPort2.data.value.toInt();
      expect(pre1, equals(oldData));
      expect(pre2, equals(oldData));

      // Advance edge, now reads should see newData.
      await clk.nextPosedge;
      expect(readPort1.data.value.toInt(), equals(newData));
      expect(readPort2.data.value.toInt(), equals(newData));

      // cleanup
      fillPort.en.inject(0);
      readPort1.en.inject(0);
      readPort2.en.inject(0);
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
  });
}
