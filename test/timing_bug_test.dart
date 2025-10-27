import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('timing bug: readWithInvalidate interference with fill operations',
      () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    final readIntf = ValidDataPortInterface(8, 8, hasReadWithInvalidate: true);
    final fillIntf = ValidDataPortInterface(8, 8);

    // Create a 2-way cache with address/data width 8
    final cache = FullyAssociativeCache(
      clk,
      reset,
      [fillIntf],
      [readIntf],
      ways: 2,
      generateOccupancy: true,
    );

    await cache.build();

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    reset.inject(1);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextPosedge;
    await clk.nextPosedge; // Give time for reset to propagate

    print('=== Testing timing bug scenario ===');

    // Wait for everything to stabilize
    await clk.nextPosedge;
    await clk.nextPosedge;

    // Cycle 1: Fill address 0x100 with data 0xaa, and do readWithInvalidate
    // (which should miss)
    fillIntf.addr.inject(0x100);
    fillIntf.data.inject(0xaa);
    fillIntf.valid.inject(1);
    fillIntf.en.inject(1);

    readIntf.addr
        .inject(0x100); // This will miss, but sets up readWithInvalidate
    readIntf.en.inject(1);
    readIntf.readWithInvalidate.inject(1);

    await clk.nextPosedge;
    print('After cycle 1: fill should have succeeded');

    // Stop the readWithInvalidate and fill
    fillIntf.en.inject(0);
    readIntf.en.inject(0);
    readIntf.readWithInvalidate.inject(0);

    await clk.nextPosedge;
    print('After cycle 2: (cleanup)');

    // Cycle 3: Fill address 0x200 with data 0xbb (should use way 1)
    fillIntf.addr.inject(0x200);
    fillIntf.data.inject(0xbb);
    fillIntf.valid.inject(1);
    fillIntf.en.inject(1);

    await clk.nextPosedge;
    print('After cycle 3: second fill completed');

    fillIntf.en.inject(0);
    await clk.nextPosedge;

    // Read back both addresses to check if data is correct
    readIntf.addr.inject(0x100);
    readIntf.en.inject(1);
    await clk.nextPosedge;
    final read100Valid = readIntf.valid.value;
    final read100Data = readIntf.data.value;
    readIntf.en.inject(0);

    await clk.nextPosedge;

    readIntf.addr.inject(0x200);
    readIntf.en.inject(1);
    await clk.nextPosedge;
    final read200Valid = readIntf.valid.value;
    final read200Data = readIntf.data.value;
    readIntf.en.inject(0);

    print('Read 0x100: valid=$read100Valid, '
        'data=0x${read100Data.toInt().toRadixString(16)}');
    print('Read 0x200: valid=$read200Valid, '
        'data=0x${read200Data.toInt().toRadixString(16)}');

    // Final occupancy check
    await clk.nextPosedge;
    if (cache.occupancy!.value.isValid) {
      print('Final occupancy: ${cache.occupancy!.value}');

      // The bug: If readWithInvalidate interferes, we'll see:
      // - occupancy stays at 1 instead of 2
      // - one of the reads will return wrong data (overwritten)

      if (cache.occupancy!.value.toInt() == 1) {
        print('BUG CONFIRMED: occupancy is 1, should be 2');
        print('This indicates readWithInvalidate interfered with fill '
            'operations');
      } else {
        print('No bug detected, occupancy is correct');
      }
    } else {
      print('Occupancy not valid, checking data integrity instead');
    }

    if (read100Data.toInt() != 0xaa) {
      print('BUG CONFIRMED: address 0x100 data is '
          '0x${read100Data.toInt().toRadixString(16)}, should be 0xaa');
    }

    if (read200Data.toInt() != 0xbb) {
      print('BUG CONFIRMED: address 0x200 data is '
          '0x${read200Data.toInt().toRadixString(16)}, should be 0xbb');
    }

    await Simulator.endSimulation();
  });
}
