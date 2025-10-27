// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// comprehensive_cache_test.dart

// Comprehensive test demonstrating FullyAssociativeCache with occupancy and
// readWithInvalidate.
//
// 2025 October 26

import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test(
      'comprehensive cache functionality with occupancy and readWithInvalidate',
      () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    // Create interfaces with readWithInvalidate capability
    final readIntf = ValidDataPortInterface(8, 8, hasReadWithInvalidate: true);
    final fillIntf = ValidDataPortInterface(8, 8);

    final cache = FullyAssociativeCache(
      clk,
      reset,
      [fillIntf],
      [readIntf],
      generateOccupancy: true, // Enable occupancy tracking
    );

    await cache.build();

    WaveDumper(cache, outputPath: 'comprehensive_cache_test.vcd');

    Simulator.setMaxSimTime(800);
    unawaited(Simulator.run());

    // Reset
    reset.inject(1);
    readIntf.en.inject(0);
    readIntf.addr.inject(0);
    readIntf.readWithInvalidate.inject(0);
    fillIntf.en.inject(0);
    fillIntf.valid.inject(0);
    fillIntf.addr.inject(0);
    fillIntf.data.inject(0);
    await clk.waitCycles(2);

    reset.inject(0);
    await clk.waitCycles(1);

    print('=== Comprehensive Cache Test ===');
    print('Testing FullyAssociativeCache with occupancy tracking and '
        'readWithInvalidate');

    // Phase 1: Demonstrate occupancy tracking
    print(r'\nPhase 1: Occupancy Tracking Demo');
    expect(cache.empty!.value.toBool(), isTrue);
    expect(cache.full!.value.toBool(), isFalse);
    expect(cache.occupancy!.value.toInt(), equals(0));
    print('✅ Initial: empty=${cache.empty!.value}, full=${cache.full!.value}, '
        'occupancy=${cache.occupancy!.value.toInt()}');

    // Fill cache entries
    final addresses = [0x100, 0x200, 0x300, 0x400];
    final dataValues = [0xAA, 0xBB, 0xCC, 0xDD];

    for (var i = 0; i < addresses.length; i++) {
      fillIntf.en.inject(1);
      fillIntf.valid.inject(1);
      fillIntf.addr.inject(addresses[i]);
      fillIntf.data.inject(dataValues[i]);
      await clk.nextPosedge;

      fillIntf.en.inject(0);
      await clk.nextPosedge;

      final expectedOccupancy = i + 1;
      expect(cache.occupancy!.value.toInt(), equals(expectedOccupancy));
      print('✅ After fill ${i + 1}: addr=0x${addresses[i].toRadixString(16)}, '
          'occupancy=${cache.occupancy!.value.toInt()}');
    }

    expect(cache.full!.value.toBool(), isTrue);
    print(
        '✅ Cache is now full (occupancy=${cache.occupancy!.value.toInt()}/4)');

    // Phase 2: Demonstrate readWithInvalidate
    print(r'\nPhase 2: ReadWithInvalidate Demo');

    // Normal read first
    readIntf.en.inject(1);
    readIntf.addr.inject(0x200);
    await clk.nextPosedge;
    expect(readIntf.valid.value.toBool(), isTrue);
    expect(readIntf.data.value.toInt(), equals(0xBB));
    print('✅ Normal read: addr=0x200, '
        'data=0x${readIntf.data.value.toInt().toRadixString(16)}');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    // ReadWithInvalidate
    readIntf.en.inject(1);
    readIntf.addr.inject(0x200);
    readIntf.readWithInvalidate.inject(1);
    await clk.nextPosedge;
    expect(readIntf.valid.value.toBool(), isTrue);
    expect(readIntf.data.value.toInt(), equals(0xBB));
    print('✅ ReadWithInvalidate: addr=0x200, '
        'data=0x${readIntf.data.value.toInt().toRadixString(16)}');
    readIntf.en.inject(0);
    readIntf.readWithInvalidate.inject(0);
    await clk.nextPosedge;

    // Verify invalidation
    expect(cache.occupancy!.value.toInt(), equals(3));
    print('✅ After invalidation: '
        'occupancy=${cache.occupancy!.value.toInt()} (reduced by 1)');

    readIntf.en.inject(1);
    readIntf.addr.inject(0x200);
    await clk.nextPosedge;
    expect(readIntf.valid.value.toBool(), isFalse);
    print('✅ Verification: 0x200 is now invalid');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Phase 3: Demonstrate simultaneous fill + readWithInvalidate on full cache
    print(r'\nPhase 3: Simultaneous Operations on Full Cache');

    // First, fill the cache back to full by adding another entry
    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(0x500);
    fillIntf.data.inject(0xEE);
    await clk.nextPosedge;
    fillIntf.en.inject(0);
    await clk.nextPosedge;

    expect(cache.full!.value.toBool(), isTrue);
    expect(cache.occupancy!.value.toInt(), equals(4));
    print('✅ Cache refilled to capacity: '
        'occupancy=${cache.occupancy!.value.toInt()}');

    // Show current cache contents
    print('Current cache contents:');
    final currentAddresses = [
      0x100,
      0x300,
      0x400,
      0x500
    ]; // 0x200 was invalidated
    for (final addr in currentAddresses) {
      readIntf.en.inject(1);
      readIntf.addr.inject(addr);
      await clk.nextPosedge;
      if (readIntf.valid.value.toBool()) {
        print('  0x${addr.toRadixString(16)}: valid, '
            'data=0x${readIntf.data.value.toInt().toRadixString(16)}');
      } else {
        print('  0x${addr.toRadixString(16)}: invalid');
      }
      readIntf.en.inject(0);
      await clk.nextPosedge;
    }

    // Now perform the key test: simultaneous fill + readWithInvalidate on full
    // cache
    print(r'\n🔥 KEY TEST: Simultaneous fill (0x600) + '
        'readWithInvalidate (0x100) on FULL cache');
    print('This demonstrates that the operation is possible, similar to '
        'read+write on full FIFO');

    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(0x600);
    fillIntf.data.inject(0xFF);

    readIntf.en.inject(1);
    readIntf.addr.inject(0x100);
    readIntf.readWithInvalidate.inject(1);

    await clk.nextPosedge;

    // Verify both operations succeeded
    final readHit = readIntf.valid.value.toBool();
    final readData = readIntf.data.value.toInt();

    print('Simultaneous operation results:');
    print('  ReadWithInvalidate: hit=$readHit, '
        'data=0x${readData.toRadixString(16)}');
    print('  Cache occupancy: ${cache.occupancy!.value.toInt()}');
    print('  Cache full: ${cache.full!.value}');

    expect(readHit, isTrue,
        reason: 'ReadWithInvalidate should succeed on full cache');
    expect(readData, equals(0xAA),
        reason: 'Should return correct data for 0x100');

    fillIntf.en.inject(0);
    readIntf.en.inject(0);
    readIntf.readWithInvalidate.inject(0);
    await clk.nextPosedge;

    print('✅ SIMULTANEOUS OPERATIONS SUCCESSFUL ON FULL CACHE!');
    print('  - ReadWithInvalidate freed one slot');
    print('  - Fill used available capacity (may evict other entries '
        'due to replacement policy)');
    print('  - Final occupancy: ${cache.occupancy!.value.toInt()}');

    // Phase 4: Verify final state
    print(r'\nPhase 4: Final State Verification');

    // Check that 0x100 is invalidated
    readIntf.en.inject(1);
    readIntf.addr.inject(0x100);
    await clk.nextPosedge;
    expect(readIntf.valid.value.toBool(), isFalse);
    print('✅ 0x100 successfully invalidated');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Check that 0x600 was added
    readIntf.en.inject(1);
    readIntf.addr.inject(0x600);
    await clk.nextPosedge;
    expect(readIntf.valid.value.toBool(), isTrue);
    expect(readIntf.data.value.toInt(), equals(0xFF));
    print('✅ 0x600 successfully added with '
        'data=0x${readIntf.data.value.toInt().toRadixString(16)}');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    print(r'\n🎉 COMPREHENSIVE TEST COMPLETE!');
    print(
        '✅ Occupancy tracking: empty, full, and count signals work correctly');
    print('✅ ReadWithInvalidate: reads data and invalidates entries');
    print('✅ Simultaneous operations: fill + readWithInvalidate '
        'works on full cache');
    print('✅ Final occupancy: ${cache.occupancy!.value.toInt()}, '
        'empty: ${cache.empty!.value}, full: ${cache.full!.value}');

    await Simulator.endSimulation();
  });
}
