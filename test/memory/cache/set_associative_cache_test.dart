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
// 2025 September 10 Author: Desmond Kirkpatrick
// <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  group('SetAssociativeCache basic tests', () {
    test('instantiate cache', () async {
      final clk = SimpleClockGenerator(10).clk;

      final reset = Logic();
      final fillPort = ValidDataPortInterface(8, 16);
      final rdPort = ValidDataPortInterface(8, 16);

      final cache = SetAssociativeCache(clk, reset, [fillPort], [rdPort],
          ways: 4, lines: 8);

      await cache.build();
    });

    test('Cache smoke test', () async {
      final clk = SimpleClockGenerator(10).clk;

      final reset = Logic();

      final fillPort = ValidDataPortInterface(8, 16);
      final fillPort2 = ValidDataPortInterface(8, 16);
      final rdPort = ValidDataPortInterface(8, 16);
      final rdPort2 = ValidDataPortInterface(8, 16);

      final cache = SetAssociativeCache(
          clk, reset, [fillPort, fillPort2], [rdPort, rdPort2],
          ways: 4, lines: 51);

      await cache.build();
      unawaited(Simulator.run());

      await clk.waitCycles(2);

      fillPort.en.inject(0);
      fillPort.valid.inject(0);
      rdPort.en.inject(0);
      fillPort.addr.inject(0);
      fillPort.data.inject(0);
      rdPort.addr.inject(0);
      fillPort2.en.inject(0);
      fillPort2.valid.inject(0);
      rdPort2.en.inject(0);
      fillPort2.addr.inject(0);
      fillPort2.data.inject(0);
      rdPort2.addr.inject(0);
      reset.inject(1);
      await clk.nextPosedge;
      reset.inject(0);
      await clk.waitCycles(2);

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

      final fillPort = ValidDataPortInterface(8, 16);
      final fillPort2 = ValidDataPortInterface(8, 16);
      final rdPort = ValidDataPortInterface(8, 16);
      final rdPort2 = ValidDataPortInterface(8, 16);

      final cache = SetAssociativeCache(
          clk, reset, [fillPort, fillPort2], [rdPort, rdPort2],
          ways: 4, lines: 51);

      await cache.build();
      unawaited(Simulator.run());

      await clk.waitCycles(2);

      fillPort.en.inject(0);
      fillPort.valid.inject(0);
      rdPort.en.inject(0);
      fillPort.addr.inject(0);
      fillPort.data.inject(0);
      rdPort.addr.inject(0);
      fillPort2.en.inject(0);
      fillPort2.valid.inject(0);
      rdPort2.en.inject(0);
      fillPort2.addr.inject(0);
      fillPort2.data.inject(0);
      rdPort2.addr.inject(0);
      reset.inject(1);
      await clk.nextPosedge;
      reset.inject(0);
      await clk.waitCycles(2);

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

      final fillPort = ValidDataPortInterface(8, 16);
      final fillPort2 = ValidDataPortInterface(8, 16);
      final rdPort = ValidDataPortInterface(8, 16);
      final rdPort2 = ValidDataPortInterface(8, 16);

      final cache = SetAssociativeCache(
          clk, reset, [fillPort, fillPort2], [rdPort, rdPort2],
          ways: 4, lines: 51);

      await cache.build();
      unawaited(Simulator.run());

      await clk.waitCycles(2);

      fillPort.en.inject(0);
      fillPort.valid.inject(0);
      rdPort.en.inject(0);
      fillPort.addr.inject(0);
      fillPort.data.inject(0);
      rdPort.addr.inject(0);
      fillPort2.en.inject(0);
      fillPort2.valid.inject(0);
      rdPort2.en.inject(0);
      fillPort2.addr.inject(0);
      fillPort2.data.inject(0);
      rdPort2.addr.inject(0);
      reset.inject(1);
      await clk.nextPosedge;
      reset.inject(0);
      await clk.waitCycles(2);

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
  });

  group('Cache narrow tests', () {
    const dataWidth = 4;
    const addrWidth = 7;
    const ways = 4;
    final lines = BigInt.two.pow(addrWidth).toInt() ~/ ways;
    final lineAddrWith = log2Ceil(lines);
    final tagWidth = addrWidth - lineAddrWith;

    test('Cache singleton 2 writes then reads test', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort = ValidDataPortInterface(dataWidth, addrWidth);
      final rdPort = ValidDataPortInterface(dataWidth, addrWidth);

      final cache = SetAssociativeCache(clk, reset, [fillPort], [rdPort],
          ways: ways, lines: lines);

      await cache.build();
      unawaited(Simulator.run());

      await clk.waitCycles(2);
      rdPort.en.inject(0);
      rdPort.addr.inject(0);
      fillPort.en.inject(0);
      fillPort.addr.inject(0);
      fillPort.data.inject(0);
      reset.inject(1);
      await clk.nextPosedge;
      reset.inject(0);
      await clk.waitCycles(2);

      // write data to address addr
      const first = 0x20;
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(first);
      fillPort.data.inject(9);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.waitCycles(3);

      const second = 0x40;
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
      final fillPort = ValidDataPortInterface(dataWidth, addrWidth);
      final rdPort = ValidDataPortInterface(dataWidth, addrWidth);

      final cache = SetAssociativeCache(clk, reset, [fillPort], [rdPort],
          ways: ways, lines: lines);
      await cache.build();

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
      // reset flow
      fillPort.en.inject(0);
      rdPort.en.inject(0);
      fillPort.addr.inject(0);
      fillPort.data.inject(0);
      rdPort.addr.inject(0);
      reset.inject(1);
      await clk.nextPosedge;
      reset.inject(0);
      // end reset flow

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
    // Note: Common eviction tests are in cache_eviction_test.dart
    // This file contains tests specific to SetAssociativeCache behavior

    test('eviction on way conflict', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort = ValidDataPortInterface(8, 8);
      final readPort = ValidDataPortInterface(8, 8);
      final evictionPort = ValidDataPortInterface(8, 8);

      // 2 ways, 4 lines
      final cache = SetAssociativeCache(clk, reset, [fillPort], [readPort],
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
      readPort.en.inject(1);
      readPort.addr.inject(evictedAddr);
      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), isFalse,
          reason: 'Evicted entry should not be present');
      readPort.en.inject(0);

      await Simulator.endSimulation();
    });

    test('simultaneous evictions on multiple fill ports', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort0 = ValidDataPortInterface(8, 8);
      final fillPort1 = ValidDataPortInterface(8, 8);
      final readPort = ValidDataPortInterface(8, 8);
      final evictionPort0 = ValidDataPortInterface(8, 8);
      final evictionPort1 = ValidDataPortInterface(8, 8);

      final cache = SetAssociativeCache(
          clk, reset, [fillPort0, fillPort1], [readPort],
          evictions: [evictionPort0, evictionPort1], lines: 2);

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

      // Fill all ways of line 0 using both ports
      fillPort0.en.inject(1);
      fillPort0.valid.inject(1);
      fillPort0.addr.inject(0x00);
      fillPort0.data.inject(0xA0);
      writtenData[0x00] = 0xA0;

      fillPort1.en.inject(1);
      fillPort1.valid.inject(1);
      fillPort1.addr.inject(0x02);
      fillPort1.data.inject(0xA1);
      writtenData[0x02] = 0xA1;

      await clk.nextPosedge;
      fillPort0.en.inject(0);
      fillPort1.en.inject(0);
      await clk.waitCycles(1);

      // Now cause evictions on both ports simultaneously
      fillPort0.en.inject(1);
      fillPort0.valid.inject(1);
      fillPort0.addr.inject(0x04); // Line 0
      fillPort0.data.inject(0xB0);
      writtenData[0x04] = 0xB0;

      fillPort1.en.inject(1);
      fillPort1.valid.inject(1);
      fillPort1.addr.inject(0x03); // Line 1
      fillPort1.data.inject(0xB1);
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
      fillPort0.en.inject(0);
      fillPort1.en.inject(0);

      await Simulator.endSimulation();
    });
  });
}
