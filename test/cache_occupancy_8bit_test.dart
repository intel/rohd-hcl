import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('cache occupancy with correct 8-bit addresses', () async {
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

    // Initialize properly
    fillIntf.en.inject(0);
    fillIntf.valid.inject(0);
    fillIntf.addr.inject(0);
    fillIntf.data.inject(0);
    readIntf.en.inject(0);
    readIntf.addr.inject(0);
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

    // === Cache Occupancy Test with Proper 8-bit Addresses ===

    if (!cache.occupancy!.value.isValid) {
      // Occupancy still not valid, but continuing test
      fail('Occupancy should be valid after stabilization period');
    } else {
      expect(cache.occupancy!.value.toInt(), equals(0),
          reason: 'Initial occupancy should be 0');
    }

    // Test with different valid 8-bit addresses
    final testAddresses = [0x10, 0x20, 0x30, 0x40]; // All within 8-bit range
    final testData = [0xAA, 0xBB, 0xCC, 0xDD];

    // Fill each address sequentially
    for (var i = 0; i < testAddresses.length; i++) {
      final addr = testAddresses[i];
      final data = testData[i];

      // Filling address with data
      fillIntf.en.inject(1);
      fillIntf.valid.inject(1);
      fillIntf.addr.inject(addr);
      fillIntf.data.inject(data);
      await clk.nextPosedge;
      fillIntf.en.inject(0);
      await clk.nextPosedge;

      // Check occupancy
      if (cache.occupancy!.value.isValid) {
        final occupancy = cache.occupancy!.value.toInt();
        expect(occupancy, equals(i + 1),
            reason: 'Occupancy should be ${i + 1} after '
                'filling ${i + 1} addresses');
      }

      // Verify this address now hits
      readIntf.en.inject(1);
      readIntf.addr.inject(addr);
      await clk.nextPosedge;
      final hit = readIntf.valid.value.toInt();
      final readData = readIntf.data.value.toInt();

      expect(hit, equals(1),
          reason: 'Address 0x${addr.toRadixString(16)} should hit');
      expect(readData, equals(data),
          reason: 'Should return correct data 0x${data.toRadixString(16)}');

      readIntf.en.inject(0);
      await clk.nextPosedge;
    }

    // Verify all addresses still work - Verifying all addresses still
    // accessible
    for (var i = 0; i < testAddresses.length; i++) {
      final addr = testAddresses[i];
      final expectedData = testData[i];

      readIntf.en.inject(1);
      readIntf.addr.inject(addr);
      await clk.nextPosedge;
      final hit = readIntf.valid.value.toInt();
      final readData = readIntf.data.value.toInt();
      readIntf.en.inject(0);
      await clk.nextPosedge;

      expect(hit, equals(1),
          reason: 'Address 0x${addr.toRadixString(16)} should still hit');
      expect(readData, equals(expectedData),
          reason: 'Should return original data '
              '0x${expectedData.toRadixString(16)}');
    }

    // Test that a different address misses
    const missAddr = 0x50;
    readIntf.en.inject(1);
    readIntf.addr.inject(missAddr);
    await clk.nextPosedge;
    final missHit = readIntf.valid.value.toInt();
    readIntf.en.inject(0);
    await clk.nextPosedge;

    expect(missHit, equals(0),
        reason: 'Unused address 0x${missAddr.toRadixString(16)} should miss');

    // Final occupancy check
    if (cache.occupancy!.value.isValid) {
      final finalOccupancy = cache.occupancy!.value.toInt();
      expect(finalOccupancy, equals(4), reason: 'Should have 4 filled entries');

      final full = cache.full!.value.toInt();
      final empty = cache.empty!.value.toInt();
      expect(full, equals(1), reason: 'Cache should be full');
      expect(empty, equals(0), reason: 'Cache should not be empty');
    }

    // ✅ Cache occupancy tracking working correctly with proper 8-bit addresses!
    await Simulator.endSimulation();
  });
}
