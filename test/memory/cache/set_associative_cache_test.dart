// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// set_associative_cache_test.dart
// All tests for SetAssociativeCache component.
//
// Test Groups:
// 1. Basic functionality - instantiation, smoke tests, pathology, invalidation
// 2. Narrow tests - specific read/write patterns
// 3. Eviction tests - way conflicts, simultaneous evictions
//
// Related test files:
// - cache_test.dart - Common tests for all caches (10 tests for
//   SetAssociativeCache)
//   * 4 basic functionality tests (miss/hit, multi-port, simultaneous)
//   * 6 eviction tests (invalidation, hit update, stress, capacity, sequential)
//
// Total: 4 (basic) + 2 (narrow) + 2 (eviction) + 10 (common) = 18 tests
//
// 2025 September 10
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

import 'cache_test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test(
      'SetAssociativeCache: RWI with simultaneous fills on different addresses',
      () async {
    final clk = SimpleClockGenerator(2).clk;
    final reset = Logic();

    const ways = 4;

    final fillPorts = List.generate(2, (_) => ValidDataPortInterface(32, 32));
    final fills = fillPorts.map(FillEvictInterface.new).toList();
    final readPorts = List.generate(
        2, (_) => ValidDataPortInterface(32, 32, hasReadWithInvalidate: true));

    final cache = SetAssociativeCache(clk, reset, fills, readPorts, ways: ways);

    await cache.build();
    unawaited(Simulator.run());

    // Reset and initialize all signals
    reset.inject(0);
    for (final fillPort in fillPorts) {
      fillPort.en.inject(0);
      fillPort.valid.inject(0);
      fillPort.addr.inject(0);
      fillPort.data.inject(0);
    }
    for (final readPort in readPorts) {
      readPort.en.inject(0);
      readPort.readWithInvalidate.inject(0);
      readPort.addr.inject(0);
    }
    await clk.waitCycles(2);
    reset.inject(1);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextPosedge;

    // Log suppressed: fill address 0x100 with data 0x10100
    fillPorts[0].addr.inject(0x100);
    fillPorts[0].data.inject(0x10100);
    fillPorts[0].valid.inject(1);
    fillPorts[0].en.inject(1);
    await clk.nextPosedge;
    fillPorts[0].en.inject(0);
    await clk.nextPosedge;

    // Log suppressed: verify 0x100 is in cache
    readPorts[0].addr.inject(0x100);
    readPorts[0].en.inject(1);
    await clk.nextPosedge;
    await clk.nextNegedge;
    var hit = readPorts[0].valid.value.toInt();
    var data = readPorts[0].data.value.toInt();
    expect(hit, 1, reason: 'Should hit after fill (hit=$hit)');
    expect(data, 0x10100,
        reason: 'Should return data=0x${0x10100.toRadixString(16)} '
            '(data=0x${data.toRadixString(16)})');
    readPorts[0].en.inject(0);
    await clk.nextPosedge;

    // Log suppressed: RWI simultaneously with fills description
    // Use addresses that map to different sets to avoid conflicts
    // 0x200 and 0x300 should map to different sets than 0x100
    fillPorts[0].addr.inject(0x200);
    fillPorts[0].data.inject(0x10200);
    fillPorts[0].valid.inject(1);
    fillPorts[0].en.inject(1);

    fillPorts[1].addr.inject(0x300);
    fillPorts[1].data.inject(0x10300);
    fillPorts[1].valid.inject(1);
    fillPorts[1].en.inject(1);

    readPorts[0].addr.inject(0x100);
    readPorts[0].readWithInvalidate.inject(1);
    readPorts[0].en.inject(1);

    await clk.nextPosedge;
    await clk.nextNegedge;

    hit = readPorts[0].valid.value.toInt();
    data = readPorts[0].data.value.toInt();
    expect(hit, 1,
        reason:
            'RWI should hit on 0x100 despite simultaneous fills (hit=$hit)');
    expect(data, 0x10100,
        reason: 'RWI should return correct data 0x${0x10100.toRadixString(16)} '
            '(data=0x${data.toRadixString(16)})');

    for (final fillPort in fillPorts) {
      fillPort.en.inject(0);
    }
    readPorts[0].en.inject(0);
    readPorts[0].readWithInvalidate.inject(0);
    await clk.nextPosedge;

    await Simulator.endSimulation();
  });

  group('SetAssociativeCache basic tests', () {
    test('instantiate cache', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();
      final cp = CachePorts.fresh(8, 16, attachEvictionsToFills: true);
      final cache = cp.createCache(clk, reset, setAssociativeFactory(lines: 8));
      await cache.build();
    });

    test('Cache smoke test', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();
      final cp = CachePorts.fresh(8, 16);
      final cache = cp.createCache(clk, reset, setAssociativeFactory(lines: 8));
      final fillPort = cp.fillPorts[0];
      final rdPort = cp.readPorts[0];

      await cache.build();
      unawaited(Simulator.run());
      await cp.resetCache(clk, reset);

      // write 0x41 to address 1111
      fillPort.en.inject(1);
      fillPort.addr.inject(1111);
      fillPort.data.inject(0x41);
      fillPort.valid.inject(1);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.nextPosedge;
      // write 0x42 to address 1111
      fillPort.en.inject(1);
      fillPort.addr.inject(1111);
      fillPort.data.inject(0x42);
      fillPort.valid.inject(1);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      // read it back
      rdPort.en.inject(1);
      rdPort.addr.inject(1111);
      await clk.nextPosedge;
      expect(rdPort.data.value, LogicValue.ofInt(0x42, 8));
      expect(rdPort.valid.value, LogicValue.one);
      rdPort.en.inject(0);
      await clk.waitCycles(2);

      await Simulator.endSimulation();
    });

    test('Cache pathology double-write, double-read same location', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();
      final cp = CachePorts.fresh(8, 16);
      final cache =
          cp.createCache(clk, reset, setAssociativeFactory(lines: 16));

      final fillPort = cp.fillPorts[0];
      final fillPort2 = cp.fillPorts[1];
      final rdPort = cp.readPorts[0];
      final rdPort2 = cp.readPorts[1];

      await cache.build();
      unawaited(Simulator.run());
      await cp.resetCache(clk, reset);

      // write 0x41 to address 1111
      fillPort.en.inject(1);
      fillPort.addr.inject(1111);
      fillPort.data.inject(0x41);
      fillPort.valid.inject(1);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.nextPosedge;
      fillPort.en.inject(1);
      fillPort.addr.inject(1111);
      fillPort.data.inject(0x44);
      fillPort.valid.inject(1);
      fillPort2.en.inject(1);
      fillPort2.addr.inject(1111);
      fillPort2.data.inject(0x42);
      fillPort2.valid.inject(1);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      fillPort2.en.inject(0);
      // read it back
      rdPort.en.inject(1);
      rdPort.addr.inject(1111);
      rdPort2.en.inject(1);
      rdPort2.addr.inject(1111);
      await clk.nextPosedge;
      expect(rdPort.data.value, LogicValue.ofInt(0x42, 8));
      expect(rdPort.valid.value, LogicValue.one);
      expect(rdPort2.data.value, LogicValue.ofInt(0x42, 8));
      expect(rdPort2.valid.value, LogicValue.one);
      await clk.waitCycles(2);

      await Simulator.endSimulation();
    });

    test('Cache invalidate singleton test', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();
      final cp = CachePorts.fresh(8, 16);
      final cache =
          cp.createCache(clk, reset, setAssociativeFactory(lines: 16));

      final fillPort = cp.fillPorts[0];
      final rdPort = cp.readPorts[0];

      await cache.build();
      unawaited(Simulator.run());
      await cp.resetCache(clk, reset);

      // write 0x42 to address 1111
      fillPort.en.inject(1);
      fillPort.addr.inject(1111);
      fillPort.data.inject(0x42);
      fillPort.valid.inject(1);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      fillPort.valid.inject(0);
      await clk.waitCycles(2);

      // read it back
      rdPort.en.inject(1);
      rdPort.addr.inject(1111);
      await clk.nextPosedge;
      expect(rdPort.data.value, LogicValue.ofInt(0x42, 8));
      expect(rdPort.valid.value, LogicValue.one);
      rdPort.en.inject(0);
      await clk.nextPosedge;
      fillPort.en.inject(1);
      fillPort.addr.inject(1111);
      fillPort.data.inject(0x42);
      // Invalidate by writing with valid low.
      fillPort.valid.inject(0);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.nextPosedge;
      rdPort.en.inject(1);
      rdPort.addr.inject(1111);
      await clk.nextPosedge;
      rdPort.en.inject(0);

      expect(rdPort.data.value, LogicValue.ofInt(0, 8));
      expect(rdPort.valid.value, LogicValue.zero);
      await clk.waitCycles(2);

      await Simulator.endSimulation();
    });

    test('fill allocation sets valid bit', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();
      final cp = CachePorts.fresh(8, 16);
      final cache = cp.createCache(clk, reset, setAssociativeFactory(lines: 8));
      final fillPort = cp.fillPorts[0];
      final rdPort = cp.readPorts[0];

      await cache.build();
      unawaited(Simulator.run());
      await cp.resetCache(clk, reset);

      // Fill (miss) should allocate and set valid bit
      fillPort.en.inject(1);
      fillPort.addr.inject(0x7); // some addr
      fillPort.data.inject(0x55);
      fillPort.valid.inject(1);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.nextPosedge;

      // Read it back
      rdPort.en.inject(1);
      rdPort.addr.inject(0x7);
      await clk.nextPosedge;
      expect(rdPort.valid.value, LogicValue.one);
      expect(rdPort.data.value, LogicValue.ofInt(0x55, 8));
      rdPort.en.inject(0);
      await clk.waitCycles(2);

      await Simulator.endSimulation();
    });

    test('fill invalidation clears valid bit', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();
      final cp = CachePorts.fresh(8, 16);
      final cache = cp.createCache(clk, reset, setAssociativeFactory(lines: 8));
      final fillPort = cp.fillPorts[0];
      final rdPort = cp.readPorts[0];

      await cache.build();
      unawaited(Simulator.run());
      await cp.resetCache(clk, reset);

      // Fill to set valid
      fillPort.en.inject(1);
      fillPort.addr.inject(0x3);
      fillPort.data.inject(0x99);
      fillPort.valid.inject(1);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.waitCycles(2);

      // Invalidate by writing with valid==0
      fillPort.en.inject(1);
      fillPort.addr.inject(0x3);
      fillPort.data.inject(0x99);
      fillPort.valid.inject(0);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.nextPosedge;

      // Read should be invalid
      rdPort.en.inject(1);
      rdPort.addr.inject(0x3);
      await clk.nextPosedge;
      expect(rdPort.valid.value, LogicValue.zero);
      rdPort.en.inject(0);
      await clk.waitCycles(2);

      await Simulator.endSimulation();
    });
  });

  group('Cache narrow tests', () {
    const dataWidth = 4;
    const addrWidth = 4;
    const ways = 4;
    final lines = BigInt.two.pow(addrWidth).toInt() ~/ ways;
    final lineAddrWith = log2Ceil(lines);
    final tagWidth = addrWidth - lineAddrWith;

    test('Cache singleton 2 writes then reads test', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();
      final cp = CachePorts.fresh(dataWidth, addrWidth);
      final cache =
          cp.createCache(clk, reset, setAssociativeFactory(lines: 16));

      final fillPort = cp.fillPorts[0];
      final rdPort = cp.readPorts[0];

      await cache.build();
      unawaited(Simulator.run());

      await cp.resetCache(clk, reset);

      // write data to address addr
      const first = 0x2;
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(first);
      fillPort.data.inject(9);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.waitCycles(3);

      const second = 0x4;
      fillPort.addr.inject(second);
      fillPort.data.inject(7);
      fillPort.en.inject(1);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.nextPosedge;
      // read it back
      rdPort.en.inject(1);
      rdPort.addr.inject(first);
      await clk.nextPosedge;
      rdPort.en.inject(0);

      expect(rdPort.data.value.toInt(), 9);
      expect(rdPort.valid.value, LogicValue.one);
      rdPort.addr.inject(second);
      await clk.nextPosedge;
      rdPort.en.inject(1);

      await clk.nextPosedge;
      expect(rdPort.data.value.toInt(), 7);
      expect(rdPort.valid.value, LogicValue.one);
      rdPort.en.inject(0);
      await clk.waitCycles(2);

      await Simulator.endSimulation();
    });

    test('Cache writes then reads test', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();
      final cp = CachePorts.fresh(dataWidth, addrWidth);
      final cache = SetAssociativeCache(
        clk,
        reset,
        // Wrap fill ports into composite FillEvictInterface expected by API.
        List.generate(
            cp.fillPorts.length, (i) => FillEvictInterface(cp.fillPorts[i])),
        cp.readPorts,
      );
      await cache.build();

      final fillPort = cp.fillPorts[0];
      final rdPort = cp.readPorts[0];
      // #writes>#ways to the same line can result in eviction. So a test is to
      // write #ways writes to each line to fill it. Then perform reads to
      // verify all are there. This verifies we are not evicting anything less
      // than #ways old.

      // Generate a set of address/data pairs to write and read back.
      final testData = <(LogicValue, LogicValue)>[];
      var data = 0;
      for (var line = 0; line < lines; line++) {
        final lv = LogicValue.ofInt(line, lineAddrWith);
        for (var way = 0; way < ways; way++) {
          final tag = LogicValue.ofInt(way + 1, tagWidth);
          final addr = [tag, lv].swizzle();
          testData.add((addr, LogicValue.ofInt(data, dataWidth)));
          data++;
        }
      }

      unawaited(Simulator.run());

      await cp.resetCache(clk, reset);

      await clk.nextPosedge;
      // Fill each line of the cache.
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      for (var i = 0; i < testData.length; i++) {
        final (addr, data) = testData[i];
        fillPort.addr.inject(addr);
        fillPort.data.inject(data);
        await clk.nextPosedge;
      }
      fillPort.en.inject(0);
      await clk.nextPosedge;
      // Read them all back.
      await clk.nextPosedge;
      rdPort.en.inject(1);
      for (var i = 0; i < testData.length; i++) {
        final (addr, data) = testData[i];
        rdPort.addr.inject(addr);
        await clk.nextPosedge;
        expect(rdPort.valid.value, LogicValue.one,
            reason: 'read valid for addr $addr');
        expect(rdPort.data.value, data,
            reason: 'should read $data for addr $addr');
      }
      rdPort.en.inject(0);
      await clk.waitCycles(2);

      await Simulator.endSimulation();
    });
  });

  group('SetAssociativeCache eviction tests', () {
    test('eviction on way conflict', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();
      final cp = CachePorts.fresh(8, 8, attachEvictionsToFills: true);
      final cache =
          cp.createCache(clk, reset, setAssociativeFactory(ways: 2, lines: 4));

      final fillPort = cp.fillPorts[0];
      final rdPort = cp.readPorts[0];
      final evictionPort = cp.evictionPorts[0];

      await cache.build();
      unawaited(Simulator.run());

      await cp.resetCache(clk, reset);

      // Track what we write: map[addr] = data
      final writtenData = <int, int>{};

      // Fill all ways of line 0 (addresses with bottom 2 bits = 0)
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x00); // Line 0, way 0 or 1
      fillPort.data.inject(0xAA);
      writtenData[0x00] = 0xAA;

      Simulator.registerAction(Simulator.time + 1, () {
        expect(evictionPort.valid.value.toBool(), isFalse,
            reason: 'First fill should not evict');
      });

      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.waitCycles(1);

      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x04); // Line 0, different tag
      fillPort.data.inject(0xBB);
      writtenData[0x04] = 0xBB;

      Simulator.registerAction(Simulator.time + 1, () {
        expect(evictionPort.valid.value.toBool(), isFalse,
            reason: 'Second fill should not evict (goes to way 1)');
      });

      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.waitCycles(1);

      // Third fill to same line - should evict one of the previous entries
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x08); // Line 0, yet another tag
      fillPort.data.inject(0xCC);
      writtenData[0x08] = 0xCC;

      var evictedAddr = 0;
      Simulator.registerAction(Simulator.time + 1, () {
        expect(evictionPort.valid.value.toBool(), isTrue,
            reason: 'Third fill should evict (all ways full)');
        evictedAddr = evictionPort.addr.value.toInt();
        final evictedData = evictionPort.data.value.toInt();

        // Verify evicted data matches what we wrote to that address
        expect(writtenData.containsKey(evictedAddr), isTrue,
            reason: 'Evicted address should be one we wrote');
        expect(evictedData, equals(writtenData[evictedAddr]),
            reason: 'Evicted data should match written data for that address');
      });

      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.waitCycles(1);

      // Verify evicted entry is gone
      rdPort.en.inject(1);
      rdPort.addr.inject(evictedAddr);
      await clk.nextPosedge;
      expect(rdPort.valid.value.toBool(), isFalse,
          reason: 'Evicted entry should not be present');
      rdPort.en.inject(0);

      await Simulator.endSimulation();
    });

    test('simultaneous evictions on multiple fill ports', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();
      final cp = CachePorts.fresh(8, 8, attachEvictionsToFills: true);
      final evictionPort0 = cp.evictionPorts[0];
      final evictionPort1 = cp.evictionPorts[1];

      final cache = cp.createCache(clk, reset, setAssociativeFactory(ways: 2));

      final fillPort = cp.fillPorts[0];
      final fillPort2 = cp.fillPorts[1];

      await cache.build();
      unawaited(Simulator.run());

      // Reset using CachePorts instance helper to clear ports and pulse reset.
      await cp.resetCache(clk, reset);

      final writtenData = <int, int>{};

      // Fill all ways of line 0 using both ports
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x00);
      fillPort.data.inject(0xA0);
      writtenData[0x00] = 0xA0;

      fillPort2.en.inject(1);
      fillPort2.valid.inject(1);
      fillPort2.addr.inject(0x02);
      fillPort2.data.inject(0xA1);
      writtenData[0x02] = 0xA1;

      await clk.nextPosedge;
      fillPort.en.inject(0);
      fillPort2.en.inject(0);
      await clk.waitCycles(1);

      // Now cause evictions on both ports simultaneously
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x04); // Line 0
      fillPort.data.inject(0xB0);
      writtenData[0x04] = 0xB0;

      fillPort2.en.inject(1);
      fillPort2.valid.inject(1);
      fillPort2.addr.inject(0x03); // Line 1
      fillPort2.data.inject(0xB1);
      writtenData[0x03] = 0xB1;

      Simulator.registerAction(Simulator.time + 1, () {
        // Port 0 should evict from line 0
        expect(evictionPort0.valid.value.toBool(), isTrue,
            reason: 'Port 0 should evict');
        final evictedAddr0 = evictionPort0.addr.value.toInt();
        final evictedData0 = evictionPort0.data.value.toInt();
        expect(writtenData.containsKey(evictedAddr0), isTrue);
        expect(evictedData0, equals(writtenData[evictedAddr0]));

        // Port 1 might not evict if line 1 has space
        // But if it does, check consistency
        if (evictionPort1.valid.value.toBool()) {
          final evictedAddr1 = evictionPort1.addr.value.toInt();
          final evictedData1 = evictionPort1.data.value.toInt();
          expect(writtenData.containsKey(evictedAddr1), isTrue);
          expect(evictedData1, equals(writtenData[evictedAddr1]));
        }
      });

      await clk.nextPosedge;
      fillPort.en.inject(0);
      fillPort2.en.inject(0);

      await Simulator.endSimulation();
    });
  });
}
