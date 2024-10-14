// SPDX-License-Identifier: BSD-3-Clause
//
// linear_feedback_shift_register_test.dart
// Tests for linear feedback shift register
//
// 2024 October 1
// Author: Omonefe Itietie <omonefe.itietie@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/linear_feedback_shift_register.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });
  test('Test LFSR creation', () async {
    final dataIn = Logic(width: 4)..put(bin('1000')); // initial state
    final clk = SimpleClockGenerator(6).clk;
    final state = Logic(width: 4)..put(bin('1000'));
    const shifts = 6;
    final taps = Logic(width: 4)..put(bin('1010')); // tap positions
    final lfsr = LinearFeedbackShiftRegister(dataIn,
        clk: clk, state: state, shifts: shifts, taps: taps);

    final dataOut = lfsr.dataOut;

    await lfsr.build();

    final expectedData = [8, 12, 6, 3, 9, 4, 2, 1];

    unawaited(Simulator.run());
    await clk.waitCycles(5);

    for (var i = 0; i < expectedData.length; i++) {
      unawaited(clk
          .waitCycles(1)
          .then((value) => expect(dataOut.value.toInt(), expectedData[i])));
    }

    await Simulator.endSimulation();
  });

  test('Test LFSR naming', () async {
    final lfsr = LinearFeedbackShiftRegister(Logic(),
        clk: Logic(),
        state: Logic(),
        shifts: 2,
        taps: Logic(),
        dataName: 'test');

    expect(lfsr.name, contains('test'));
    expect(lfsr.dataOut.name, contains('test'));
    expect(
        // ignore: invalid_use_of_protected_member
        lfsr.inputs.keys.where((element) => element.contains('test')).length,
        1);
  });

  test('Test LFSR with 0 initial state and 0 taps returns as 0', () async {
    final dataIn = Logic(width: 4)..put(bin('0000')); // initial state
    final clk = SimpleClockGenerator(6).clk;
    final state = Logic(width: 4)..put(bin('0000'));
    const shifts = 6;
    final taps = Logic(width: 4)..put(bin('0000')); // tap positions
    final lfsr = LinearFeedbackShiftRegister(dataIn,
        clk: clk, state: state, shifts: shifts, taps: taps);

    final dataOut = lfsr.dataOut;

    await lfsr.build();

    final expectedData = [0, 0, 0, 0];

    unawaited(Simulator.run());
    await clk.waitCycles(5);

    for (var i = 0; i < expectedData.length; i++) {
      unawaited(clk
          .waitCycles(1)
          .then((value) => expect(dataOut.value.toInt(), expectedData[i])));
    }

    await Simulator.endSimulation();
  });

  test('Test LFSR with enable signal and reset', () async {
    final dataIn = Logic(width: 4)..put(bin('1110'));
    final clk = SimpleClockGenerator(6).clk;
    final state = Logic(width: 4)..put(bin('1110'));
    final enable = Logic(); // Create the enable signal
    final reset = Logic(); // Create a reset signal
    const shifts = 6;
    final taps = Logic(width: 4)..put(bin('1010'));

    final lfsr = LinearFeedbackShiftRegister(dataIn,
        clk: clk,
        state: state,
        shifts: shifts,
        taps: taps,
        enable: enable,
        reset: reset);

    final dataOut = lfsr.dataOut;

    await lfsr.build();

    final expectedData = [0, 0, 0, 0, 0, 14];

    unawaited(Simulator.run());

    // Apply reset
    reset.put(1);
    await clk.nextPosedge; // Wait for reset to propagate
    reset.put(0); // Remove reset

    // Apply enable
    enable.put(1);

    for (var i = 0; i < expectedData.length; i++) {
      await clk.nextPosedge;
      expect(
          dataOut.value.toInt(), expectedData[i]); // Check output when enabled
    }

    await Simulator.endSimulation();
  });

  test('Test LFSR with reset value', () async {
    final dataIn = Logic(width: 4)..put(bin('1010'));
    final clk = SimpleClockGenerator(6).clk;
    final state = Logic(width: 4)..put(bin('1010'));
    final reset = Logic(); // Create a reset signal
    const shifts = 6;
    final taps = Logic(width: 4)..put(bin('1000'));

    final lfsr = LinearFeedbackShiftRegister(dataIn,
        clk: clk, state: state, shifts: shifts, taps: taps, reset: reset);

    final dataOut = lfsr.dataOut;

    await lfsr.build();

    final expectedData = [0, 0, 0, 0, 0, 0, 0];

    unawaited(Simulator.run());

    // Apply reset
    reset.put(1);
    await clk.nextPosedge; // Wait for reset to propagate

    for (var i = 0; i < expectedData.length; i++) {
      await clk.nextPosedge;
      expect(
          dataOut.value.toInt(), expectedData[i]); // Check output when enabled
    }

    await Simulator.endSimulation();
  });

  test('Test Enabled LFSR', () async {
    final dataIn = Logic(width: 4)..put(bin('1110'));
    final clk = SimpleClockGenerator(6).clk;
    final state = Logic(width: 4)..put(bin('1110'));
    final enable = Logic(); // Create the enable signal
    const shifts = 6;
    final taps = Logic(width: 4)..put(bin('1110'));

    final lfsr = LinearFeedbackShiftRegister(dataIn,
        clk: clk, state: state, shifts: shifts, taps: taps, enable: enable);

    final dataOut = lfsr.dataOut;

    await lfsr.build();

    final expectedData = [14, 7, 12, 6, 3];

    unawaited(Simulator.run());

    // Apply enable
    enable.put(1);
    await clk.waitCycles(5);

    for (var i = 0; i < expectedData.length; i++) {
      unawaited(clk
          .waitCycles(1)
          .then((value) => expect(dataOut.value.toInt(), expectedData[i])));
    }

    await Simulator.endSimulation();
  });
}
