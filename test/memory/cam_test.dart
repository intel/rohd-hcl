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

  group('CamInvalidate', () {
    test('basic write and lookup with invalidate', () async {
      const tagWidth = 8;
      const numEntries = 4;
      const idWidth = 2;

      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final writePort = DataPortInterface(tagWidth, idWidth);
      final lookupPort = TagInvalidateInterface(idWidth, tagWidth);

      final cam = CamInvalidate(
        clk,
        reset,
        [writePort],
        [lookupPort],
        numEntries: numEntries,
      );

      await cam.build();

      unawaited(Simulator.run());

      // Reset
      reset.inject(1);
      writePort.en.inject(0);
      lookupPort.invalidate.inject(0);
      await clk.nextPosedge;
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;

      // Write tag 0x42 to entry 0
      writePort.en.inject(1);
      writePort.addr.inject(0);
      writePort.data.inject(0x42);
      await clk.nextPosedge;

      // Write tag 0x99 to entry 1
      writePort.addr.inject(1);
      writePort.data.inject(0x99);
      await clk.nextPosedge;

      writePort.en.inject(0);
      await clk.nextPosedge;

      // Lookup tag 0x42 without invalidate
      lookupPort.tag.inject(0x42);
      await clk.nextPosedge;

      expect(lookupPort.hit.value.toBool(), isTrue,
          reason: 'Should hit for tag 0x42');
      expect(lookupPort.idx.value.toInt(), equals(0),
          reason: 'Should return index 0');

      // Lookup again - should still hit
      await clk.nextPosedge;
      expect(lookupPort.hit.value.toBool(), isTrue,
          reason: 'Should still hit after lookup without invalidate');

      // Lookup with invalidate
      lookupPort.invalidate.inject(1);

      expect(lookupPort.hit.value.toBool(), isTrue,
          reason: 'Should hit when invalidate is asserted (original behavior)');
      await clk.nextPosedge;

      // Try to lookup again - should miss because entry was invalidated
      lookupPort.invalidate.inject(0);
      await clk.nextPosedge;

      expect(lookupPort.hit.value.toBool(), isFalse,
          reason: 'Should miss after entry was invalidated');

      // Lookup tag 0x99 - should still be valid
      lookupPort.tag.inject(0x99);
      await clk.nextPosedge;

      expect(lookupPort.hit.value.toBool(), isTrue,
          reason: 'Entry 1 should still be valid');
      expect(lookupPort.idx.value.toInt(), equals(1),
          reason: 'Should return index 1');

      await Simulator.endSimulation();
    });

    test('multiple lookups with different invalidate behavior', () async {
      const tagWidth = 16;
      const idWidth = 3;

      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final writePort = DataPortInterface(tagWidth, idWidth);
      final lookupPort1 = TagInvalidateInterface(idWidth, tagWidth);
      final lookupPort2 = TagInvalidateInterface(idWidth, tagWidth);

      final cam = CamInvalidate(
        clk,
        reset,
        [writePort],
        [lookupPort1, lookupPort2],
      );

      await cam.build();

      unawaited(Simulator.run());

      // Reset
      reset.inject(1);
      writePort.en.inject(0);
      lookupPort1.invalidate.inject(0);
      lookupPort2.invalidate.inject(0);
      await clk.nextPosedge;
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;

      // Write some entries
      writePort.en.inject(1);
      for (var i = 0; i < 4; i++) {
        writePort.addr.inject(i);
        writePort.data.inject(0x1000 + i);
        await clk.nextPosedge;
      }
      writePort.en.inject(0);
      await clk.nextPosedge;

      // Both ports lookup different tags
      lookupPort1.tag.inject(0x1000);
      lookupPort1.invalidate.inject(0);

      lookupPort2.tag.inject(0x1002);
      lookupPort2.invalidate.inject(0);

      await clk.nextPosedge;

      expect(lookupPort1.hit.value.toBool(), isTrue);
      expect(lookupPort1.idx.value.toInt(), equals(0));
      expect(lookupPort2.hit.value.toBool(), isTrue);
      expect(lookupPort2.idx.value.toInt(), equals(2));

      // Port 1 invalidates entry 0, port 2 doesn't invalidate
      lookupPort1.invalidate.inject(1);
      await clk.nextPosedge;

      // Port 1 should now miss, port 2 should still hit
      lookupPort1.invalidate.inject(0);
      await clk.nextPosedge;

      expect(lookupPort1.hit.value.toBool(), isFalse,
          reason: 'Entry 0 was invalidated');
      expect(lookupPort2.hit.value.toBool(), isTrue,
          reason: 'Entry 2 was not invalidated');

      await Simulator.endSimulation();
    });

    test('rewrite after invalidate restores entry', () async {
      const tagWidth = 8;
      const numEntries = 4;
      const idWidth = 2;

      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final writePort = DataPortInterface(tagWidth, idWidth);
      final lookupPort = TagInvalidateInterface(idWidth, tagWidth);

      final cam = CamInvalidate(
        clk,
        reset,
        [writePort],
        [lookupPort],
        numEntries: numEntries,
      );

      await cam.build();

      unawaited(Simulator.run());

      // Reset
      reset.inject(1);
      writePort.en.inject(0);
      lookupPort.invalidate.inject(0);
      await clk.nextPosedge;
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;

      // Write and invalidate
      writePort.en.inject(1);
      writePort.addr.inject(0);
      writePort.data.inject(0xAA);
      await clk.nextPosedge;
      writePort.en.inject(0);
      await clk.nextPosedge;

      // Lookup and invalidate
      lookupPort.tag.inject(0xAA);
      lookupPort.invalidate.inject(1);

      // Combinational output check
      await clk.nextNegedge;
      expect(lookupPort.hit.value.toBool(), isTrue,
          reason: 'Should hit when invalidate is asserted (original behavior)');
      await clk.nextPosedge;

      // Should now miss
      lookupPort.invalidate.inject(0);
      await clk.nextPosedge;
      expect(lookupPort.hit.value.toBool(), isFalse);

      // Rewrite the same entry
      writePort.en.inject(1);
      writePort.addr.inject(0);
      writePort.data.inject(0xAA);
      await clk.nextPosedge;
      writePort.en.inject(0);
      await clk.nextPosedge;

      // Should hit again
      lookupPort.tag.inject(0xAA);

      // Combinational output check
      await clk.nextNegedge;
      expect(lookupPort.hit.value.toBool(), isTrue,
          reason: 'Entry should be valid after rewrite');

      await Simulator.endSimulation();
    });

    test('invalidate only clears on hit', () async {
      const tagWidth = 8;
      const numEntries = 4;
      const idWidth = 2;

      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final writePort = DataPortInterface(tagWidth, idWidth);
      final lookupPort = TagInvalidateInterface(idWidth, tagWidth);

      final cam = CamInvalidate(
        clk,
        reset,
        [writePort],
        [lookupPort],
        numEntries: numEntries,
      );

      await cam.build();

      unawaited(Simulator.run());

      // Reset
      reset.inject(1);
      writePort.en.inject(0);
      lookupPort.invalidate.inject(0);
      await clk.nextPosedge;
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;

      // Write entry
      writePort.en.inject(1);
      writePort.addr.inject(0);
      writePort.data.inject(0x55);
      await clk.nextPosedge;
      writePort.en.inject(0);
      await clk.nextPosedge;

      // Lookup wrong tag with invalidate - should not affect entry
      lookupPort.tag.inject(0x66); // Wrong tag
      lookupPort.invalidate.inject(1);
      await clk.nextNegedge;

      expect(lookupPort.hit.value.toBool(), isFalse,
          reason: 'Should miss for wrong tag');

      // Lookup correct tag - should still hit
      lookupPort.tag.inject(0x55);
      lookupPort.invalidate.inject(0);
      await clk.nextPosedge;

      expect(lookupPort.hit.value.toBool(), isTrue,
          reason: 'Entry should still be valid (invalidate only on hit)');

      await Simulator.endSimulation();
    });

    test('CamInvalidate with valid tracking', () async {
      const numEntries = 4;
      const tagWidth = 8;
      const idWidth = 2;

      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final writePort = DataPortInterface(tagWidth, idWidth);
      final lookupPort = TagInvalidateInterface(idWidth, tagWidth);

      final cam = CamInvalidate(
        clk,
        reset,
        [writePort],
        [lookupPort],
        numEntries: numEntries,
        enableValidTracking: true,
      );

      await cam.build();
      unawaited(Simulator.run());

      // Reset
      reset.inject(1);
      writePort.en.inject(0);
      lookupPort.invalidate.inject(0);
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

      // Write entries
      writePort.en.inject(1);
      for (var i = 0; i < numEntries; i++) {
        writePort.addr.inject(i);
        writePort.data.inject(0x10 + i);
        await clk.nextPosedge;
      }
      writePort.en.inject(0);
      await clk.nextPosedge;

      // Should be full
      expect(cam.empty!.value.toBool(), isFalse, reason: 'Should not be empty');
      expect(cam.full!.value.toBool(), isTrue, reason: 'Should be full');
      expect(cam.validCount!.value.toInt(), equals(numEntries),
          reason: 'Count should equal numEntries');

      // Invalidate one entry
      lookupPort.tag.inject(0x10);
      lookupPort.invalidate.inject(1);

      // Check combinational output.
      await clk.nextNegedge;
      // Wait for invalidate to take effect
      expect(lookupPort.hit.value.toBool(), isTrue,
          reason: 'Should hit when invalidate is asserted (original behavior)');
      await clk.nextPosedge;

      expect(cam.full!.value.toBool(), isFalse,
          reason: 'Should not be full after invalidate');
      expect(cam.validCount!.value.toInt(), equals(numEntries - 1),
          reason: 'Count should decrease by 1');

      // Invalidate remaining entries
      for (var i = 1; i < numEntries; i++) {
        lookupPort.tag.inject(0x10 + i);
        await clk.nextPosedge;
        await clk.nextPosedge; // Wait for invalidate
      }

      // Should be empty now
      expect(cam.empty!.value.toBool(), isTrue,
          reason: 'Should be empty after invalidating all');
      expect(cam.validCount!.value.toInt(), equals(0),
          reason: 'Count should be 0');

      await Simulator.endSimulation();
    });

    test('CamInvalidate simultaneous write and invalidate', () async {
      const numEntries = 8;
      const tagWidth = 8;
      const idWidth = 3;

      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final writePort = DataPortInterface(tagWidth, idWidth);
      final lookupPort = TagInvalidateInterface(idWidth, tagWidth);

      final cam = CamInvalidate(
        clk,
        reset,
        [writePort],
        [lookupPort],
        enableValidTracking: true,
      );

      await cam.build();

      unawaited(Simulator.run());

      // Reset
      reset.inject(1);
      writePort.en.inject(0);
      lookupPort.invalidate.inject(0);
      await clk.nextPosedge;
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;

      // Fill CAM completely
      writePort.en.inject(1);
      for (var i = 0; i < numEntries; i++) {
        writePort.addr.inject(i);
        writePort.data.inject(0xA0 + i);
        await clk.nextPosedge;
      }

      // Verify full
      expect(cam.full!.value.toBool(), isTrue, reason: 'CAM should be full');
      expect(cam.validCount!.value.toInt(), equals(numEntries),
          reason: 'Count should equal numEntries');

      // Disable write temporarily
      writePort.en.inject(0);
      await clk.nextPosedge;

      // Verify we can lookup the entries before starting simultaneous ops,
      lookupPort.invalidate.inject(0); // Don't invalidate yet
      lookupPort.tag.inject(0xA0);
      await clk.nextPosedge;

      expect(lookupPort.hit.value.toBool(), isTrue,
          reason: 'Should find 0xA0 before test');
      lookupPort.tag.inject(0xA1);
      await clk.nextPosedge;

      expect(lookupPort.hit.value.toBool(), isTrue,
          reason: 'Should find 0xA1 before test');

      // Now perform simultaneous write and invalidate operations This
      // demonstrates that the CAM can handle looking up/invalidating entries
      // while simultaneously writing new entries.
      //
      // Test: Do 4 simultaneous operations (half the CAM size) to demonstrate
      // that writes and invalidate-on-read can happen concurrently.

      writePort.en.inject(1);
      lookupPort.invalidate.inject(1);

      const numSimultaneousOps = numEntries ~/ 2;
      for (var i = 0; i < numSimultaneousOps; i++) {
        // Write to the upper half while invalidating the lower half.
        final writeIdx = i + numSimultaneousOps; // Indices 4-7
        final lookupIdx = i; // Indices 0-3
        final lookupTag = 0xA0 + lookupIdx;

        lookupPort.tag.inject(lookupTag);
        writePort.addr.inject(writeIdx);
        writePort.data.inject(0xC0 + writeIdx); // New tag

        await clk.nextNegedge;

        // Should hit when invalidate is asserted (original behavior restored).
        expect(lookupPort.hit.value.toBool(), isTrue,
            reason: 'Cycle $i: Should hit when invalidate=1 for '
                'tag 0x${lookupTag.toRadixString(16)}');
        await clk.nextPosedge;
      }

      // Wait for final write and invalidates to settle.
      // Need extra cycles because:
      // - Writes complete on the clock edge.
      // - Invalidates happen one cycle after lookup (registered).
      await clk.nextPosedge;
      await clk.nextPosedge;
      await clk.nextPosedge;

      // After invalidating lower half (indices 0-3) and writing new entries to
      // upper half (indices 4-7), we should have exactly the upper half valid.
      expect(cam.full!.value.toBool(), isFalse,
          reason: 'CAM should not be full - only upper half is valid');
      expect(cam.validCount!.value.toInt(), equals(numSimultaneousOps),
          reason:
              'Count should equal number of new writes ($numSimultaneousOps)');

      // Verify the new entries in upper half exist and can be looked up
      lookupPort.invalidate.inject(0); // Don't invalidate for verification
      for (var i = numSimultaneousOps; i < numEntries; i++) {
        lookupPort.tag.inject(0xC0 + i);
        await clk.nextPosedge;
        expect(lookupPort.hit.value.toBool(), isTrue,
            reason: 'Should find new tag 0x${(0xC0 + i).toRadixString(16)}');
        expect(lookupPort.idx.value.toInt(), equals(i),
            reason: 'Should be at index $i');
      }

      // Verify lower half entries are invalidated (miss on lookup)
      for (var i = 0; i < numSimultaneousOps; i++) {
        lookupPort.tag.inject(0xA0 + i);
        await clk.nextPosedge;
        expect(lookupPort.hit.value.toBool(), isFalse,
            reason: 'Should NOT find invalidated '
                'tag 0x${(0xA0 + i).toRadixString(16)}');
      }

      await Simulator.endSimulation();
    });
  });
}
