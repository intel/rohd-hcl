import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('debug replacement policy allocation', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    // Create a simple replacement policy to test allocation behavior
    final hits = [AccessInterface(4)]; // Need at least one
    final allocs = [AccessInterface(4)];
    final invalidates = <AccessInterface>[];

    final replacement =
        PseudoLRUReplacement(clk, reset, hits, allocs, invalidates, ways: 4);

    await replacement.build();
    unawaited(Simulator.run());

    // Initialize all signals first (like the working test)
    hits[0].access.inject(0);
    hits[0].way.inject(0);
    allocs[0].access.inject(0);
    allocs[0].way.inject(0);
    reset.inject(0);
    await clk.nextPosedge;
    await clk.nextPosedge;

    reset.inject(1);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextPosedge;
    await clk.nextPosedge; // End reset flow

    print('=== Replacement Policy Test ===');

    // Test multiple allocations in sequence - keep access high and read each
    // cycle,
    allocs[0].access.inject(1);
    for (var i = 0; i < 8; i++) {
      await clk.nextPosedge;
      if (allocs[0].way.value.isValid) {
        final way = allocs[0].way.value.toInt();
        print('Allocation $i: way = $way');
      } else {
        print('Allocation $i: way = INVALID');
      }
    }
    allocs[0].access.inject(0);

    await Simulator.endSimulation();
  });
}
