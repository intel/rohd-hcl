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

    // WaveDumper(cache, outputPath: 'debug_valid_bits.vcd');

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

    // === Debug Valid Bits ===
    expect(cache.occupancy!.value.toInt(), equals(0),
        reason: 'Cache should start empty');

    // Fill first entry - use 8-bit address 0x10
    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(0x10);
    fillIntf.data.inject(0xAA);
    await clk.nextPosedge;

    fillIntf.en.inject(0);
    await clk.nextPosedge;

    expect(cache.occupancy!.value.toInt(), equals(1),
        reason: 'Occupancy should be 1 after first fill');

    // Test read (ensure readWithInvalidate is 0)
    readIntf.en.inject(1);
    readIntf.addr.inject(0x10);
    readIntf.readWithInvalidate.inject(0);
    await clk.nextPosedge;

    expect(readIntf.valid.value.toBool(), isTrue,
        reason: '0x10 should be valid after fill');
    expect(readIntf.data.value.toInt(), equals(0xAA),
        reason: '0x10 should contain data 0xAA');

    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Fill second entry - use 8-bit address 0x20
    fillIntf.en.inject(1);
    fillIntf.valid.inject(1);
    fillIntf.addr.inject(0x20);
    fillIntf.data.inject(0xBB);
    await clk.nextPosedge;

    fillIntf.en.inject(0);
    await clk.nextPosedge;

    expect(cache.occupancy!.value.toInt(), equals(2),
        reason: 'Occupancy should be 2 after second fill');

    // Test read second entry
    readIntf.en.inject(1);
    readIntf.addr.inject(0x20);
    readIntf.readWithInvalidate.inject(0);
    await clk.nextPosedge;

    expect(readIntf.valid.value.toBool(), isTrue,
        reason: '0x20 should be valid after fill');
    expect(readIntf.data.value.toInt(), equals(0xBB),
        reason: '0x20 should contain data 0xBB');

    readIntf.en.inject(0);
    await clk.nextPosedge;

    // Test read first entry again
    readIntf.en.inject(1);
    readIntf.addr.inject(0x10);
    readIntf.readWithInvalidate.inject(0);
    await clk.nextPosedge;

    expect(readIntf.valid.value.toBool(), isTrue,
        reason: '0x10 should still be valid');
    expect(readIntf.data.value.toInt(), equals(0xAA),
        reason: '0x10 should still contain data 0xAA');

    readIntf.en.inject(0);
    await clk.nextPosedge;

    await Simulator.endSimulation();
  });
}
