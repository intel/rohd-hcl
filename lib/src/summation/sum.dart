// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sum.dart
// A flexible sum implementation.
//
// 2024 August 26
// Author: Max Korbel <max.korbel@intel.com>

import 'package:collection/collection.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/summation/summation_utils.dart';

extension on SumInterface {
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

class Sum extends Module with DynamicInputToLogicForSummation {
  final int width;

  /// If `true`,  will saturate at the `maxValue` and `minValue`. If `false`,
  /// will wrap around (overflow/underflow) at the `maxValue` and `minValue`.
  final bool saturates;

  Logic get sum => output('sum');

  /// Indicates whether the sum has reached the maximum value.
  ///
  /// If it [saturates], then [sum] will be equal to the maximum value.
  /// Otherwise, the value may have overflowed to any value, but the net sum
  /// before overflow will have been greater than the maximum value.
  Logic get reachedMax => output('reachedMax');

  /// Indicates whether the sum has reached the minimum value.
  ///
  /// If it [saturates], then [sum] will be equal to the minimum value.
  /// Otherwise, the value may have underflowed to any value, but the net sum
  /// before underflow will have been less than the minimum value.
  Logic get reachedMin => output('reachedMin');

  /// TODO
  ///
  /// All [logics]s are always enabled and incrementing.
  factory Sum.ofLogics(
    List<Logic> logics, {
    dynamic initialValue = 0,
    dynamic maxValue,
    dynamic minValue = 0,
    int? width,
    bool saturates = false,
    String name = 'sum',
  }) =>
      Sum(
          logics
              .map((e) => SumInterface(width: e.width)..amount.gets(e))
              .toList(),
          initialValue: initialValue,
          maxValue: maxValue,
          minValue: minValue,
          width: width,
          saturates: saturates,
          name: name);

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
  ///
  /// It is expected that [maxValue] is at least [minValue], or else results may
  /// be unpredictable.
  Sum(
    List<SumInterface> interfaces, {
    dynamic initialValue = 0,
    dynamic maxValue,
    dynamic minValue = 0,
    int? width,
    this.saturates = false,
    super.name = 'sum',
  }) : width =
            inferWidth([initialValue, maxValue, minValue], width, interfaces) {
    if (interfaces.isEmpty) {
      throw RohdHclException('At least one interface must be provided.');
    }

    interfaces = interfaces
        .mapIndexed((i, e) => SumInterface.clone(e)
          ..pairConnectIO(this, e, PairRole.consumer,
              uniquify: (original) => '${original}_$i'))
        .toList();

    addOutput('sum', width: this.width);
    addOutput('reachedMax');
    addOutput('reachedMin');

    // assume minValue is 0, maxValue is 2^width, for width safety calcs
    final maxPosMagnitude = _biggestVal(this.width) +
        interfaces
            .where((e) => e.increments)
            .map((e) => _biggestVal(e.width))
            .sum;
    final maxNegMagnitude = interfaces
            .where((e) => !e.increments)
            .map((e) => _biggestVal(e.width))
            .sum +
        // also consider that initialValue may be less than min
        (initialValue is Logic
            ? _biggestVal(initialValue.width)
            : LogicValue.ofInferWidth(initialValue).toInt());

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

    // lazy range so that it's not generated if not necessary
    late final range = Logic(name: 'range', width: internalWidth)
      ..gets(maxValueLogic - minValueLogic + 1);

    final zeroPoint = Logic(name: 'zeroPoint', width: internalWidth)
      ..gets(Const(maxNegMagnitude, width: internalWidth));

    final upperSaturation = Logic(name: 'upperSaturation', width: internalWidth)
      ..gets(maxValueLogic + zeroPoint);
    final lowerSaturation = Logic(name: 'lowerSaturation', width: internalWidth)
      ..gets(minValueLogic + zeroPoint);

    final internalValue = Logic(name: 'internalValue', width: internalWidth);
    sum <= (internalValue - zeroPoint).getRange(0, this.width);

    final passedMax = Logic(name: 'passedMax');
    final passedMin = Logic(name: 'passedMin');

    final preAdjustmentValue =
        Logic(name: 'preAdjustmentValue', width: internalWidth);

    Combinational.ssa((s) => [
          // initialize
          s(internalValue) < initialValueLogic + zeroPoint,

          // perform increments and decrements
          ...interfaces
              .map((e) => e._combAdjustments(s, internalValue))
              .flattened,

          // identify if we're at a max/min case
          passedMax < s(internalValue).gt(upperSaturation),
          passedMin < s(internalValue).lt(lowerSaturation),
          reachedMax < passedMax | s(internalValue).eq(upperSaturation),
          reachedMin < passedMin | s(internalValue).eq(lowerSaturation),

          // useful as an internal node for debug/visibility
          preAdjustmentValue < s(internalValue),

          // handle saturation or over/underflow
          If.block([
            Iff.s(
              passedMax,
              s(internalValue) <
                  (saturates
                      ? upperSaturation
                      : ((s(internalValue) - upperSaturation - 1) % range +
                          lowerSaturation)),
            ),
            ElseIf.s(
              passedMin,
              s(internalValue) <
                  (saturates
                      ? lowerSaturation
                      : (upperSaturation -
                          ((lowerSaturation - s(internalValue) - 1) % range))),
            )
          ]),
        ]);
  }

  static int _biggestVal(int width) => (1 << width) - 1;
}
