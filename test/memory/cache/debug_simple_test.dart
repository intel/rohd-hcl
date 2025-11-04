import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('debug valid bit updates in detail', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    final readIntf = ValidDataPortInterface(8, 8);
    final fillIntf = ValidDataPortInterface(8, 8);

    final cache = FullyAssociativeCache(
      clk,
      reset,
      [fillIntf],
      [readIntf],
      generateOccupancy: true,
    );

    await cache.build();

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    // Initialize all signals before reset
    readIntf.en.inject(0);
    fillIntf.en.inject(0);
    fillIntf.valid.inject(0);
    fillIntf.addr.inject(0);
    fillIntf.data.inject(0);

    reset.inject(1);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextPosedge;

    // === Debug Valid Bit Updates ===

    // Wait for occupancy to be valid
    var cycles = 0;
    while (!cache.occupancy!.value.isValid && cycles < 10) {
      await clk.nextPosedge;
      cycles++;
    }

    expect(cache.occupancy!.value.isValid, isTrue,
        reason: 'Occupancy should become valid after $cycles cycles');

    // Initial occupancy: ${cache.occupancy!.value.toInt()}

    // Fill first entry - use 8-bit address 0x10
    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(0x10);
    fillIntf.data.inject(0xAA);
    await clk.nextPosedge;

    fillIntf.en.inject(0);
    await clk.nextPosedge;

    // After first fill: occupancy=${cache.occupancy!.value.toInt()}
    expect(cache.occupancy!.value.toInt(), equals(1),
        reason: 'Should have 1 entry after first fill');

    // Verify read
    readIntf.en.inject(1);
    readIntf.addr.inject(0x10);
    await clk.nextPosedge;
    expect(readIntf.valid.value.toBool(), isTrue,
        reason: 'Read 0x10 should be valid');
    expect(readIntf.data.value.toInt(), equals(0xAA),
        reason: 'Read 0x10 should return correct data');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Fill second entry - use 8-bit address 0x20
    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(0x20);
    fillIntf.data.inject(0xBB);
    await clk.nextPosedge;

    fillIntf.en.inject(0);
    await clk.nextPosedge;

    // After second fill: occupancy=${cache.occupancy!.value.toInt()}
    expect(cache.occupancy!.value.toInt(), equals(2),
        reason: 'Should have 2 entries after second fill');

    // Verify both reads work correctly
    readIntf.en.inject(1);
    readIntf.addr.inject(0x10);
    await clk.nextPosedge;
    expect(readIntf.valid.value.toBool(), isTrue,
        reason: 'Read 0x10 should still be valid after second fill');
    expect(readIntf.data.value.toInt(), equals(0xAA),
        reason: 'Read 0x10 should still return correct data');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    readIntf.en.inject(1);
    readIntf.addr.inject(0x20);
    await clk.nextPosedge;
    expect(readIntf.valid.value.toBool(), isTrue,
        reason: 'Read 0x20 should be valid');
    expect(readIntf.data.value.toInt(), equals(0xBB),
        reason: 'Read 0x20 should return correct data');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Check final occupancy - this is verified by the final expect at the end

    // The bug: If the second fill overwrote the first, we'll see:
    // - occupancy = 1 instead of 2
    // - reading 0x10 returns wrong data or miss

    expect(cache.occupancy!.value.toInt(), equals(2),
        reason: 'Should have 2 entries, not ${cache.occupancy!.value.toInt()}');

    await Simulator.endSimulation();
  });
}
