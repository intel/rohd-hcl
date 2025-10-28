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

    // === Hit Detection Debug ===

    // Test 1: Check if cache is initially empty
    readIntf.en.inject(1);
    readIntf.addr.inject(0x100);
    await clk.nextPosedge;
    final initialHit = readIntf.valid.value.toInt();
    expect(initialHit, equals(0),
        reason: 'Initial read 0x100 should miss (cache empty)');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Test 2: Fill first entry and verify hit
    // Filling 0x100 with 0xAA...
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
    expect(afterFillHit, equals(1),
        reason: 'After first fill, read 0x100 should hit');
    expect(afterFillData, equals(0xAA),
        reason: 'After first fill, read 0x100 should return correct data');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Test 4: Check if different address misses
    readIntf.en.inject(1);
    readIntf.addr.inject(0x200);
    await clk.nextPosedge;
    final differentAddrHit = readIntf.valid.value.toInt();
    expect(differentAddrHit, equals(0),
        reason: 'Different address 0x200 should miss');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Test 5: Now fill the second entry - this is where the bug happens
    // Filling 0x200 with 0xBB...
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
    expect(addr100Hit, equals(1),
        reason: 'After second fill, read 0x100 should still hit');
    expect(addr100Data, equals(0xAA),
        reason: 'After second fill, read 0x100 should still '
            'return correct data');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    readIntf.en.inject(1);
    readIntf.addr.inject(0x200);
    await clk.nextPosedge;
    final addr200Hit = readIntf.valid.value.toInt();
    final addr200Data = readIntf.data.value.toInt();
    expect(addr200Hit, equals(1),
        reason: 'After second fill, read 0x200 should hit');
    expect(addr200Data, equals(0xBB),
        reason: 'After second fill, read 0x200 should return correct data');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Analysis - Both entries should be working correctly
    // The individual expects above already validate the behavior

    await Simulator.endSimulation();
  });
}
