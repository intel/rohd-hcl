import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('debug hit detection logic', () async {
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

    // Proper initialization sequence
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

    print('=== Hit Detection Debug ===');

    // Test 1: Check if cache is initially empty
    readIntf.en.inject(1);
    readIntf.addr.inject(0x100);
    await clk.nextPosedge;
    final initialHit = readIntf.valid.value.toInt();
    print('Initial read 0x100: hit=$initialHit (should be 0)');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Test 2: Fill first entry and verify hit
    print('\nFilling 0x100 with 0xAA...');
    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(0x100);
    fillIntf.data.inject(0xAA);
    await clk.nextPosedge;
    fillIntf.en.inject(0);
    await clk.nextPosedge;

    // Test 3: Check if first entry now hits
    readIntf.en.inject(1);
    readIntf.addr.inject(0x100);
    await clk.nextPosedge;
    final afterFillHit = readIntf.valid.value.toInt();
    final afterFillData = readIntf.data.value.toInt();
    print('After first fill, read 0x100: hit=$afterFillHit, '
        'data=0x${afterFillData.toRadixString(16)}');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Test 4: Check if different address misses
    readIntf.en.inject(1);
    readIntf.addr.inject(0x200);
    await clk.nextPosedge;
    final differentAddrHit = readIntf.valid.value.toInt();
    print('Different address 0x200: hit=$differentAddrHit (should be 0)');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Test 5: Now fill the second entry - this is where the bug happens
    print('\nFilling 0x200 with 0xBB...');
    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(0x200);
    fillIntf.data.inject(0xBB);
    await clk.nextPosedge;
    fillIntf.en.inject(0);
    await clk.nextPosedge;

    // Test 6: Check both addresses after second fill
    readIntf.en.inject(1);
    readIntf.addr.inject(0x100);
    await clk.nextPosedge;
    final addr100Hit = readIntf.valid.value.toInt();
    final addr100Data = readIntf.data.value.toInt();
    print('After second fill, read 0x100: hit=$addr100Hit, '
        'data=0x${addr100Data.toRadixString(16)} (should be hit=1, data=0xAA)');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    readIntf.en.inject(1);
    readIntf.addr.inject(0x200);
    await clk.nextPosedge;
    final addr200Hit = readIntf.valid.value.toInt();
    final addr200Data = readIntf.data.value.toInt();
    print('After second fill, read 0x200: hit=$addr200Hit, '
        'data=0x${addr200Data.toRadixString(16)} (should be hit=1, data=0xBB)');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Analysis
    if (addr100Hit == 1 &&
        addr100Data == 0xAA &&
        addr200Hit == 1 &&
        addr200Data == 0xBB) {
      print('\n✅ Both entries working correctly');
    } else {
      print('\n❌ Bug detected:');
      if (addr100Hit == 0) {
        print('  - Address 0x100 was invalidated');
      }
      if (addr100Data != 0xAA) {
        print('  - Address 0x100 data was overwritten');
      }
      if (addr200Hit == 0) {
        print('  - Address 0x200 did not get stored');
      }
      if (addr200Data != 0xBB) {
        print('  - Address 0x200 has wrong data');
      }
    }

    await Simulator.endSimulation();
  });
}
