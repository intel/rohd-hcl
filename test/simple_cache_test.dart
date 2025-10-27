// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// simple_cache_test.dart
// Simple test to verify basic cache functionality before readWithInvalidate.
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

  test('basic cache functionality without readWithInvalidate', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    // Create interfaces without readWithInvalidate
    final readIntf = ValidDataPortInterface(8, 8);
    final fillIntf = ValidDataPortInterface(8, 8);

    final cache = FullyAssociativeCache(
      clk,
      reset,
      [fillIntf],
      [readIntf],
    );

    await cache.build();

    WaveDumper(cache, outputPath: 'simple_cache_test.vcd');

    Simulator.setMaxSimTime(300);
    unawaited(Simulator.run());

    // Reset sequence
    reset.inject(1);
    readIntf.en.inject(0);
    readIntf.addr.inject(0);
    fillIntf.en.inject(0);
    fillIntf.valid.inject(0);
    fillIntf.addr.inject(0);
    fillIntf.data.inject(0);
    await clk.waitCycles(2);

    reset.inject(0);
    await clk.waitCycles(1);

    print('=== Simple Cache Test ===');

    // Step 1: Fill cache with data
    print('Step 1: Filling cache entry');
    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(0x42);
    fillIntf.data.inject(0xAB);
    await clk.nextPosedge;

    fillIntf.en.inject(0);
    await clk.nextPosedge;

    // Step 2: Read (should hit)
    print('Step 2: Reading cache entry (should hit)');
    readIntf.en.inject(1);
    readIntf.addr.inject(0x42);
    await clk.nextPosedge;

    expect(readIntf.valid.value.toBool(), isTrue, reason: 'Should hit');
    expect(readIntf.data.value.toInt(), equals(0xAB),
        reason: 'Should return correct data');
    print('✅ Read hit with data: '
        '0x${readIntf.data.value.toInt().toRadixString(16)}');

    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Step 3: Read different address (should miss)
    print('Step 3: Reading different address (should miss)');
    readIntf.en.inject(1);
    readIntf.addr.inject(0x99);
    await clk.nextPosedge;

    expect(readIntf.valid.value.toBool(), isFalse, reason: 'Should miss');
    print('✅ Read missed as expected');

    readIntf.en.inject(0);
    await clk.nextPosedge;

    await Simulator.endSimulation();
    print('=== Simple Cache Test Complete ===');
  });
}
