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
import 'package:rohd_hcl/src/summation/summation_base.dart';
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

class Sum extends SummationBase {
  Logic get sum => output('sum');

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
    super.interfaces, {
    dynamic initialValue = 0,
    super.maxValue,
    super.minValue,
    super.width,
    super.saturates,
    super.name = 'sum',
  }) : super(initialValue: initialValue) {
    addOutput('sum', width: width);

    // assume minValue is 0, maxValue is 2^width, for width safety calcs
    final maxPosMagnitude = biggestVal(this.width) +
        interfaces
            .where((e) => e.increments)
            .map((e) => biggestVal(e.width))
            .sum;
    final maxNegMagnitude = interfaces
            .where((e) => !e.increments)
            .map((e) => biggestVal(e.width))
            .sum +
        // also consider that initialValue may be less than min
        (initialValue is Logic
            ? biggestVal(initialValue.width)
            : LogicValue.ofInferWidth(initialValue).toInt());

    // calculate the largest number that we could have in intermediate
    final internalWidth = log2Ceil(maxPosMagnitude + maxNegMagnitude + 1);

    final initialValueLogicExt = initialValueLogic.zeroExtend(internalWidth);
    final minValueLogicExt = minValueLogic.zeroExtend(internalWidth);
    final maxValueLogicExt = maxValueLogic.zeroExtend(internalWidth);

    // lazy range so that it's not generated if not necessary
    late final range = Logic(name: 'range', width: internalWidth)
      ..gets(maxValueLogicExt - minValueLogicExt + 1);

    final zeroPoint = Logic(name: 'zeroPoint', width: internalWidth)
      ..gets(Const(maxNegMagnitude, width: internalWidth));

    final upperSaturation = Logic(name: 'upperSaturation', width: internalWidth)
      ..gets(maxValueLogicExt + zeroPoint);
    final lowerSaturation = Logic(name: 'lowerSaturation', width: internalWidth)
      ..gets(minValueLogicExt + zeroPoint);

    final internalValue = Logic(name: 'internalValue', width: internalWidth);
    sum <= (internalValue - zeroPoint).getRange(0, this.width);

    final preAdjustmentValue =
        Logic(name: 'preAdjustmentValue', width: internalWidth);

    Combinational.ssa((s) => [
          // initialize
          s(internalValue) < initialValueLogicExt + zeroPoint,

          // perform increments and decrements
          ...interfaces
              .map((e) => e._combAdjustments(s, internalValue))
              .flattened,

          // identify if we're at a max/min case
          overflowed < s(internalValue).gt(upperSaturation),
          underflowed < s(internalValue).lt(lowerSaturation),

          // useful as an internal node for debug/visibility
          preAdjustmentValue < s(internalValue),

          // handle saturation or over/underflow
          If.block([
            Iff.s(
              overflowed,
              s(internalValue) <
                  (saturates
                      ? upperSaturation
                      : ((s(internalValue) - upperSaturation - 1) % range +
                          lowerSaturation)),
            ),
            ElseIf.s(
              underflowed,
              s(internalValue) <
                  (saturates
                      ? lowerSaturation
                      : (upperSaturation -
                          ((lowerSaturation - s(internalValue) - 1) % range))),
            )
          ]),
        ]);

    equalsMax <= internalValue.eq(upperSaturation);
    equalsMin <= internalValue.eq(lowerSaturation);
  }
}
