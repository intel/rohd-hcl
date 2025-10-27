import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('debug tag storage and comparison for unique addresses', () async {
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

    print('=== Tag Storage and Comparison Test ===');
    print('Testing whether unique addresses 0x100 and 0x200 '
        'are properly distinguished');

    // Test with different address patterns to see if there's a pattern
    final testCases = [
      {'addr1': 0x100, 'addr2': 0x200, 'name': '0x100 vs 0x200'},
      {'addr1': 0x010, 'addr2': 0x020, 'name': '0x010 vs 0x020'},
      {'addr1': 0x001, 'addr2': 0x002, 'name': '0x001 vs 0x002'},
      {'addr1': 0x080, 'addr2': 0x040, 'name': '0x080 vs 0x040'},
    ];

    for (final testCase in testCases) {
      final addr1 = testCase['addr1']! as int;
      final addr2 = testCase['addr2']! as int;
      final name = testCase['name']! as String;

      print('\n--- Testing $name ---');

      // Reset cache for each test
      reset.inject(1);
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;
      await clk.nextPosedge;

      // Step 1: Verify both addresses initially miss
      readIntf.en.inject(1);
      readIntf.addr.inject(addr1);
      await clk.nextPosedge;
      final addr1InitialHit = readIntf.valid.value.toInt();
      readIntf.en.inject(0);
      await clk.nextPosedge;

      readIntf.en.inject(1);
      readIntf.addr.inject(addr2);
      await clk.nextPosedge;
      final addr2InitialHit = readIntf.valid.value.toInt();
      readIntf.en.inject(0);
      await clk.nextPosedge;

      print('  Initial state - addr1: hit=$addr1InitialHit, '
          'addr2: hit=$addr2InitialHit');

      // Step 2: Fill first address
      fillIntf.en.inject(1);
      fillIntf.valid.inject(1);
      fillIntf.addr.inject(addr1);
      fillIntf.data.inject(0xAA);
      await clk.nextPosedge;
      fillIntf.en.inject(0);
      await clk.nextPosedge;

      // Step 3: Check both addresses after first fill
      readIntf.en.inject(1);
      readIntf.addr.inject(addr1);
      await clk.nextPosedge;
      final addr1AfterFill = readIntf.valid.value.toInt();
      final addr1Data = readIntf.data.value.toInt();
      readIntf.en.inject(0);
      await clk.nextPosedge;

      readIntf.en.inject(1);
      readIntf.addr.inject(addr2);
      await clk.nextPosedge;
      final addr2AfterFill = readIntf.valid.value.toInt();
      final addr2DataIfHit = readIntf.data.value.toInt();
      readIntf.en.inject(0);
      await clk.nextPosedge;

      print('  After filling addr1 with 0xAA:');
      print('    addr1: hit=$addr1AfterFill, '
          'data=0x${addr1Data.toRadixString(16)}');
      print('    addr2: hit=$addr2AfterFill, '
          'data=0x${addr2DataIfHit.toRadixString(16)}');

      // Analyze results
      final correctBehavior = (addr1InitialHit == 0) &&
          (addr2InitialHit == 0) &&
          (addr1AfterFill == 1) &&
          (addr2AfterFill == 0) &&
          (addr1Data == 0xAA);

      if (correctBehavior) {
        print('  ✅ CORRECT: Addresses are properly distinguished');
      } else {
        print('  ❌ BUG: Addresses are not properly distinguished');
        if (addr1InitialHit != 0) {
          print('    - addr1 should initially miss');
        }
        if (addr2InitialHit != 0) {
          print('    - addr2 should initially miss');
        }
        if (addr1AfterFill != 1) {
          print('    - addr1 should hit after fill');
        }
        if (addr2AfterFill != 0) {
          print('    - addr2 should still miss after filling addr1');
        }
        if (addr1Data != 0xAA) {
          print('    - addr1 should return 0xAA');
        }

        // This is the key bug - if addr2 hits when it shouldn't
        if (addr2AfterFill == 1) {
          print('  🔍 KEY BUG: addr2 incorrectly reports hit when only addr1 '
              'was filled');
          print(
              '      This means tag comparison is broken - different addresses '
              'match the same stored tag');
        }
      }

      // For the first test case, also try the second fill to see the overwrite
      // behavior.
      if (name.contains('0x100')) {
        print('\n  --- Testing second fill behavior ---');

        // Fill second address
        fillIntf.en.inject(1);
        fillIntf.valid.inject(1);
        fillIntf.addr.inject(addr2);
        fillIntf.data.inject(0xBB);
        await clk.nextPosedge;
        fillIntf.en.inject(0);
        await clk.nextPosedge;

        // Check both addresses after second fill
        readIntf.en.inject(1);
        readIntf.addr.inject(addr1);
        await clk.nextPosedge;
        final addr1Final = readIntf.valid.value.toInt();
        final addr1FinalData = readIntf.data.value.toInt();
        readIntf.en.inject(0);
        await clk.nextPosedge;

        readIntf.en.inject(1);
        readIntf.addr.inject(addr2);
        await clk.nextPosedge;
        final addr2Final = readIntf.valid.value.toInt();
        final addr2FinalData = readIntf.data.value.toInt();
        readIntf.en.inject(0);
        await clk.nextPosedge;

        print('  After filling addr2 with 0xBB:');
        print('    addr1: hit=$addr1Final, '
            'data=0x${addr1FinalData.toRadixString(16)}');
        print('    addr2: hit=$addr2Final, '
            'data=0x${addr2FinalData.toRadixString(16)}');

        if (addr1Final == 1 &&
            addr1FinalData == 0xAA &&
            addr2Final == 1 &&
            addr2FinalData == 0xBB) {
          print('  ✅ Both addresses working correctly');
        } else {
          print('  ❌ BUG: Second fill caused issues');
          if (addr1FinalData != 0xAA) {
            print('    - addr1 data was overwritten (should be 0xAA, got '
                '0x${addr1FinalData.toRadixString(16)})');
          }
        }
      }
    }

    await Simulator.endSimulation();
  });

  test('verify address bit patterns are different', () {
    // Just verify that our test addresses are actually different at the bit
    // level.
    print('\n=== Address Bit Pattern Analysis ===');
    final addresses = [0x100, 0x200, 0x010, 0x020, 0x001, 0x002, 0x080, 0x040];

    for (var addr in addresses) {
      final binary = addr.toRadixString(2).padLeft(8, '0');
      print('0x${addr.toRadixString(16).padLeft(3, '0')} = $binary');
    }

    print('\nThese addresses should produce different tag comparisons if the '
        'cache is working correctly.');
  });
}
