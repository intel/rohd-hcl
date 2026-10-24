// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// shift_register.dart
// Implementation of a shift register.
//
// 2023 September 21
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';

/// A shift register with configurable width and depth and optional enable and
/// reset, preserving the payload type [T] at every stage.
class ShiftRegister<T extends Logic> extends Module with ResettableEntries {
  /// The number of stages in this shift register.
  final int depth;

  /// The main output of the shift register after going through all the stages.
  T get dataOut => output('${dataName}_out') as T;

  /// The width of the data passing through this shfit register.
  final int width;

  /// A [List] of [output]s where the `n`'th entry corresponds to a version of
  /// the input data after passing through `n + 1` flops.
  ///
  /// The length is equal to [depth]. The last entry is the same as [dataOut].
  late final List<T> stages = UnmodifiableListView(
      List.generate(depth, (i) => output(_stageName(i)) as T));

  /// The name of the signal (and output pin) for the [i]th stage.
  String _stageName(int i) => '${dataName}_stage_$i';

  /// The name of the data, used for naming the ports and [Module].
  final String dataName;

  /// Creates a new shift register with specified [depth] which is only active
  /// when [enable]d.
  ///
  /// If [reset] is provided, it will reset synchronously with [clk] or
  /// aynchronously if [asyncReset] is `true`. The [reset] will reset all stages
  /// to a default of `0` or to the provided [resetValue]. If [resetValue] is a
  /// [List] the stages will reset to the corresponding value in the list.
  /// When both reset and payload are structured, their layouts must match.
  /// Scalar constants used as [dataIn] require `ShiftRegister<Logic>` for
  /// driveable ports.
  ShiftRegister(
    T dataIn, {
    required Logic clk,
    required this.depth,
    Logic? enable,
    Logic? reset,
    bool asyncReset = false,
    dynamic resetValue,
    this.dataName = 'data',
    String? name,
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  })  : width = dataIn.width,
        super(
            name: name ?? '${dataName}_shift_register',
            definitionName: definitionName ??
                'ShiftRegister_W${dataIn.width}'
                    '_D$depth') {
    dataIn = addTypedInput('${dataName}_in', dataIn);
    clk = addInput('clk', clk);

    addTypedOutput('${dataName}_out', dataIn.cloneTyped);

    final Map<Logic, dynamic>? resetValues;
    final List<Logic>? resetValueList;

    if (reset != null) {
      reset = addInput('reset', reset);
      resetValueList =
          makeResetValues(resetValue, numEntries: depth, entryWidth: width);
      for (final value in resetValueList) {
        if ((dataIn is LogicStructure || dataIn is LogicEnum) &&
            (value is LogicStructure || value is LogicEnum) &&
            !sameDeclaredPayloadShape(dataIn, value)) {
          throw RohdHclException(
              'ShiftRegister reset signal layout must match the payload.');
        }
      }
      resetValues = {};
    } else {
      resetValueList = null;
      resetValues = null;
    }

    var dataStage = dataIn;
    var conds = <Conditional>[];

    for (var i = 0; i < depth; i++) {
      final stageI = addTypedOutput(_stageName(i), dataIn.cloneTyped);
      conds.add(stageI < dataStage);

      resetValues?[stageI] = resetValueList![i];
      dataStage = stageI;
    }

    if (enable != null) {
      enable = addInput('enable', enable);

      conds = [If(enable, then: conds)];
    }

    Sequential.multi(
      [clk],
      reset: reset,
      resetValues: resetValues,
      asyncReset: asyncReset,
      conds,
    );

    dataOut <= dataStage;
  }
}
