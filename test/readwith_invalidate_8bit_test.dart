import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('readWithInvalidate with proper 8-bit addresses', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    final readIntf = ValidDataPortInterface(8, 8, hasReadWithInvalidate: true);
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

    // Initialize properly
    fillIntf.en.inject(0);
    fillIntf.valid.inject(0);
    fillIntf.addr.inject(0);
    fillIntf.data.inject(0);
    readIntf.en.inject(0);
    readIntf.addr.inject(0);
    readIntf.readWithInvalidate.inject(0);
    reset.inject(0);
    await clk.nextPosedge;
    await clk.nextPosedge;

    reset.inject(1);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextPosedge;
    await clk.nextPosedge;

    // Wait for occupancy to stabilize
    var cycles = 0;
    while (!cache.occupancy!.value.isValid && cycles < 10) {
      await clk.nextPosedge;
      cycles++;
    }

    print('=== ReadWithInvalidate Test with Proper 8-bit Addresses ===');

    // Fill two entries
    const addr1 = 0x10;
    const addr2 = 0x20;

    print('Filling two entries...');

    // Fill first entry
    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(addr1);
    fillIntf.data.inject(0xAA);
    await clk.nextPosedge;
    fillIntf.en.inject(0);
    await clk.nextPosedge;

    // Fill second entry
    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(addr2);
    fillIntf.data.inject(0xBB);
    await clk.nextPosedge;
    fillIntf.en.inject(0);
    await clk.nextPosedge;

    if (cache.occupancy!.value.isValid) {
      print('Occupancy after filling 2 entries: '
          '${cache.occupancy!.value.toInt()}');
      expect(cache.occupancy!.value.toInt(), equals(2));
    }

    // Test simultaneous fill + readWithInvalidate (the key test case)
    print('\nTesting simultaneous fill + readWithInvalidate...');
    print('This should fill addr2=0x30 while invalidating addr1=0x10');

    // Simultaneous operations: fill new entry while invalidating existing entry
    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(0x30); // New address
    fillIntf.data.inject(0xCC);

    readIntf.en.inject(1);
    readIntf.addr.inject(addr1); // Read existing address 0x10
    readIntf.readWithInvalidate.inject(1); // And invalidate it

    await clk.nextPosedge;

    // Stop operations
    fillIntf.en.inject(0);
    readIntf.en.inject(0);
    readIntf.readWithInvalidate.inject(0);
    await clk.nextPosedge;

    // Check results
    if (cache.occupancy!.value.isValid) {
      final occupancy = cache.occupancy!.value.toInt();
      print('Occupancy after simultaneous operation: $occupancy');
      // Should still be 2: added 0x30, but invalidated 0x10
      expect(occupancy, equals(2),
          reason: 'Occupancy should remain 2 (add one, invalidate one)');
    }

    // Verify addr1 (0x10) is now invalid
    readIntf.en.inject(1);
    readIntf.addr.inject(addr1);
    await clk.nextPosedge;
    final addr1Hit = readIntf.valid.value.toInt();
    readIntf.en.inject(0);
    await clk.nextPosedge;

    print('Read invalidated address 0x10: hit=$addr1Hit (should be 0)');
    expect(addr1Hit, equals(0), reason: 'Invalidated address should miss');

    // Verify addr2 (0x20) is still valid
    readIntf.en.inject(1);
    readIntf.addr.inject(addr2);
    await clk.nextPosedge;
    final addr2Hit = readIntf.valid.value.toInt();
    final addr2Data = readIntf.data.value.toInt();
    readIntf.en.inject(0);
    await clk.nextPosedge;

    print('Read untouched address 0x20: hit=$addr2Hit, '
        'data=0x${addr2Data.toRadixString(16)}');
    expect(addr2Hit, equals(1), reason: 'Untouched address should still hit');
    expect(addr2Data, equals(0xBB), reason: 'Should return original data');

    // Verify new addr3 (0x30) is valid
    readIntf.en.inject(1);
    readIntf.addr.inject(0x30);
    await clk.nextPosedge;
    final addr3Hit = readIntf.valid.value.toInt();
    final addr3Data = readIntf.data.value.toInt();
    readIntf.en.inject(0);
    await clk.nextPosedge;

    print('Read new address 0x30: hit=$addr3Hit, '
        'data=0x${addr3Data.toRadixString(16)}');
    expect(addr3Hit, equals(1), reason: 'New address should hit');
    expect(addr3Data, equals(0xCC), reason: 'Should return new data');

    print('\n✅ ReadWithInvalidate working correctly with '
        'simultaneous operations!');
    await Simulator.endSimulation();
  });
}
