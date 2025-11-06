// Debug test for simultaneous operations
import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('debug simultaneous operations', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    final readIntf = ValidDataPortInterface(8, 8, hasReadWithInvalidate: true);
    final fillIntf = ValidDataPortInterface(8, 8);

    final cache = FullyAssociativeCache(
      clk,
      reset,
      [fillIntf],
      [readIntf],
      ways: 2,
      generateOccupancy: true,
    );

    await cache.build();

    // WaveDumper(cache, outputPath: 'debug_simultaneous.vcd');

    Simulator.setMaxSimTime(400);
    unawaited(Simulator.run());

    // Reset
    reset.inject(1);
    readIntf.en.inject(0);
    readIntf.readWithInvalidate.inject(0);
    fillIntf.en.inject(0);
    fillIntf.valid.inject(0);
    await clk.waitCycles(2);

    reset.inject(0);
    await clk.waitCycles(1);

    // === Debug Simultaneous Operations ===

    // Fill to capacity - initial state
    expect(cache.occupancy!.value.toInt(), equals(0),
        reason: 'Cache should start empty');
    expect(cache.full!.value.toBool(), isFalse,
        reason: 'Cache should not be full initially');

    // Fill first entry - Fill 0x10
    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(0x10);
    fillIntf.data.inject(0xA0);
    await clk.nextPosedge;

    fillIntf.en.inject(0);
    await clk.nextPosedge;

    expect(cache.occupancy!.value.toInt(), equals(1),
        reason: 'Occupancy should be 1 after first fill');
    expect(cache.full!.value.toBool(), isFalse,
        reason: 'Cache should not be full with 1/2 entries');

    // Fill second entry - Fill 0x20
    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(0x20);
    fillIntf.data.inject(0xA1);
    await clk.nextPosedge;

    fillIntf.en.inject(0);
    await clk.nextPosedge;

    expect(cache.occupancy!.value.toInt(), equals(2),
        reason: 'Occupancy should be 2 after second fill');
    expect(cache.full!.value.toBool(), isTrue,
        reason: 'Cache should be full with 2/2 entries');

    // Verify both entries exist - Verify 0x10 exists
    readIntf.en.inject(1);
    readIntf.addr.inject(0x10);
    await clk.nextPosedge;

    expect(readIntf.valid.value.toBool(), isTrue,
        reason: '0x10 should exist in cache');
    expect(readIntf.data.value.toInt(), equals(0xA0),
        reason: '0x10 should contain data 0xA0');

    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Verify 0x20 exists
    readIntf.en.inject(1);
    readIntf.addr.inject(0x20);
    await clk.nextPosedge;

    expect(readIntf.valid.value.toBool(), isTrue,
        reason: '0x20 should exist in cache');
    expect(readIntf.data.value.toInt(), equals(0xA1),
        reason: '0x20 should contain data 0xA1');

    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Now do simultaneous operations - Simultaneous: Fill 0x30 +
    // ReadWithInvalidate 0x10
    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(0x30);
    fillIntf.data.inject(0xC0);

    readIntf.en.inject(1);
    readIntf.addr.inject(0x10);
    readIntf.readWithInvalidate.inject(1);

    await clk.nextPosedge;

    // Simultaneous results - verify readWithInvalidate hit
    expect(readIntf.valid.value.toBool(), isTrue,
        reason: 'ReadWithInvalidate should hit existing 0x10');
    expect(readIntf.data.value.toInt(), equals(0xA0),
        reason: 'ReadWithInvalidate should return 0xA0 from 0x10');

    // Cache state verification will depend on implementation
    expect(cache.occupancy!.value.toInt(), greaterThanOrEqualTo(1),
        reason: 'Cache occupancy should be at least 1 after operations');

    fillIntf.en.inject(0);
    readIntf.en.inject(0);
    readIntf.readWithInvalidate.inject(0);
    await clk.nextPosedge;

    // After cycle - verify final cache state
    expect(cache.occupancy!.value.toInt(), lessThanOrEqualTo(2),
        reason: 'Cache occupancy should not exceed capacity');

    // Test what entries exist now
    final testAddresses = [0x10, 0x20, 0x30];
    for (final addr in testAddresses) {
      readIntf.en.inject(1);
      readIntf.addr.inject(addr);
      await clk.nextPosedge;

      final valid = readIntf.valid.value.toBool();
      // Note: 0x10 should be invalidated, 0x30 should exist, 0x20 may vary
      if (addr == 0x10) {
        expect(valid, isFalse, reason: '0x10 should be invalidated');
      } else if (addr == 0x30) {
        expect(valid, isTrue, reason: '0x30 should exist after fill');
        if (valid) {
          expect(readIntf.data.value.toInt(), equals(0xC0),
              reason: '0x30 should contain data 0xC0');
        }
      }
      // 0x20 may or may not exist depending on replacement policy

      readIntf.en.inject(0);
      await clk.nextPosedge;
    }

    await Simulator.endSimulation();
  });
}
