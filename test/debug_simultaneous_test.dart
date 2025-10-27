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

    WaveDumper(cache, outputPath: 'debug_simultaneous.vcd');

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

    print('=== Debug Simultaneous Operations ===');

    // Fill to capacity
    print('Initial: occupancy=${cache.occupancy!.value.toInt()}, '
        'full=${cache.full!.value}');

    // Fill first entry
    print('Fill 0x10...');
    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(0x10);
    fillIntf.data.inject(0xA0);
    await clk.nextPosedge;

    fillIntf.en.inject(0);
    await clk.nextPosedge;
    print('After fill 0x10: occupancy=${cache.occupancy!.value.toInt()}, '
        'full=${cache.full!.value}');

    // Fill second entry
    print('Fill 0x20...');
    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(0x20);
    fillIntf.data.inject(0xA1);
    await clk.nextPosedge;

    fillIntf.en.inject(0);
    await clk.nextPosedge;
    print('After fill 0x20: occupancy=${cache.occupancy!.value.toInt()}, '
        'full=${cache.full!.value}');

    // Verify both entries exist
    print('Verify 0x10 exists...');
    readIntf.en.inject(1);
    readIntf.addr.inject(0x10);
    await clk.nextPosedge;
    print('Read 0x10: valid=${readIntf.valid.value}, '
        'data=0x${readIntf.data.value.toInt().toRadixString(16)}');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    print('Verify 0x20 exists...');
    readIntf.en.inject(1);
    readIntf.addr.inject(0x20);
    await clk.nextPosedge;
    print('Read 0x20: valid=${readIntf.valid.value}, '
        'data=0x${readIntf.data.value.toInt().toRadixString(16)}');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Now do simultaneous operations
    print(r'\nSimultaneous: Fill 0x30 + ReadWithInvalidate 0x10');
    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(0x30);
    fillIntf.data.inject(0xC0);

    readIntf.en.inject(1);
    readIntf.addr.inject(0x10);
    readIntf.readWithInvalidate.inject(1);

    await clk.nextPosedge;
    print('Simultaneous results:');
    print('- ReadWithInvalidate: valid=${readIntf.valid.value}, '
        'data=0x${readIntf.data.value.toInt().toRadixString(16)}');
    print('- Cache state: occupancy=${cache.occupancy!.value.toInt()}, '
        'full=${cache.full!.value}');

    fillIntf.en.inject(0);
    readIntf.en.inject(0);
    readIntf.readWithInvalidate.inject(0);
    await clk.nextPosedge;

    print('After cycle: occupancy=${cache.occupancy!.value.toInt()}, '
        'full=${cache.full!.value}');

    // Test what entries exist now
    final testAddresses = [0x10, 0x20, 0x30];
    for (final addr in testAddresses) {
      readIntf.en.inject(1);
      readIntf.addr.inject(addr);
      await clk.nextPosedge;

      final valid = readIntf.valid.value.toBool();
      final data = valid ? readIntf.data.value.toInt() : 0;
      print('Test 0x${addr.toRadixString(16)}: '
          'valid=$valid${valid ? ", data=0x${data.toRadixString(16)}" : ""}');

      readIntf.en.inject(0);
      await clk.nextPosedge;
    }

    await Simulator.endSimulation();
  });
}
