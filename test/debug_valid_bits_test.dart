// Debug test for valid bits
import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('debug valid bits and occupancy', () async {
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

    WaveDumper(cache, outputPath: 'debug_valid_bits.vcd');

    Simulator.setMaxSimTime(300);
    unawaited(Simulator.run());

    // Reset
    reset.inject(1);
    readIntf.en.inject(0);
    fillIntf.en.inject(0);
    fillIntf.valid.inject(0);
    await clk.waitCycles(2);

    reset.inject(0);
    await clk.waitCycles(1);

    print('=== Debug Valid Bits ===');
    print('Initial occupancy: ${cache.occupancy!.value.toInt()}');

    // Fill first entry (back to the problem addresses)
    print('Fill first entry (0x100)...');
    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(0x100);
    fillIntf.data.inject(0xAA);
    await clk.nextPosedge;

    fillIntf.en.inject(0);
    await clk.nextPosedge;

    print('After first fill: occupancy=${cache.occupancy!.value.toInt()}');

    // Test read (ensure readWithInvalidate is 0)
    readIntf.en.inject(1);
    readIntf.addr.inject(0x100);
    readIntf.readWithInvalidate.inject(0);
    await clk.nextPosedge;
    print('Read 0x100: valid=${readIntf.valid.value}, '
        'data=0x${readIntf.data.value.toInt().toRadixString(16)}');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Fill second entry
    print('Fill second entry (0x200)...');
    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(0x200);
    fillIntf.data.inject(0xBB);
    await clk.nextPosedge;

    fillIntf.en.inject(0);
    await clk.nextPosedge;

    print('After second fill: occupancy=${cache.occupancy!.value.toInt()}');

    // Test read second entry
    readIntf.en.inject(1);
    readIntf.addr.inject(0x200);
    readIntf.readWithInvalidate.inject(0);
    await clk.nextPosedge;
    print('Read 0x200: valid=${readIntf.valid.value}, '
        'data=0x${readIntf.data.value.toInt().toRadixString(16)}');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Test read first entry again
    readIntf.en.inject(1);
    readIntf.addr.inject(0x100);
    readIntf.readWithInvalidate.inject(0);
    await clk.nextPosedge;
    print('Read 0x100 again: valid=${readIntf.valid.value}, '
        'data=0x${readIntf.data.value.toInt().toRadixString(16)}');
    readIntf.en.inject(0);
    await clk.nextPosedge;

    await Simulator.endSimulation();
  });
}
