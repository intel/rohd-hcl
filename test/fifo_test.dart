//
// fifo_test.dart
// Tests for FIFO
//
// Author: Max Korbel
// 2023 March 13
//

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('fifo simple', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);

    final wrEn = Logic()..put(0);
    final rdEn = Logic()..put(0);
    final wrData = Logic(width: 32);

    final fifo = Fifo(
      clk,
      reset,
      writeEnable: wrEn,
      readEnable: rdEn,
      writeData: wrData,
      depth: 3,
    );

    final rdData = fifo.readData;

    await fifo.build();

    Future<void> checkThat({required bool empty, required bool full}) async {
      await clk.nextPosedge;
      expect(fifo.empty.value.toBool(), empty);
      expect(fifo.full.value.toBool(), full);
    }

    unawaited(Simulator.run());

    // a little reset flow
    await clk.nextNegedge;
    reset.put(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.put(0);
    await clk.nextNegedge;
    await clk.nextNegedge;

    // this test, we don't expect any errors, check every negedge
    clk.negedge.listen((event) {
      // do it 1 timestamp after since this TB drives after edges
      Simulator.registerAction(
          Simulator.time + 1, () => expect(fifo.error.value.toBool(), false));
    });

    await checkThat(empty: true, full: false);

    await clk.nextNegedge;

    // push a few things in, checking empty and full
    wrEn.put(1);
    wrData.put(0xa);

    await checkThat(empty: false, full: false);

    await clk.nextNegedge;

    wrData.put(0xb);

    await clk.nextNegedge;

    wrData.put(0xc);

    await checkThat(empty: false, full: true);

    await clk.nextNegedge;

    wrEn.put(0);

    // pop them out and check they match
    await clk.nextNegedge;

    rdEn.put(1);
    expect(rdData.value.toInt(), 0xa);

    await checkThat(empty: false, full: false);

    await clk.nextNegedge;

    expect(rdData.value.toInt(), 0xb);

    await clk.nextNegedge;

    expect(rdData.value.toInt(), 0xc);

    await checkThat(empty: true, full: false);

    await clk.nextNegedge;

    rdEn.put(0);

    await checkThat(empty: true, full: false);

    await clk.nextNegedge;

    Simulator.endSimulation();
    await Simulator.simulationEnded;
  });

  test('fifo err', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);

    final wrEn = Logic()..put(0);
    final rdEn = Logic()..put(0);
    final wrData = Logic(width: 32);

    final fifo = Fifo(
      clk,
      reset,
      writeEnable: wrEn,
      readEnable: rdEn,
      writeData: wrData,
      depth: 3,
    );

    await fifo.build();

    unawaited(Simulator.run());

    // a little reset flow
    await clk.nextNegedge;
    reset.put(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.put(0);
    await clk.nextNegedge;
    await clk.nextNegedge;

    wrEn.put(1);
    wrData.put(0xdead);

    expect(fifo.error.value.toBool(), false);

    await clk.nextPosedge;
    expect(fifo.error.value.toBool(), false);
    await clk.nextPosedge;
    expect(fifo.error.value.toBool(), false);
    await clk.nextPosedge;
    expect(fifo.error.value.toBool(), true);
    await clk.nextPosedge;

    Simulator.endSimulation();
    await Simulator.simulationEnded;
  });

  test('fifo bypass', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);

    final wrEn = Logic()..put(0);
    final rdEn = Logic()..put(0);
    final wrData = Logic(width: 32);

    final fifo = Fifo(
      clk,
      reset,
      writeEnable: wrEn,
      readEnable: rdEn,
      writeData: wrData,
      depth: 3,
    );

    final rdData = fifo.readData;

    await fifo.build();

    unawaited(Simulator.run());

    // a little reset flow
    await clk.nextNegedge;
    reset.put(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.put(0);
    await clk.nextNegedge;
    await clk.nextNegedge;

    wrEn.put(1);
    wrData.put(0xfeedbeef);
    rdEn.put(1);

    expect(rdData.value.toInt(), 0xfeedbeef);

    await clk.nextNegedge;

    expect(rdData.value.toInt(), 0xfeedbeef);

    await clk.nextNegedge;

    Simulator.endSimulation();
    await Simulator.simulationEnded;
  });
}
