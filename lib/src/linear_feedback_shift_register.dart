// Copyright (C) 2023 Intel Corporation

// SPDX-License-Identifier: BSD-3-Clause

//

// linear_feedback_shift_register.dart

// Implementation of Galois Linear Feedback Shift Register.

//

// 2024 October 1

// Author: Omonefe Itietie <omonefe.itietie@intel.com>

//

import 'dart:collection';
import 'package:rohd/rohd.dart';

/// Galois Linear Feedback Shift Register
class LinearFeedbackShiftRegister extends Module {
  /// Contains polynomial size for LFSR
  final int width;

  /// Contains seed of LFSR (starting value)
  Logic state;

  /// Data names for signals
  final String dataName;

  /// Contains bit string that will be used to calculate the output
  final Logic taps;

  /// Output for shift register
  Logic get dataOut => output('${dataName}_out');

  /// The number of stages in this shift register.
  final int shifts;

  /// A [List] of [output]s where the `n`'th entry corresponds to a version of
  /// the input data after passing through `n + 1` flops.
  late final List<Logic> stages = UnmodifiableListView(
      [for (var i = 0; i < shifts; i++) output(_stageName(i))]);

  /// The name of the signal (and output pin) for the [i]th stage.
  String _stageName(int i) => '${dataName}_stage_$i';

  LinearFeedbackShiftRegister(Logic dataIn,
      {required Logic clk,
      required this.state,
      required this.shifts,
      required this.taps,
      Logic? enable,
      Logic? reset,
      dynamic resetValue,
      this.dataName = 'data'})
      : width = dataIn.width,
        super(name: '${dataName}_lfsr') {
    dataIn = addInput('${dataName}_in', dataIn, width: width);
    clk = addInput('clk', clk);
    addOutput('${dataName}_out', width: width);

    Map<Logic, dynamic>? resetValues;

    if (reset != null) {
      reset = addInput('reset', reset);
      if (resetValue != null) {
        if (resetValue is Logic) {
          resetValue =
              addInput('resetValue', resetValue, width: resetValue.width);
        }
        resetValues = {};
      }
    }

    var dataStage = dataIn;
    var conds = <Conditional>[];

    // Create the LFSR logic for each shift stage
    for (var i = 0; i < shifts; i++) {
      final stageI = addOutput(_stageName(i), width: width);

      conds.add(stageI < dataStage);
      resetValues?[stageI] = resetValue;

      Logic lsb = state.getRange(0, 1); // Get LSB (least significant bit)
      state = [Const(0, width: 1), state.getRange(1, width)].swizzle();

      If(lsb.eq(Const(1)), then: [
        state < state ^ taps // Perform XOR and assign back to state
      ]);

      dataStage = stageI;
    }

    // Enable logic if needed
    if (enable != null) {
      enable = addInput('enable', enable);
      conds = [If(enable, then: conds)];
    }

    // Sequential logic block
    Sequential(
      clk,
      reset: reset,
      resetValues: resetValues,
      conds,
    );
    // Connect the final stage to the output
    dataOut <= dataStage;
  }
}
