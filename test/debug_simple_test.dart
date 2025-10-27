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

    reset.inject(1);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextPosedge;
    await clk.nextPosedge;
    await clk.nextPosedge;
    await clk.nextPosedge;

    print('=== Debug Valid Bit Updates ===');

    // Wait for occupancy to be valid
    var cycles = 0;
    while (!cache.occupancy!.value.isValid && cycles < 10) {
      await clk.nextPosedge;
      cycles++;
    }

    if (!cache.occupancy!.value.isValid) {
      print('ERROR: Occupancy never became valid after $cycles cycles');
      return;
    }

    print('Initial occupancy: ${cache.occupancy!.value.toInt()}');

    // Fill first entry
    print('\n1. Fill first entry (0x100)...');
    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(0x100);
    fillIntf.data.inject(0xAA);
    await clk.nextPosedge;

    fillIntf.en.inject(0);
    await clk.nextPosedge;

    print('After first fill: occupancy=${cache.occupancy!.value.toInt()}');

    // Verify read
    readIntf.en.inject(1);
    readIntf.addr.inject(0x100);
    await clk.nextPosedge;
    print('Read 0x100: valid=${readIntf.valid.value}, '
        'data=0x${readIntf.data.value.toInt().toRadixString(16)}');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Fill second entry - this should go to a different way
    print('\n2. Fill second entry (0x200)...');
    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(0x200);
    fillIntf.data.inject(0xBB);
    await clk.nextPosedge;

    fillIntf.en.inject(0);
    await clk.nextPosedge;

    print('After second fill: occupancy=${cache.occupancy!.value.toInt()}');

    // Verify both reads work correctly
    readIntf.en.inject(1);
    readIntf.addr.inject(0x100);
    await clk.nextPosedge;
    print('Read 0x100: valid=${readIntf.valid.value}, '
        'data=0x${readIntf.data.value.toInt().toRadixString(16)}');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    readIntf.en.inject(1);
    readIntf.addr.inject(0x200);
    await clk.nextPosedge;
    print('Read 0x200: valid=${readIntf.valid.value}, '
        'data=0x${readIntf.data.value.toInt().toRadixString(16)}');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Check final occupancy
    print('\nFinal occupancy: ${cache.occupancy!.value.toInt()}');

    // The bug: If the second fill overwrote the first, we'll see:
    // - occupancy = 1 instead of 2
    // - reading 0x100 returns wrong data or miss

    expect(cache.occupancy!.value.toInt(), equals(2),
        reason: 'Should have 2 entries, not ${cache.occupancy!.value.toInt()}');

    await Simulator.endSimulation();
  });
}
