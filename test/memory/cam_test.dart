// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cam_test.dart
// CAM (Contents-Addressable Memory) tests.
//
// 2025 September 18
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('Cam smoke test', () async {
    final clk = SimpleClockGenerator(10).clk;

    final reset = Logic();

    final wrPort = DataPortInterface(8, 12);
    final wrPort2 = DataPortInterface(8, 12);
    final rdPort = TagInterface(8, 8);
    final rdPort2 = TagInterface(8, 8);

    final cam =
        Cam(clk, reset, [wrPort, wrPort2], [rdPort, rdPort2], numEntries: 32);

    await cam.build();
    unawaited(Simulator.run());

    await clk.nextPosedge;
    await clk.nextPosedge;
    wrPort.en.inject(0);
    reset.inject(1);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextPosedge;

    wrPort.en.inject(1);
    wrPort2.en.inject(1);
    wrPort.addr.inject(14);
    wrPort.data.inject(42);
    wrPort2.addr.inject(29);
    wrPort2.data.inject(7);
    await clk.nextPosedge;
    await clk.nextPosedge;
    wrPort.en.inject(0);
    wrPort2.en.inject(0);
    await clk.nextPosedge;
    rdPort.tag.inject(42);
    rdPort2.tag.inject(7);
    await clk.nextPosedge;
    expect(rdPort.hit.value, LogicValue.one);
    expect(rdPort.idx.value.toInt(), 14);
    expect(rdPort2.hit.value, LogicValue.one);
    expect(rdPort2.idx.value.toInt(), 29);
    await clk.nextPosedge;
    await clk.nextPosedge;

    await Simulator.endSimulation();
  });

  test('Cam with valid tracking', () async {
    const numEntries = 4;
    const tagWidth = 8;

    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    final wrPort = DataPortInterface(tagWidth, log2Ceil(numEntries));
    final rdPort = TagInterface(log2Ceil(numEntries), tagWidth);

    final cam = Cam(
      clk,
      reset,
      [wrPort],
      [rdPort],
      numEntries: numEntries,
      enableValidTracking: true,
    );

    await cam.build();
    unawaited(Simulator.run());

    // Reset
    reset.inject(1);
    wrPort.en.inject(0);
    await clk.nextPosedge;
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextPosedge;

    // Initially empty
    expect(cam.empty!.value.toBool(), isTrue,
        reason: 'Should be empty initially');
    expect(cam.full!.value.toBool(), isFalse,
        reason: 'Should not be full initially');
    expect(cam.validCount!.value.toInt(), equals(0),
        reason: 'Count should be 0');

    // Write one entry
    wrPort.en.inject(1);
    wrPort.addr.inject(0);
    wrPort.data.inject(0x42);
    await clk.nextPosedge;

    expect(cam.empty!.value.toBool(), isFalse,
        reason: 'Should not be empty after write');
    expect(cam.full!.value.toBool(), isFalse,
        reason: 'Should not be full with 1 entry');
    expect(cam.validCount!.value.toInt(), equals(1),
        reason: 'Count should be 1');

    // Write three more entries to fill the CAM
    for (var i = 1; i < numEntries; i++) {
      wrPort.addr.inject(i);
      wrPort.data.inject(0x50 + i);
      await clk.nextPosedge;
    }

    expect(cam.empty!.value.toBool(), isFalse,
        reason: 'Should not be empty when full');
    expect(cam.full!.value.toBool(), isTrue,
        reason: 'Should be full with all entries');
    expect(cam.validCount!.value.toInt(), equals(numEntries),
        reason: 'Count should equal numEntries');

    wrPort.en.inject(0);
    await clk.nextPosedge;

    // Verify lookups work
    rdPort.tag.inject(0x42);
    await clk.nextPosedge;
    expect(rdPort.hit.value.toBool(), isTrue, reason: 'Should find tag 0x42');
    expect(rdPort.idx.value.toInt(), equals(0), reason: 'Should be at index 0');

    await Simulator.endSimulation();
  });
}
