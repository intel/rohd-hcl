// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//

// cache_test.dart Common tests for all cache types (DirectMappedCache,
// SetAssociativeCache, FullyAssociativeCache).
//
// Test categories:
// 1. Basic functionality - cache miss/hit, multi-port reads
// 2. Simultaneous operations - concurrent reads, fills, invalidations
// 3. Eviction behavior - capacity limits, replacement policies
// 4. Invalidation methods - fill port invalidation (valid=0) vs
//    readWithInvalidate
//
// Total: 15 test types × 3 cache types = 45 tests
//
// 2025 November 4

import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  // Test configuration for each cache type
  final cacheConfigs = [
    {
      'name': 'DirectMappedCache',
      'create': (Logic clk,
              Logic reset,
              List<ValidDataPortInterface> fills,
              List<ValidDataPortInterface> reads,
              List<ValidDataPortInterface> evictions) =>
          DirectMappedCache(clk, reset, fills, reads,
              evictions: evictions.isEmpty ? null : evictions, lines: 4),
      'capacity': 4, // 4 lines, 1 way each
    },
    {
      'name': 'SetAssociativeCache',
      'create': (Logic clk,
              Logic reset,
              List<ValidDataPortInterface> fills,
              List<ValidDataPortInterface> reads,
              List<ValidDataPortInterface> evictions) =>
          SetAssociativeCache(clk, reset, fills, reads,
              evictions: evictions.isEmpty ? null : evictions,
              ways: 4,
              lines: 2),
      'capacity': 8, // 4 ways * 2 lines
    },
    {
      'name': 'FullyAssociativeCache',
      'create': (Logic clk,
              Logic reset,
              List<ValidDataPortInterface> fills,
              List<ValidDataPortInterface> reads,
              List<ValidDataPortInterface> evictions) =>
          FullyAssociativeCache(clk, reset, fills, reads,
              evictions: evictions.isEmpty ? null : evictions),
      'capacity': 4, // 4 ways
    },
  ];

  for (final config in cacheConfigs) {
    group('${config['name']} common basic tests', () {
      test('cache miss then hit', () async {
        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic();

        final fillPort = ValidDataPortInterface(8, 8);
        final readPort = ValidDataPortInterface(8, 8);

        final createCache = config['create']! as Cache Function(
            Logic,
            Logic,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>);

        final cache = createCache(clk, reset, [fillPort], [readPort], []);

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
        await clk.nextPosedge;

        // Read from address 0x10 (cache miss)
        readPort.en.inject(1);
        readPort.addr.inject(0x10);

        await clk.nextPosedge;
        expect(readPort.valid.value.toBool(), false,
            reason: 'Initial read should miss');

        readPort.en.inject(0);
        await clk.nextPosedge;

        // Fill address 0x10 with data 0xAB
        fillPort.en.inject(1);
        fillPort.addr.inject(0x10);
        fillPort.data.inject(0xAB);
        fillPort.valid.inject(1);

        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.nextPosedge;

        // Read from address 0x10 again (cache hit)
        readPort.en.inject(1);
        readPort.addr.inject(0x10);

        await clk.nextPosedge;
        expect(readPort.valid.value.toBool(), true, reason: 'Should hit');
        expect(readPort.data.value.toInt(), 0xAB, reason: 'Data should match');

        readPort.en.inject(0);

        await Simulator.endSimulation();
      });

      test('multiple read and fill ports', () async {
        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic();

        final fillPort1 = ValidDataPortInterface(8, 8);
        final fillPort2 = ValidDataPortInterface(8, 8);
        final readPort1 = ValidDataPortInterface(8, 8);
        final readPort2 = ValidDataPortInterface(8, 8);

        final createCache = config['create']! as Cache Function(
            Logic,
            Logic,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>);

        final cache = createCache(
            clk, reset, [fillPort1, fillPort2], [readPort1, readPort2], []);

        await cache.build();
        unawaited(Simulator.run());

        // Reset
        reset.inject(1);
        fillPort1.en.inject(0);
        fillPort1.valid.inject(0);
        fillPort1.addr.inject(0);
        fillPort1.data.inject(0);
        fillPort2.en.inject(0);
        fillPort2.valid.inject(0);
        fillPort2.addr.inject(0);
        fillPort2.data.inject(0);
        readPort1.en.inject(0);
        readPort1.addr.inject(0);
        readPort2.en.inject(0);
        readPort2.addr.inject(0);
        await clk.waitCycles(2);

        reset.inject(0);
        await clk.waitCycles(1);

        // Fill using both ports with non-conflicting addresses
        fillPort1.en.inject(1);
        fillPort1.valid.inject(1);
        fillPort1.addr.inject(0x10);
        fillPort1.data.inject(0xAA);

        fillPort2.en.inject(1);
        fillPort2.valid.inject(1);
        fillPort2.addr.inject(0x11);
        fillPort2.data.inject(0xBB);

        await clk.nextPosedge;
        fillPort1.en.inject(0);
        fillPort2.en.inject(0);
        await clk.waitCycles(1);

        // Read using both ports
        readPort1.en.inject(1);
        readPort1.addr.inject(0x10);
        readPort2.en.inject(1);
        readPort2.addr.inject(0x11);

        await clk.nextPosedge;

        expect(readPort1.valid.value.toBool(), isTrue,
            reason: 'Port 1 should hit');
        expect(readPort1.data.value.toInt(), 0xAA,
            reason: 'Port 1 data should match');
        expect(readPort2.valid.value.toBool(), isTrue,
            reason: 'Port 2 should hit');
        expect(readPort2.data.value.toInt(), 0xBB,
            reason: 'Port 2 data should match');

        readPort1.en.inject(0);
        readPort2.en.inject(0);

        await Simulator.endSimulation();
      });

      test('simultaneous reads from multiple ports', () async {
        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic();

        final fillPort = ValidDataPortInterface(8, 8);
        final readPort0 = ValidDataPortInterface(8, 8);
        final readPort1 = ValidDataPortInterface(8, 8);

        final createCache = config['create']! as Cache Function(
            Logic,
            Logic,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>);

        final cache =
            createCache(clk, reset, [fillPort], [readPort0, readPort1], []);

        await cache.build();
        unawaited(Simulator.run());

        // Reset
        reset.inject(1);
        fillPort.en.inject(0);
        fillPort.valid.inject(0);
        fillPort.addr.inject(0);
        fillPort.data.inject(0);
        readPort0.en.inject(0);
        readPort0.addr.inject(0);
        readPort1.en.inject(0);
        readPort1.addr.inject(0);
        await clk.waitCycles(2);

        reset.inject(0);
        await clk.waitCycles(1);

        // Fill two entries with non-conflicting addresses
        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(0x20);
        fillPort.data.inject(0xCC);
        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);

        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(0x21);
        fillPort.data.inject(0xDD);
        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);

        // Simultaneously read from both ports
        readPort0.en.inject(1);
        readPort0.addr.inject(0x20);
        readPort1.en.inject(1);
        readPort1.addr.inject(0x21);

        await clk.nextPosedge;

        // Both reads should hit
        expect(readPort0.valid.value.toBool(), isTrue,
            reason: 'Port 0 read should hit');
        expect(readPort0.data.value.toInt(), equals(0xCC));
        expect(readPort1.valid.value.toBool(), isTrue,
            reason: 'Port 1 read should hit');
        expect(readPort1.data.value.toInt(), equals(0xDD));

        readPort0.en.inject(0);
        readPort1.en.inject(0);
        await Simulator.endSimulation();
      });

      test('simultaneous read and fill to same address', () async {
        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic();

        final fillPort = ValidDataPortInterface(8, 8);
        final readPort = ValidDataPortInterface(8, 8);

        final createCache = config['create']! as Cache Function(
            Logic,
            Logic,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>);

        final cache = createCache(clk, reset, [fillPort], [readPort], []);

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

        // Pre-fill an entry
        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(0x60);
        fillPort.data.inject(0xEE);
        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);

        // Simultaneously: Read same address and update it
        readPort.en.inject(1);
        readPort.addr.inject(0x60);
        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(0x60);
        fillPort.data.inject(0xFF); // Updated data

        await clk.nextPosedge;

        // Read should see NEW data (write forwarding)
        expect(readPort.valid.value.toBool(), isTrue,
            reason: 'Read should hit');
        expect(readPort.data.value.toInt(), equals(0xFF),
            reason: 'Read should see new data after simultaneous write');

        readPort.en.inject(0);
        fillPort.en.inject(0);
        await clk.waitCycles(1);

        // Subsequent read should also see NEW data
        readPort.en.inject(1);
        readPort.addr.inject(0x60);
        await clk.nextPosedge;
        expect(readPort.valid.value.toBool(), isTrue);
        expect(readPort.data.value.toInt(), equals(0xFF),
            reason: 'Data should remain 0xFF');

        readPort.en.inject(0);
        await Simulator.endSimulation();
      });
    });

    group('${config['name']} common eviction tests', () {
      test('invalidation eviction', () async {
        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic();

        final fillPort = ValidDataPortInterface(8, 8);
        final readPort = ValidDataPortInterface(8, 8);
        final evictionPort = ValidDataPortInterface(8, 8);

        final createCache = config['create']! as Cache Function(
            Logic,
            Logic,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>);

        final cache =
            createCache(clk, reset, [fillPort], [readPort], [evictionPort]);

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
        fillPort.addr.inject(0x50);
        fillPort.data.inject(0xDD);
        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);

        // Verify entry exists
        readPort.en.inject(1);
        readPort.addr.inject(0x50);
        await clk.nextPosedge;
        expect(readPort.valid.value.toBool(), isTrue);
        expect(readPort.data.value.toInt(), equals(0xDD));
        readPort.en.inject(0);
        await clk.waitCycles(1);

        // Invalidate the entry
        fillPort.en.inject(1);
        fillPort.valid.inject(0); // Invalidation
        fillPort.addr.inject(0x50);

        Simulator.registerAction(Simulator.time + 1, () {
          expect(evictionPort.valid.value.toBool(), isTrue,
              reason: 'Invalidation should evict');
          expect(evictionPort.addr.value.toInt(), equals(0x50));
          expect(evictionPort.data.value.toInt(), equals(0xDD));
        });

        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);

        // Verify entry is now invalid
        readPort.en.inject(1);
        readPort.addr.inject(0x50);
        await clk.nextPosedge;
        expect(readPort.valid.value.toBool(), isFalse);
        readPort.en.inject(0);

        await Simulator.endSimulation();
      });

      test('no eviction on hit update', () async {
        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic();

        final fillPort = ValidDataPortInterface(8, 8);
        final readPort = ValidDataPortInterface(8, 8);
        final evictionPort = ValidDataPortInterface(8, 8);

        final createCache = config['create']! as Cache Function(
            Logic,
            Logic,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>);

        final cache =
            createCache(clk, reset, [fillPort], [readPort], [evictionPort]);

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
        fillPort.addr.inject(0x60);
        fillPort.data.inject(0xEE);
        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);

        // Update same entry (hit)
        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(0x60);
        fillPort.data.inject(0xFF);

        Simulator.registerAction(Simulator.time + 1, () {
          expect(evictionPort.valid.value.toBool(), isFalse,
              reason: 'Hit update should not evict');
        });

        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);

        // Verify data was updated
        readPort.en.inject(1);
        readPort.addr.inject(0x60);
        await clk.nextPosedge;
        expect(readPort.valid.value.toBool(), isTrue);
        expect(readPort.data.value.toInt(), equals(0xFF));
        readPort.en.inject(0);

        await Simulator.endSimulation();
      });

      test('multiple fill ports with evictions', () async {
        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic();

        final fillPort0 = ValidDataPortInterface(8, 8);
        final fillPort1 = ValidDataPortInterface(8, 8);
        final readPort = ValidDataPortInterface(8, 8);
        final evictionPort0 = ValidDataPortInterface(8, 8);
        final evictionPort1 = ValidDataPortInterface(8, 8);

        final createCache = config['create']! as Cache Function(
            Logic,
            Logic,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>);

        final cache = createCache(clk, reset, [fillPort0, fillPort1],
            [readPort], [evictionPort0, evictionPort1]);

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

        final writtenData = <int, int>{};
        final capacity = config['capacity']! as int;

        // Fill to capacity using both ports alternately
        var fillCount = 0;
        while (fillCount < capacity) {
          if (fillCount < capacity) {
            final addr = 0x10 + fillCount;
            final data = 0x80 + fillCount;
            fillPort0.en.inject(1);
            fillPort0.valid.inject(1);
            fillPort0.addr.inject(addr);
            fillPort0.data.inject(data);
            writtenData[addr] = data;
            fillCount++;
          }

          if (fillCount < capacity) {
            final addr = 0x10 + fillCount;
            final data = 0x80 + fillCount;
            fillPort1.en.inject(1);
            fillPort1.valid.inject(1);
            fillPort1.addr.inject(addr);
            fillPort1.data.inject(data);
            writtenData[addr] = data;
            fillCount++;
          }

          await clk.nextPosedge;
          fillPort0.en.inject(0);
          fillPort1.en.inject(0);
          await clk.waitCycles(1);
        }

        // Now both ports cause evictions with new addresses
        fillPort0.en.inject(1);
        fillPort0.valid.inject(1);
        fillPort0.addr.inject(0x40);
        fillPort0.data.inject(0xA0);
        writtenData[0x40] = 0xA0;

        fillPort1.en.inject(1);
        fillPort1.valid.inject(1);
        fillPort1.addr.inject(0x41);
        fillPort1.data.inject(0xA1);
        writtenData[0x41] = 0xA1;

        Simulator.registerAction(Simulator.time + 1, () {
          // At least one port should evict
          final evict0 = evictionPort0.valid.value.toBool();
          final evict1 = evictionPort1.valid.value.toBool();
          expect(evict0 || evict1, isTrue,
              reason: 'At least one port should evict when cache is full');

          // Check consistency for any evictions
          if (evict0) {
            final evictedAddr0 = evictionPort0.addr.value.toInt();
            final evictedData0 = evictionPort0.data.value.toInt();
            expect(writtenData.containsKey(evictedAddr0), isTrue,
                reason: 'Port 0 evicted address should be known');
            expect(evictedData0, equals(writtenData[evictedAddr0]),
                reason: 'Port 0 evicted data should match');
          }

          if (evict1) {
            final evictedAddr1 = evictionPort1.addr.value.toInt();
            final evictedData1 = evictionPort1.data.value.toInt();
            expect(writtenData.containsKey(evictedAddr1), isTrue,
                reason: 'Port 1 evicted address should be known');
            expect(evictedData1, equals(writtenData[evictedAddr1]),
                reason: 'Port 1 evicted data should match');
          }
        });

        await clk.nextPosedge;
        fillPort0.en.inject(0);
        fillPort1.en.inject(0);

        await Simulator.endSimulation();
      });

      test('eviction consistency stress test', () async {
        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic();

        final fillPort = ValidDataPortInterface(8, 8);
        final readPort = ValidDataPortInterface(8, 8);
        final evictionPort = ValidDataPortInterface(8, 8);

        final createCache = config['create']! as Cache Function(
            Logic,
            Logic,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>);

        final cache =
            createCache(clk, reset, [fillPort], [readPort], [evictionPort]);

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

        final writtenData = <int, int>{};
        var evictionCount = 0;

        // Perform many fills with pseudo-random addresses
        for (var i = 0; i < 50; i++) {
          final addr = (i * 11) % 256;
          final data = (i * 17) % 256;

          fillPort.en.inject(1);
          fillPort.valid.inject(1);
          fillPort.addr.inject(addr);
          fillPort.data.inject(data);
          writtenData[addr] = data;

          Simulator.registerAction(Simulator.time + 1, () {
            if (evictionPort.valid.value.toBool()) {
              evictionCount++;
              final evictedAddr = evictionPort.addr.value.toInt();
              final evictedData = evictionPort.data.value.toInt();

              // Verify evicted data is consistent
              expect(writtenData.containsKey(evictedAddr), isTrue,
                  reason: 'Evicted address $evictedAddr should be known');
              expect(evictedData, equals(writtenData[evictedAddr]),
                  reason: 'Evicted data for addr $evictedAddr should match');
            }
          });

          await clk.nextPosedge;
          fillPort.en.inject(0);
          await clk.waitCycles(1);
        }

        // Should have had some evictions
        expect(evictionCount, greaterThan(0),
            reason: 'Should have evictions during stress test');

        await Simulator.endSimulation();
      });

      test('eviction on capacity full', () async {
        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic();

        final fillPort = ValidDataPortInterface(8, 8);
        final readPort = ValidDataPortInterface(8, 8);
        final evictionPort = ValidDataPortInterface(8, 8);

        final createCache = config['create']! as Cache Function(
            Logic,
            Logic,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>);

        final cache =
            createCache(clk, reset, [fillPort], [readPort], [evictionPort]);

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

        final writtenData = <int, int>{};
        final capacity = config['capacity']! as int;

        // Fill to capacity with unique sequential addresses
        for (var i = 0; i < capacity; i++) {
          final addr = 0x10 + i;
          final data = 0xA0 + i;
          fillPort.en.inject(1);
          fillPort.valid.inject(1);
          fillPort.addr.inject(addr);
          fillPort.data.inject(data);
          writtenData[addr] = data;

          Simulator.registerAction(Simulator.time + 1, () {
            expect(evictionPort.valid.value.toBool(), isFalse,
                reason: 'Initial fills should not evict');
          });

          await clk.nextPosedge;
          fillPort.en.inject(0);
          await clk.waitCycles(1);
        }

        // Next fill should evict (capacity + 1)
        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(0x50);
        fillPort.data.inject(0xB0);
        writtenData[0x50] = 0xB0;

        var evictedAddr = 0;
        Simulator.registerAction(Simulator.time + 1, () {
          expect(evictionPort.valid.value.toBool(), isTrue,
              reason: 'Should evict when capacity full');
          evictedAddr = evictionPort.addr.value.toInt();
          final evictedData = evictionPort.data.value.toInt();

          expect(writtenData.containsKey(evictedAddr), isTrue,
              reason: 'Evicted address should be one we wrote');
          expect(evictedData, equals(writtenData[evictedAddr]),
              reason: 'Evicted data should match');
        });

        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);

        // Verify evicted entry is gone
        readPort.en.inject(1);
        readPort.addr.inject(evictedAddr);
        await clk.nextPosedge;
        expect(readPort.valid.value.toBool(), isFalse,
            reason: 'Evicted entry should not be present');
        readPort.en.inject(0);

        await Simulator.endSimulation();
      });

      test('sequential evictions', () async {
        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic();

        final fillPort = ValidDataPortInterface(8, 8);
        final readPort = ValidDataPortInterface(8, 8);
        final evictionPort = ValidDataPortInterface(8, 8);

        final createCache = config['create']! as Cache Function(
            Logic,
            Logic,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>);

        final cache =
            createCache(clk, reset, [fillPort], [readPort], [evictionPort]);

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

        final writtenData = <int, int>{};
        final capacity = config['capacity']! as int;

        // Fill to capacity
        for (var i = 0; i < capacity; i++) {
          final addr = 0x70 + i;
          final data = 0xC0 + i;
          fillPort.en.inject(1);
          fillPort.valid.inject(1);
          fillPort.addr.inject(addr);
          fillPort.data.inject(data);
          writtenData[addr] = data;
          await clk.nextPosedge;
          fillPort.en.inject(0);
          await clk.waitCycles(1);
        }

        // Cause several sequential evictions
        for (var i = 0; i < 5; i++) {
          final addr = 0x80 + i;
          final data = 0xD0 + i;
          fillPort.en.inject(1);
          fillPort.valid.inject(1);
          fillPort.addr.inject(addr);
          fillPort.data.inject(data);
          writtenData[addr] = data;

          Simulator.registerAction(Simulator.time + 1, () {
            expect(evictionPort.valid.value.toBool(), isTrue,
                reason: 'Should evict when cache full');
            final evictedAddr = evictionPort.addr.value.toInt();
            final evictedData = evictionPort.data.value.toInt();

            expect(writtenData.containsKey(evictedAddr), isTrue);
            expect(evictedData, equals(writtenData[evictedAddr]));
          });

          await clk.nextPosedge;
          fillPort.en.inject(0);
          await clk.waitCycles(1);
        }

        await Simulator.endSimulation();
      });

      test('simultaneous read and fill to same address (update)', () async {
        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic();

        final fillPort = ValidDataPortInterface(8, 8);
        final readPort = ValidDataPortInterface(8, 8);

        final createCache = config['create']! as Cache Function(
            Logic,
            Logic,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>);

        final cache = createCache(
            clk, reset, [fillPort], [readPort], <ValidDataPortInterface>[]);

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

        // Pre-fill an entry
        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(0x10);
        fillPort.data.inject(0xAA);
        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);

        // Simultaneously: Read same address (hit) and fill same address
        // (hit, update).
        readPort.en.inject(1);
        readPort.addr.inject(0x10);
        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(0x10);
        fillPort.data.inject(0xCC); // Updated data

        await clk.nextPosedge;

        // Read should see NEW data (RegisterFile write happens on clock edge,
        // but the updated storage is available combinationally to read logic).
        expect(readPort.valid.value.toBool(), isTrue,
            reason: 'Read should hit');
        expect(readPort.data.value.toInt(), equals(0xCC),
            reason: 'Read should see new data after simultaneous write');

        readPort.en.inject(0);
        fillPort.en.inject(0);
        await clk.waitCycles(1);

        // Subsequent read should also see NEW data
        readPort.en.inject(1);
        readPort.addr.inject(0x10);
        await clk.nextPosedge;
        expect(readPort.valid.value.toBool(), isTrue);
        expect(readPort.data.value.toInt(), equals(0xCC),
            reason: 'Data should remain 0xCC');

        readPort.en.inject(0);
        await Simulator.endSimulation();
      });

      test('simultaneous read and invalidation', () async {
        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic();

        final fillPort = ValidDataPortInterface(8, 8);
        final readPort = ValidDataPortInterface(8, 8);
        final evictionPort = ValidDataPortInterface(8, 8);

        final createCache = config['create']! as Cache Function(
            Logic,
            Logic,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>);

        final cache =
            createCache(clk, reset, [fillPort], [readPort], [evictionPort]);

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

        // Simultaneously: Read entry and invalidate it
        readPort.en.inject(1);
        readPort.addr.inject(0x10);
        fillPort.en.inject(1);
        fillPort.valid.inject(0); // Invalidation
        fillPort.addr.inject(0x10);

        // Check eviction
        Simulator.registerAction(Simulator.time + 1, () {
          expect(evictionPort.valid.value.toBool(), isTrue,
              reason: 'Invalidation should evict');
          expect(evictionPort.addr.value.toInt(), equals(0x10));
          expect(evictionPort.data.value.toInt(), equals(0xAA));
        });

        await clk.nextPosedge;

        // Read will MISS because invalidation clears the valid bit on the same
        // cycle, and the read's valid check happens combinationally with the
        // updated (cleared) valid bit.
        expect(readPort.valid.value.toBool(), isFalse,
            reason: 'Read misses because invalidation happens simultaneously');

        readPort.en.inject(0);
        fillPort.en.inject(0);
        await clk.waitCycles(1);

        // Subsequent read should also miss
        readPort.en.inject(1);
        readPort.addr.inject(0x10);
        await clk.nextPosedge;
        expect(readPort.valid.value.toBool(), isFalse,
            reason: 'Entry should remain invalidated');
        readPort.en.inject(0);

        await Simulator.endSimulation();
      });

      test('simultaneous operations with readWithInvalidate', () async {
        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic();

        final fillPort = ValidDataPortInterface(8, 8);
        final readPort =
            ValidDataPortInterface(8, 8, hasReadWithInvalidate: true);
        final evictionPort = ValidDataPortInterface(8, 8);

        final createCache = config['create']! as Cache Function(
            Logic,
            Logic,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>);

        final cache =
            createCache(clk, reset, [fillPort], [readPort], [evictionPort]);

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
        readPort.readWithInvalidate.inject(0);
        await clk.waitCycles(2);

        reset.inject(0);
        await clk.waitCycles(1);

        // Pre-fill two entries
        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(0x10);
        fillPort.data.inject(0xAA);
        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);

        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(0x11);
        fillPort.data.inject(0xBB);
        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);

        // Simultaneously: readWithInvalidate one entry and fill another
        readPort.en.inject(1);
        readPort.addr.inject(0x10);
        readPort.readWithInvalidate.inject(1);

        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(0x12);
        fillPort.data.inject(0xCC);

        await clk.nextPosedge;

        // Read should hit
        expect(readPort.valid.value.toBool(), isTrue,
            reason: 'ReadWithInvalidate should hit');
        expect(readPort.data.value.toInt(), equals(0xAA));

        readPort.en.inject(0);
        readPort.readWithInvalidate.inject(0);
        fillPort.en.inject(0);
        await clk.waitCycles(2); // Wait for readWithInvalidate to take effect

        // Now entry at 0x10 should be invalid
        readPort.en.inject(1);
        readPort.addr.inject(0x10);
        await clk.nextPosedge;
        expect(readPort.valid.value.toBool(), isFalse,
            reason: 'Entry should be invalidated by readWithInvalidate');
        readPort.en.inject(0);

        await Simulator.endSimulation();
      });

      test('fill port invalidation (valid=0)', () async {
        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic();

        final fillPort = ValidDataPortInterface(8, 8);
        final readPort = ValidDataPortInterface(8, 8);

        final createCache = config['create']! as Cache Function(
            Logic,
            Logic,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>);

        final cache = createCache(clk, reset, [fillPort], [readPort], []);

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

        // Fill entry at address 0x42 with data 0xAB
        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(0x42);
        fillPort.data.inject(0xAB);
        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);

        // Verify entry exists
        readPort.en.inject(1);
        readPort.addr.inject(0x42);
        await clk.nextPosedge;
        expect(readPort.valid.value.toBool(), isTrue,
            reason: 'Entry should exist after fill');
        expect(readPort.data.value.toInt(), equals(0xAB),
            reason: 'Data should match');

        readPort.en.inject(0);
        await clk.waitCycles(1);

        // Invalidate using fill port with valid=0
        fillPort.en.inject(1);
        fillPort.valid.inject(0); // Invalid fill = invalidate
        fillPort.addr.inject(0x42);
        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);

        // Verify entry is now invalid
        readPort.en.inject(1);
        readPort.addr.inject(0x42);
        await clk.nextPosedge;
        expect(readPort.valid.value.toBool(), isFalse,
            reason: 'Entry should be invalid after fill port invalidation');

        readPort.en.inject(0);
        await Simulator.endSimulation();
      });

      test('readWithInvalidate', () async {
        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic();

        final fillPort = ValidDataPortInterface(8, 8);
        final readPort =
            ValidDataPortInterface(8, 8, hasReadWithInvalidate: true);

        final createCache = config['create']! as Cache Function(
            Logic,
            Logic,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>,
            List<ValidDataPortInterface>);

        final cache = createCache(clk, reset, [fillPort], [readPort], []);

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
        readPort.readWithInvalidate.inject(0);
        await clk.waitCycles(2);

        reset.inject(0);
        await clk.waitCycles(1);

        // Fill entry at address 0x42 with data 0xAB
        fillPort.en.inject(1);
        fillPort.valid.inject(1);
        fillPort.addr.inject(0x42);
        fillPort.data.inject(0xAB);
        await clk.nextPosedge;
        fillPort.en.inject(0);
        await clk.waitCycles(1);

        // Verify entry exists with normal read
        readPort.en.inject(1);
        readPort.addr.inject(0x42);
        readPort.readWithInvalidate.inject(0);
        await clk.nextPosedge;
        expect(readPort.valid.value.toBool(), isTrue,
            reason: 'Entry should exist after fill');
        expect(readPort.data.value.toInt(), equals(0xAB),
            reason: 'Data should match');

        readPort.en.inject(0);
        await clk.waitCycles(1);

        // Invalidate using readWithInvalidate
        readPort.en.inject(1);
        readPort.addr.inject(0x42);
        readPort.readWithInvalidate.inject(1);
        await clk.nextPosedge;
        expect(readPort.valid.value.toBool(), isTrue,
            reason: 'ReadWithInvalidate should hit and return data');
        expect(readPort.data.value.toInt(), equals(0xAB),
            reason: 'Data should match on readWithInvalidate');

        readPort.en.inject(0);
        readPort.readWithInvalidate.inject(0);
        await clk.waitCycles(2); // Wait for invalidation to take effect

        // Verify entry is now invalid
        readPort.en.inject(1);
        readPort.addr.inject(0x42);
        await clk.nextPosedge;
        expect(readPort.valid.value.toBool(), isFalse,
            reason: 'Entry should be invalid after readWithInvalidate');

        readPort.en.inject(0);
        await Simulator.endSimulation();
      });
    });
  }
}
