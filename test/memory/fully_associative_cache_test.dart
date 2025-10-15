// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fully_associative_cache_test.dart
// Tests for fully associative cache.
//
// 2025 October 15
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('FullyAssociativeReadCache instantiate', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final fillPort = ValidDataPortInterface(8, 16);
    final rdPort = ValidDataPortInterface(8, 16);

    final cache = FullyAssociativeReadCache(
      clk,
      reset,
      [fillPort],
      [rdPort],
      numEntries: 8,
    );

    await cache.build();
    // print(cache.generateSynth());
  });

  test('FullyAssociativeReadCache basic read/write', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    final fillPort = ValidDataPortInterface(8, 16);
    final rdPort = ValidDataPortInterface(8, 16);

    final cache = FullyAssociativeReadCache(
      clk,
      reset,
      [fillPort],
      [rdPort],
      numEntries: 8,
    );

    await cache.build();
    unawaited(Simulator.run());

    // Initialize signals
    fillPort.en.inject(0);
    fillPort.valid.inject(0);
    fillPort.addr.inject(0);
    fillPort.data.inject(0);
    rdPort.en.inject(0);
    rdPort.addr.inject(0);

    // Reset
    reset.inject(1);
    await clk.waitCycles(3);
    reset.inject(0);
    await clk.waitCycles(1);

    // Write data to address 0x1234
    fillPort.en.inject(1);
    fillPort.valid.inject(1);
    fillPort.addr.inject(0x1234);
    fillPort.data.inject(0xAB);
    await clk.nextPosedge;

    fillPort.en.inject(0);
    await clk.nextPosedge;

    // Read back from address 0x1234
    rdPort.en.inject(1);
    rdPort.addr.inject(0x1234);
    await clk.nextPosedge;

    expect(rdPort.valid.value, LogicValue.one, reason: 'Should hit in cache');
    expect(rdPort.data.value, LogicValue.ofInt(0xAB, 8),
        reason: 'Should return correct data');

    rdPort.en.inject(0);
    await clk.waitCycles(1);

    // Read from non-existent address
    rdPort.en.inject(1);
    rdPort.addr.inject(0x5678);
    await clk.nextPosedge;

    expect(rdPort.valid.value, LogicValue.zero, reason: 'Should miss in cache');

    await Simulator.endSimulation();
  });

  test('FullyAssociativeReadCache multiple entries', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    final fillPort = ValidDataPortInterface(8, 16);
    final rdPort = ValidDataPortInterface(8, 16);

    final cache = FullyAssociativeReadCache(
      clk,
      reset,
      [fillPort],
      [rdPort],
      numEntries: 4,
    );

    await cache.build();
    unawaited(Simulator.run());

    // Initialize
    fillPort.en.inject(0);
    fillPort.valid.inject(0);
    fillPort.addr.inject(0);
    fillPort.data.inject(0);
    rdPort.en.inject(0);
    rdPort.addr.inject(0);

    reset.inject(1);
    await clk.waitCycles(3);
    reset.inject(0);
    await clk.waitCycles(1);

    // Fill cache with 4 different addresses
    final testData = [
      (0x1000, 0x11),
      (0x2000, 0x22),
      (0x3000, 0x33),
      (0x4000, 0x44),
    ];

    for (final (addr, data) in testData) {
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(addr);
      fillPort.data.inject(data);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.nextPosedge;
    }

    // Verify all entries can be read
    for (final (addr, data) in testData) {
      rdPort.en.inject(1);
      rdPort.addr.inject(addr);
      await clk.nextPosedge;

      expect(rdPort.valid.value, LogicValue.one,
          reason: 'Should hit for address 0x${addr.toRadixString(16)}');
      expect(rdPort.data.value, LogicValue.ofInt(data, 8),
          reason: 'Should return correct data for 0x${addr.toRadixString(16)}');

      rdPort.en.inject(0);
      await clk.nextPosedge;
    }

    await Simulator.endSimulation();
  });

  test('FullyAssociativeReadCache eviction and replacement', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    final fillPort = ValidDataPortInterface(8, 16);
    final rdPort = ValidDataPortInterface(8, 16);

    final cache = FullyAssociativeReadCache(
      clk,
      reset,
      [fillPort],
      [rdPort],
      numEntries: 4,
    );

    await cache.build();
    unawaited(Simulator.run());

    // Initialize
    fillPort.en.inject(0);
    fillPort.valid.inject(0);
    fillPort.addr.inject(0);
    fillPort.data.inject(0);
    rdPort.en.inject(0);
    rdPort.addr.inject(0);

    reset.inject(1);
    await clk.waitCycles(3);
    reset.inject(0);
    await clk.waitCycles(1);

    // Fill cache completely (4 entries)
    for (var i = 0; i < 4; i++) {
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(0x1000 + i * 0x100);
      fillPort.data.inject(0x10 + i);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.nextPosedge;
    }

    // Verify cache is full
    for (var i = 0; i < 4; i++) {
      rdPort.en.inject(1);
      rdPort.addr.inject(0x1000 + i * 0x100);
      await clk.nextPosedge;
      expect(rdPort.valid.value, LogicValue.one);
      rdPort.en.inject(0);
      await clk.nextPosedge;
    }

    // Add a 5th entry - should evict one of the existing entries
    fillPort.en.inject(1);
    fillPort.valid.inject(1);
    fillPort.addr.inject(0x5000);
    fillPort.data.inject(0x55);
    await clk.nextPosedge;
    fillPort.en.inject(0);
    await clk.nextPosedge;

    // Verify the new entry is present
    rdPort.en.inject(1);
    rdPort.addr.inject(0x5000);
    await clk.nextPosedge;
    expect(rdPort.valid.value, LogicValue.one,
        reason: 'New entry should be in cache');
    expect(rdPort.data.value, LogicValue.ofInt(0x55, 8));

    await Simulator.endSimulation();
  });

  test('FullyAssociativeReadCache update existing entry', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    final fillPort = ValidDataPortInterface(8, 16);
    final rdPort = ValidDataPortInterface(8, 16);

    final cache = FullyAssociativeReadCache(
      clk,
      reset,
      [fillPort],
      [rdPort],
      numEntries: 4,
    );

    await cache.build();
    unawaited(Simulator.run());

    // Initialize
    fillPort.en.inject(0);
    fillPort.valid.inject(0);
    fillPort.addr.inject(0);
    fillPort.data.inject(0);
    rdPort.en.inject(0);
    rdPort.addr.inject(0);

    reset.inject(1);
    await clk.waitCycles(3);
    reset.inject(0);
    await clk.waitCycles(1);

    // Write initial data
    fillPort.en.inject(1);
    fillPort.valid.inject(1);
    fillPort.addr.inject(0x1234);
    fillPort.data.inject(0x11);
    await clk.nextPosedge;
    fillPort.en.inject(0);
    await clk.nextPosedge;

    // Update with new data
    fillPort.en.inject(1);
    fillPort.valid.inject(1);
    fillPort.addr.inject(0x1234);
    fillPort.data.inject(0x99);
    await clk.nextPosedge;
    fillPort.en.inject(0);
    await clk.nextPosedge;

    // Read back - should get updated data
    rdPort.en.inject(1);
    rdPort.addr.inject(0x1234);
    await clk.nextPosedge;

    expect(rdPort.valid.value, LogicValue.one);
    expect(rdPort.data.value, LogicValue.ofInt(0x99, 8),
        reason: 'Should return updated data');

    await Simulator.endSimulation();
  });

  test('FullyAssociativeReadCache invalidate entry', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    final fillPort = ValidDataPortInterface(8, 16);
    final rdPort = ValidDataPortInterface(8, 16);

    final cache = FullyAssociativeReadCache(
      clk,
      reset,
      [fillPort],
      [rdPort],
      numEntries: 4,
    );

    await cache.build();
    unawaited(Simulator.run());

    // Initialize
    fillPort.en.inject(0);
    fillPort.valid.inject(0);
    fillPort.addr.inject(0);
    fillPort.data.inject(0);
    rdPort.en.inject(0);
    rdPort.addr.inject(0);

    reset.inject(1);
    await clk.waitCycles(3);
    reset.inject(0);
    await clk.waitCycles(1);

    // Write data
    fillPort.en.inject(1);
    fillPort.valid.inject(1);
    fillPort.addr.inject(0x1234);
    fillPort.data.inject(0xAB);
    await clk.nextPosedge;
    fillPort.en.inject(0);
    await clk.nextPosedge;

    // Verify it's there
    rdPort.en.inject(1);
    rdPort.addr.inject(0x1234);
    await clk.nextPosedge;
    expect(rdPort.valid.value, LogicValue.one);
    rdPort.en.inject(0);
    await clk.nextPosedge;

    // Invalidate the entry (valid = 0)
    fillPort.en.inject(1);
    fillPort.valid.inject(0);
    fillPort.addr.inject(0x1234);
    await clk.nextPosedge;
    fillPort.en.inject(0);
    await clk.waitCycles(2);

    // Try to read - should miss
    rdPort.en.inject(1);
    rdPort.addr.inject(0x1234);
    await clk.nextPosedge;

    expect(rdPort.valid.value, LogicValue.zero,
        reason: 'Should miss after invalidate');

    await Simulator.endSimulation();
  });

  test('FullyAssociativeReadCache multi-port operations', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    final fillPort1 = ValidDataPortInterface(8, 16);
    final fillPort2 = ValidDataPortInterface(8, 16);
    final rdPort1 = ValidDataPortInterface(8, 16);
    final rdPort2 = ValidDataPortInterface(8, 16);

    final cache = FullyAssociativeReadCache(
      clk,
      reset,
      [fillPort1, fillPort2],
      [rdPort1, rdPort2],
      numEntries: 8,
    );

    await cache.build();
    unawaited(Simulator.run());

    // Initialize all ports
    fillPort1.en.inject(0);
    fillPort1.valid.inject(0);
    fillPort1.addr.inject(0);
    fillPort1.data.inject(0);
    fillPort2.en.inject(0);
    fillPort2.valid.inject(0);
    fillPort2.addr.inject(0);
    fillPort2.data.inject(0);
    rdPort1.en.inject(0);
    rdPort1.addr.inject(0);
    rdPort2.en.inject(0);
    rdPort2.addr.inject(0);

    reset.inject(1);
    await clk.waitCycles(3);
    reset.inject(0);
    await clk.waitCycles(1);

    // Write to two different addresses simultaneously
    fillPort1.en.inject(1);
    fillPort1.valid.inject(1);
    fillPort1.addr.inject(0x1000);
    fillPort1.data.inject(0xAA);

    fillPort2.en.inject(1);
    fillPort2.valid.inject(1);
    fillPort2.addr.inject(0x2000);
    fillPort2.data.inject(0xBB);

    await clk.nextPosedge;

    fillPort1.en.inject(0);
    fillPort2.en.inject(0);
    await clk.nextPosedge;

    // Read from both addresses simultaneously
    rdPort1.en.inject(1);
    rdPort1.addr.inject(0x1000);

    rdPort2.en.inject(1);
    rdPort2.addr.inject(0x2000);

    await clk.nextPosedge;

    expect(rdPort1.valid.value, LogicValue.one);
    expect(rdPort1.data.value, LogicValue.ofInt(0xAA, 8));

    expect(rdPort2.valid.value, LogicValue.one);
    expect(rdPort2.data.value, LogicValue.ofInt(0xBB, 8));

    await Simulator.endSimulation();
  });
}
