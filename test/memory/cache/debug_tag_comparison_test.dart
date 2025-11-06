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

    // === Tag Storage and Comparison Test === Testing whether unique addresses
    // 0x100 and 0x200 are properly distinguished

    // Test with different address patterns to see if there's a pattern
    final testCases = [
      {'addr1': 0x10, 'addr2': 0x20, 'name': '0x10 vs 0x20'},
      {'addr1': 0x30, 'addr2': 0x40, 'name': '0x30 vs 0x40'},
      {'addr1': 0x01, 'addr2': 0x02, 'name': '0x01 vs 0x02'},
      {'addr1': 0x80, 'addr2': 0x40, 'name': '0x80 vs 0x40'},
    ];

    for (final testCase in testCases) {
      final addr1 = testCase['addr1']! as int;
      final addr2 = testCase['addr2']! as int;
      final name = testCase['name']! as String;

      // --- Testing $name ---

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

      // Initial state verification
      expect(addr1InitialHit, equals(0),
          reason: '$name: addr1 should initially miss');
      expect(addr2InitialHit, equals(0),
          reason: '$name: addr2 should initially miss');

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
      readIntf.en.inject(0);
      await clk.nextPosedge;

      // After filling addr1 with 0xAA - verify results
      expect(addr1AfterFill, equals(1),
          reason: '$name: addr1 should hit after fill');
      expect(addr1Data, equals(0xAA),
          reason: '$name: addr1 should return 0xAA');
      expect(addr2AfterFill, equals(0),
          reason: '$name: addr2 should still miss after filling addr1');

      // Analyze results - addresses should be properly distinguished
      final correctBehavior = (addr1InitialHit == 0) &&
          (addr2InitialHit == 0) &&
          (addr1AfterFill == 1) &&
          (addr2AfterFill == 0) &&
          (addr1Data == 0xAA);

      if (!correctBehavior) {
        // Log details about the failure for debugging
        final failureReasons = <String>[];
        if (addr1InitialHit != 0) {
          failureReasons.add('addr1 should initially miss');
        }
        if (addr2InitialHit != 0) {
          failureReasons.add('addr2 should initially miss');
        }
        if (addr1AfterFill != 1) {
          failureReasons.add('addr1 should hit after fill');
        }
        if (addr2AfterFill != 0) {
          failureReasons.add('addr2 should still miss after filling addr1');
        }
        if (addr1Data != 0xAA) {
          failureReasons.add('addr1 should return 0xAA');
        }

        // This is the key bug - if addr2 hits when it shouldn't
        if (addr2AfterFill == 1) {
          fail('$name: KEY BUG - addr2 incorrectly reports hit when only '
              'addr1 was filled. '
              'This means tag comparison is broken - different addresses '
              'match the same stored tag. '
              'Failures: ${failureReasons.join(", ")}');
        } else {
          fail('$name: BUG - Addresses are not properly distinguished. '
              'Failures: ${failureReasons.join(", ")}');
        }
      }
      // If correctBehavior is true, addresses are properly distinguished

      // For the first test case, also try the second fill to see the overwrite
      // behavior.
      if (name.contains('0x10')) {
        // --- Testing second fill behavior ---

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

        // Verify both addresses working correctly after second fill
        expect(addr1Final, equals(1),
            reason: '$name: addr1 should still hit after second fill');
        expect(addr1FinalData, equals(0xAA),
            reason: '$name: addr1 should still contain 0xAA');
        expect(addr2Final, equals(1),
            reason: '$name: addr2 should hit after fill');
        expect(addr2FinalData, equals(0xBB),
            reason: '$name: addr2 should contain 0xBB');

        // Additional detailed failure analysis
        if (!(addr1Final == 1 &&
            addr1FinalData == 0xAA &&
            addr2Final == 1 &&
            addr2FinalData == 0xBB)) {
          final issues = <String>[];
          if (addr1FinalData != 0xAA) {
            issues.add('addr1 data was overwritten (should be 0xAA, '
                'got 0x${addr1FinalData.toRadixString(16)})');
          }
          if (addr2FinalData != 0xBB) {
            issues.add('addr2 data incorrect (should be 0xBB, '
                'got 0x${addr2FinalData.toRadixString(16)})');
          }
          if (addr1Final != 1) {
            issues.add('addr1 should still hit');
          }
          if (addr2Final != 1) {
            issues.add('addr2 should hit after fill');
          }
          // Note: This is a complex bug analysis, so using expect with detailed
          // message
          fail('$name: Second fill caused issues: ${issues.join(", ")}');
        }
      }
    }

    await Simulator.endSimulation();
  });

  test('verify address bit patterns are different', () {
    // Just verify that our test addresses are actually different at the bit
    // level.
    // === Address Bit Pattern Analysis ===
    final addresses = [0x10, 0x20, 0x30, 0x40, 0x01, 0x02, 0x80, 0x60];

    // Verify all addresses are unique
    expect(addresses.toSet().length, equals(addresses.length),
        reason: 'All test addresses should be unique');

    // Verify each address has distinct bit patterns
    for (var i = 0; i < addresses.length; i++) {
      for (var j = i + 1; j < addresses.length; j++) {
        expect(addresses[i], isNot(equals(addresses[j])),
            reason: 'Address 0x${addresses[i].toRadixString(16)} should differ '
                'from 0x${addresses[j].toRadixString(16)}');
      }
    }

    // These addresses should produce different tag comparisons if the
    // cache is working correctly.
  });
}
