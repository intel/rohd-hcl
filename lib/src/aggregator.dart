// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// aggregator.dart
// A flexible aggregator implementation.
//
// 2024 August 26
// Author: Max Korbel <max.korbel@intel.com>

import 'package:collection/collection.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/exceptions.dart';
import 'package:rohd_hcl/src/parallel_prefix_operations.dart';

class AggregatorInterface extends PairInterface {
  final bool hasEnable;

  /// The [amount] to increment/decrement by, depending on [increments].
  Logic get amount => port('amount');

  /// Controls whether it should increment or decrement (based on [increments])
  /// (active high).
  ///
  /// Present if [hasEnable] is `true`.
  Logic? get enable => tryPort('enable');

  final int width;

  /// If `true`, will increment. If `false`,  will decrement.
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
  AggregatorInterface(
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

  AggregatorInterface.clone(AggregatorInterface other)
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

class Aggregator extends Module with DynamicInputToLogic {
  final int width;

  /// If `true`,  will saturate at the `maxValue` and `minValue`. If `false`,
  /// will wrap around (overflow/underflow) at the `maxValue` and `minValue`.
  final bool saturates;

  Logic get value => output('value');

  /// TODO
  ///
  /// The [width] can be either explicitly provided or inferred from other
  /// values such as a [maxValue], [minValue], or [initialValue] that contain
  /// width information (e.g. a [LogicValue]), or by making it large enough to
  /// fit [maxValue], or by inspecting widths of [interfaces]. There must be
  /// enough information provided to determine the [width].
  ///
  /// If no [maxValue] is provided, one will be inferred by the maximum that can
  /// fit inside of the [width].
  Aggregator(
    List<AggregatorInterface> interfaces, {
    dynamic initialValue = 0,
    dynamic maxValue,
    dynamic minValue = 0,
    int? width,
    this.saturates = false,
    super.name = 'aggregator',
  }) : width =
            inferWidth([initialValue, maxValue, minValue], width, interfaces) {
    interfaces = interfaces
        .map((e) => AggregatorInterface.clone(e)..connectIO(this, e))
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

    final initialValueLogic = dynamicInputToLogic(
      'initialValue',
      initialValue,
    ).zeroExtend(internalWidth);
    final minValueLogic = dynamicInputToLogic(
      'minValue',
      minValue,
    ).zeroExtend(internalWidth);
    final maxValueLogic = dynamicInputToLogic(
      'maxValue',
      maxValue ?? _biggestVal(this.width),
    ).zeroExtend(internalWidth);

    final range = Logic(name: 'range', width: internalWidth)
      ..gets(maxValueLogic - minValueLogic);

    final zeroPoint = Logic(name: 'zeroPoint', width: internalWidth)
      ..gets(Const(maxNegMagnitude, width: internalWidth));

    final upperSaturation = Logic(name: 'upperSaturation', width: internalWidth)
      ..gets(maxValueLogic + zeroPoint);
    final lowerSaturation = Logic(name: 'lowerSaturation', width: internalWidth)
      ..gets(minValueLogic + zeroPoint);

    final internalValue = Logic(name: 'internalValue', width: internalWidth);
    value <= internalValue.getRange(0, this.width);

    Combinational.ssa((s) => [
          // initialize
          s(internalValue) < initialValueLogic,

          // perform increments and decrements
          ...interfaces
              .map((e) => e._combAdjustments(s, internalValue))
              .flattened,

          // handle saturation or over/underflow
          if (saturates)
            // saturation
            If.block([
              Iff.s(
                s(internalValue).gt(upperSaturation),
                s(internalValue) < upperSaturation,
              ),
              ElseIf.s(
                s(internalValue).lt(lowerSaturation),
                s(internalValue) < lowerSaturation,
              )
            ])
          else
            // under/overflow
            If.block([
              Iff.s(
                s(internalValue).gt(upperSaturation),
                s(internalValue) <
                    ((s(internalValue) - zeroPoint) % range + lowerSaturation),
              ),
              ElseIf.s(
                s(internalValue).lt(lowerSaturation),
                s(internalValue) <
                    (upperSaturation -
                        ((zeroPoint - s(internalValue)) % range)),
              )
            ]),
        ]);
  }

  static int _biggestVal(int width) => (1 << width) - 1;
}

//TODO doc
//TODO: hide this somehow
int inferWidth(
    List<dynamic> values, int? width, List<AggregatorInterface> interfaces) {
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
