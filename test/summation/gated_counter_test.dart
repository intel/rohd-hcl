import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/summation/gated_counter.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';
import '../edge_detector_test.dart';
import 'sum_test.dart';

Future<void> checkCounter(Counter counter) async {
  // ignore: invalid_use_of_protected_member
  counter.clk.posedge.listen((_) async {
    final expected = counter.reset.value.toBool()
        ? 0
        : goldenSum(
            // ignore: invalid_use_of_protected_member
            counter.interfaces,
            width: counter.width,
            initialValue: counter.count.value.toInt(),
          );

    // ignore: invalid_use_of_protected_member
    await counter.clk.nextPosedge;

    final actual = counter.count.value.toInt();

    // expect(actual, expected);
  });
}

void main() {
  test('simple 1-counter incrementing always', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..inject(1);
    final dut = GatedCounter([SumInterface(fixedAmount: 1)],
        clk: clk, reset: reset, width: 4, clkGatePartitionIndex: 2);

    await dut.build();

    unawaited(checkCounter(dut));

    WaveDumper(dut);

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    await clk.waitCycles(3);
    reset.inject(0);

    await clk.waitCycles(50);

    await Simulator.endSimulation();
  });
}
