// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// counter.dart
// A flexible counter implementation.
//
// 2024 August 26
// Author: Max Korbel <max.korbel@intel.com>

import 'package:collection/collection.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/exceptions.dart';
import 'package:rohd_hcl/src/parallel_prefix_operations.dart';

class CounterInterface extends PairInterface {
  final bool hasEnable;

  /// The [amount] to increment/decrement by, depending on [increments].
  Logic get amount => port('amount');

  /// Controls whether the associated [Counter] should increment or decrement
  /// (based on [increments]) this cycle (active high).
  ///
  /// Present if [hasEnable] is `true`.
  Logic? get enable => tryPort('enable');

  final int width;

  /// If `true`, the counter will increment. If `false`, the counter will
  /// decrement.
  final bool increments;

  final dynamic fixedAmount;

  /// TODO
  ///
  /// If [width] is `null`, it can be inferred from [fixedAmount] if provided
  /// with a type that contains width information (e.g. a [LogicValue]). There
  /// must be enough information provided to determine the [width].
  ///
  /// If a [fixedAmount] is provided, then [amount] will be tied to a [Const]. A
  /// provided [fixedAmount] must be parseable by [LogicValue.of]. Note that the
  /// [fixedAmount] will always be interpreted as a positive value truncated to
  /// [width]. If no [fixedAmount] is provided, then [amount] will be a normal
  /// [port] with [width] bits.
  ///
  /// If [hasEnable] is `true`, then an [enable] port will be added to the
  /// interface.
  CounterInterface(
      {this.fixedAmount,
      this.increments = true,
      int? width,
      this.hasEnable = false})
      : width = width ?? LogicValue.ofInferWidth(fixedAmount).width {
    setPorts([
      Port('amount', this.width),
      if (hasEnable) Port('enable'),
    ], [
      PairDirection.fromProvider
    ]);

    if (fixedAmount != null) {
      amount <= Const(fixedAmount, width: this.width);
    }
  }

  CounterInterface.clone(CounterInterface other)
      : this(
          fixedAmount: other.fixedAmount,
          increments: other.increments,
          width: other.width,
          hasEnable: other.hasEnable,
        );

  List<Conditional> _combAdjustments(Logic Function(Logic) s, Logic nextVal) {
    final conds = <Conditional>[
      if (increments)
        nextVal.incr(s: s, val: amount.zeroExtend(nextVal.width))
      else
        nextVal.decr(s: s, val: amount.zeroExtend(nextVal.width)),
    ];

    if (hasEnable) {
      return [If(enable!, then: conds)];
    } else {
      return conds;
    }
  }
}

class Counter extends Module {
  final int width;

  /// If `true`, the counter will saturate at the `maxValue` and `minValue`. If
  /// `false`, the counter will wrap around (overflow/underflow) at the
  /// `maxValue` and `minValue`.
  final bool saturates;

  Logic get value => output('value');

  /// TODO
  ///
  /// The [width] can be either explicitly provided or inferred from other
  /// values such as a [maxValue], [minValue], or [resetValue] that contain
  /// width information (e.g. a [LogicValue]), or by making it large enough to
  /// fit [maxValue], or by inspecting widths of [interfaces]. There must be
  /// enough information provided to determine the [width].
  ///
  /// If no [maxValue] is provided, one will be inferred by the maximum that can
  /// fit inside of the [width].
  Counter(
    List<CounterInterface> interfaces, {
    required Logic clk,
    required Logic reset,
    dynamic resetValue = 0,
    dynamic maxValue,
    dynamic minValue = 0,
    int? width,
    this.saturates = false,
    super.name = 'counter',
  }) : width =
            _inferWidth([resetValue, maxValue, minValue], width, interfaces) {
    //TODO: handle reset, max, min as Logic, not just static values

    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    interfaces = interfaces
        .map((e) => CounterInterface.clone(e)..connectIO(this, e))
        .toList();

    addOutput('value', width: this.width);

    // assume minValue is 0, maxValue is 2^width, for width safety calcs
    final maxPosMagnitude = _biggestVal(this.width) +
        interfaces
            .where((e) => e.increments)
            .map((e) => _biggestVal(e.width))
            .sum;
    final maxNegMagnitude = interfaces
        .where((e) => !e.increments)
        .map((e) => _biggestVal(e.width))
        .sum;

    // calculate the largest number that we could have in intermediate
    final internalWidth = log2Ceil(maxPosMagnitude + maxNegMagnitude + 1);

    final resetValueLogic = _dynamicInputToLogic(
      'resetValue',
      resetValue,
    ).zeroExtend(internalWidth);
    final minValueLogic = _dynamicInputToLogic(
      'minValue',
      minValue,
    ).zeroExtend(internalWidth);
    final maxValueLogic = _dynamicInputToLogic(
      'maxValue',
      maxValue ?? _biggestVal(this.width),
    ).zeroExtend(internalWidth);

    final range = Logic(name: 'range', width: internalWidth)
      ..gets(maxValueLogic - minValueLogic);

    final zeroPoint = Logic(name: 'zeroPoint', width: internalWidth)
      ..gets(Const(maxNegMagnitude, width: internalWidth));

    final nextVal = Logic(name: 'nextVal', width: internalWidth);
    final currVal = Logic(name: 'currVal', width: internalWidth);

    final upperSaturation = Logic(name: 'upperSaturation', width: internalWidth)
      ..gets(maxValueLogic + zeroPoint);
    final lowerSaturation = Logic(name: 'lowerSaturation', width: internalWidth)
      ..gets(minValueLogic + zeroPoint);

    currVal <=
        flop(
          clk,
          nextVal,
          reset: reset,
          resetValue: resetValueLogic + zeroPoint,
        );

    value <= (currVal - zeroPoint).getRange(0, this.width);

    Combinational.ssa((s) => [
          // initialize
          s(nextVal) < currVal,

          // perform increments and decrements
          ...interfaces.map((e) => e._combAdjustments(s, nextVal)).flattened,

          // handle saturation or over/underflow
          if (saturates)
            // saturation
            If.block([
              Iff.s(
                s(nextVal).gt(upperSaturation),
                s(nextVal) < upperSaturation,
              ),
              ElseIf.s(
                s(nextVal).lt(lowerSaturation),
                s(nextVal) < lowerSaturation,
              )
            ])
          else
            // under/overflow
            If.block([
              Iff.s(
                s(nextVal).gt(upperSaturation),
                // s(nextVal) < (s(nextVal) - upperSaturation + lowerSaturation),
                s(nextVal) <
                    ((s(nextVal) - zeroPoint) % range + lowerSaturation),
              ),
              ElseIf.s(
                s(nextVal).lt(lowerSaturation),
                s(nextVal) <
                    (upperSaturation - ((zeroPoint - s(nextVal)) % range)),
              )
            ]),
        ]);
  }

  //TODO doc
  Logic _dynamicInputToLogic(String name, dynamic value) {
    if (value is Logic) {
      return addInput(name, value.zeroExtend(width), width: width);
    } else {
      return Const(value, width: width);
    }
  }

  static int _biggestVal(int width) => (1 << width) - 1;

  //TODO doc
  static int _inferWidth(
      List<dynamic> values, int? width, List<CounterInterface> interfaces) {
    if (width != null) {
      return width;
    }

    int? maxWidthFound;

    for (final value in values) {
      int? inferredValWidth;
      if (value is Logic) {
        inferredValWidth = value.width;
      } else if (value != null) {
        inferredValWidth = LogicValue.ofInferWidth(value).width;
      }

      if (inferredValWidth != null &&
          (maxWidthFound == null || inferredValWidth > maxWidthFound)) {
        maxWidthFound = inferredValWidth;
      }
    }

    for (final interface in interfaces) {
      if (interface.width > maxWidthFound!) {
        maxWidthFound = interface.width;
      }
    }

    if (maxWidthFound == null) {
      throw RohdHclException('Unabled to infer width.');
    }

    return maxWidthFound;
  }
}
