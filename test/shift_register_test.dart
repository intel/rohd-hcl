// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// shift_register_test.dart
// Tests for shift register
//
// 2023 September 21
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('simple shift register', () async {
    final dataIn = Logic(width: 8);
    final clk = SimpleClockGenerator(10).clk;
    const latency = 5;
    final sr = ShiftRegister(dataIn, clk: clk, depth: latency);
    final dataOut = sr.dataOut;
    final data3 = sr.stages[2];

    final data = [for (var i = 0; i < 20; i++) i * 3];

    unawaited(Simulator.run());

    for (final dataI in data) {
      dataIn.put(dataI);
      unawaited(clk
          .waitCycles(latency)
          .then((value) => expect(dataOut.value.toInt(), dataI)));

      unawaited(clk
          .waitCycles(3)
          .then((value) => expect(data3.value.toInt(), dataI)));

      await clk.nextPosedge;
    }

    await clk.waitCycles(latency);

    expect(dataOut.value.toInt(), data.last);

    Simulator.endSimulation();

    await Simulator.simulationEnded;
  });

  test('shift register naming', () {
    final sr =
        ShiftRegister(Logic(), clk: Logic(), depth: 3, dataName: 'fancy');
    expect(sr.name, contains('fancy'));
    expect(sr.dataOut.name, contains('fancy'));
    expect(
        // ignore: invalid_use_of_protected_member
        sr.inputs.keys.where((element) => element.contains('fancy')).length,
        1);
  });

  test('depth 0 shift register is pass-through', () {
    final dataIn = Logic(width: 8);
    final clk = Logic();
    const latency = 0;
    final dataOut = ShiftRegister(dataIn, clk: clk, depth: latency).dataOut;

    dataIn.put(0x23);
    expect(dataOut.value.toInt(), 0x23);
  });

  test('width 0 constructs properly', () {
    expect(ShiftRegister(Logic(width: 0), clk: Logic(), depth: 9).dataOut.width,
        0);
  });

  test('enabled shift register', () async {
    final dataIn = Logic(width: 8);
    final clk = SimpleClockGenerator(10).clk;
    const latency = 5;
    final enable = Logic();
    final dataOut =
        ShiftRegister(dataIn, clk: clk, depth: latency, enable: enable).dataOut;

    unawaited(Simulator.run());

    enable.put(true);
    dataIn.put(0x45);

    await clk.nextPosedge;
    dataIn.put(0);

    await clk.waitCycles(2);

    enable.put(false);

    await clk.waitCycles(20);

    enable.put(true);

    expect(dataOut.value.isValid, isFalse);

    await clk.waitCycles(2);

    expect(dataOut.value.toInt(), 0x45);

    await clk.nextPosedge;

    expect(dataOut.value.toInt(), 0);

    Simulator.endSimulation();

    await Simulator.simulationEnded;
  });

  group('reset shift register', () {
    Future<void> resetTest(
        dynamic resetVal, void Function(Logic dataOut) check) async {
      final dataIn = Logic(width: 8);
      final clk = SimpleClockGenerator(10).clk;
      const latency = 5;
      final reset = Logic();
      final dataOut = ShiftRegister(dataIn,
              clk: clk, depth: latency, reset: reset, resetValue: resetVal)
          .dataOut;

      unawaited(Simulator.run());

      dataIn.put(0x45);
      reset.put(true);

      await clk.nextPosedge;

      check(dataOut);

      reset.put(false);

      await clk.waitCycles(2);

      check(dataOut);

      await clk.waitCycles(3);

      expect(dataOut.value.toInt(), 0x45);

      Simulator.endSimulation();

      await Simulator.simulationEnded;
    }

    test('null reset value', () async {
      await resetTest(null, (dataOut) {
        expect(dataOut.value.toInt(), 0);
      });
    });

    test('constant reset value', () async {
      await resetTest(0x56, (dataOut) {
        expect(dataOut.value.toInt(), 0x56);
      });
    });

    test('logic reset value', () async {
      await resetTest(Const(0x78, width: 8), (dataOut) {
        expect(dataOut.value.toInt(), 0x78);
      });
    });
  });

  test('enabled and reset shift register', () async {
    final dataIn = Logic(width: 8);
    final clk = SimpleClockGenerator(10).clk;
    const latency = 5;
    final enable = Logic();
    final reset = Logic();
    final dataOut = ShiftRegister(dataIn,
            clk: clk, depth: latency, enable: enable, reset: reset)
        .dataOut;

    unawaited(Simulator.run());

    enable.put(true);
    dataIn.put(0x45);
    reset.put(true);

    await clk.nextPosedge;
    reset.put(false);

    await clk.nextPosedge;

    dataIn.put(0);

    await clk.waitCycles(2);

    enable.put(false);

    await clk.waitCycles(20);

    enable.put(true);

    expect(dataOut.value.toInt(), 0);

    await clk.waitCycles(2);

    expect(dataOut.value.toInt(), 0x45);

    await clk.nextPosedge;

    expect(dataOut.value.toInt(), 0);

    Simulator.endSimulation();

    await Simulator.simulationEnded;
  });
}
