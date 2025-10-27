// Test to verify the readWithInvalidate functionality works with a single test
// case
import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('debug readWithInvalidate', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    // Create interfaces - one with readWithInvalidate
    final readIntf = ValidDataPortInterface(8, 8, hasReadWithInvalidate: true);
    final fillIntf = ValidDataPortInterface(8, 8);

    final cache = FullyAssociativeCache(
      clk,
      reset,
      [fillIntf],
      [readIntf],
    );

    await cache.build();

    WaveDumper(cache, outputPath: 'debug_read_with_invalidate.vcd');

    Simulator.setMaxSimTime(300);
    unawaited(Simulator.run());

    // Reset
    reset.inject(1);
    readIntf.en.inject(0);
    readIntf.addr.inject(0);
    readIntf.readWithInvalidate.inject(0);
    fillIntf.en.inject(0);
    fillIntf.valid.inject(0);
    fillIntf.addr.inject(0);
    fillIntf.data.inject(0);
    await clk.waitCycles(2);

    reset.inject(0);
    await clk.waitCycles(1);

    print('=== Debug ReadWithInvalidate ===');

    // Fill
    print('Filling cache: addr=0x42, data=0xAB');
    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(0x42);
    fillIntf.data.inject(0xAB);
    await clk.nextPosedge;

    fillIntf.en.inject(0);
    await clk.nextPosedge;
    print('Fill complete');

    // Normal read first
    print('Normal read: addr=0x42');
    readIntf.en.inject(1);
    readIntf.addr.inject(0x42);
    readIntf.readWithInvalidate.inject(0);
    await clk.nextPosedge;

    print('Normal read result: valid=${readIntf.valid.value}, '
        'data=0x${readIntf.data.value.toInt().toRadixString(16)}');

    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Now try readWithInvalidate
    print('ReadWithInvalidate: addr=0x42');
    readIntf.en.inject(1);
    readIntf.addr.inject(0x42);
    readIntf.readWithInvalidate.inject(1);
    await clk.nextPosedge;

    print('ReadWithInvalidate result: valid=${readIntf.valid.value}, '
        'data=0x${readIntf.data.value.toInt().toRadixString(16)}');

    // This should hit but also invalidate
    expect(readIntf.valid.value.toBool(), isTrue,
        reason: 'ReadWithInvalidate should hit');

    readIntf.en.inject(0);
    readIntf.readWithInvalidate.inject(0);
    await clk.nextPosedge;

    // Verify invalidation worked
    print('Verification read after invalidation: addr=0x42');
    readIntf.en.inject(1);
    readIntf.addr.inject(0x42);
    await clk.nextPosedge;

    print('Verification result: valid=${readIntf.valid.value}');
    expect(readIntf.valid.value.toBool(), isFalse,
        reason: 'Should miss after invalidation');

    readIntf.en.inject(0);
    await clk.nextPosedge;

    await Simulator.endSimulation();
    print('=== Debug Complete ===');
  });
}
