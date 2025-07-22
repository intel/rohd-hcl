// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sum.dart
// A flexible sum implementation.
//
// 2024 August 26
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/summation/summation_base.dart';

/// An extension on [SumInterface] to provide additional functionality for
/// computing in [Sum].
extension on SumInterface {
  /// Adjusts the [nextVal] by the amount specified in this interface, to be
  /// used within a [Combinational.ssa] block.
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

/// Computes a sum of any number of sources with optional configuration for
/// widths and saturation behavior.
class Sum extends SummationBase {
  /// The resulting [sum].
  Logic get sum => output('sum');

  /// Computes a [sum] across the provided [interfaces].
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
  ///
  /// If [saturates] is `true`, then it will saturate at the [maxValue] and
  /// [minValue]. If `false`, will wrap around (overflow/underflow) at the
  /// [maxValue] and [minValue].  The [equalsMax], [equalsMin], [overflowed],
  /// and [underflowed] outputs can be used to determine if the sum is at the
  /// maximum, minimum, (would have) overflowed, or  (would have) underflowed,
  /// respectively.
  Sum(super.interfaces,
      {dynamic initialValue = 0,
      super.maxValue,
      super.minValue,
      super.width,
      super.saturates,
      super.name = 'sum',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName:
                definitionName ?? 'Sum_${interfaces.length}_W$width',
            initialValue: initialValue) {
    addOutput('sum', width: width);

    var maxPosMagnitude = SummationBase.biggestVal(width);
    var maxNegMagnitude = BigInt.zero;
    for (final intf in interfaces) {
      final maxMagnitude = intf.fixedAmount != null
          ? intf.amount.value.toBigInt()
          : SummationBase.biggestVal(intf.width);

      if (intf.increments) {
        maxPosMagnitude += maxMagnitude;
      } else {
        maxNegMagnitude += maxMagnitude;
      }
    }

    // also consider that initialValue may be less than min or more than max
    final maxInitialValueMagnitude = initialValue is Logic
        ? SummationBase.biggestVal(initialValue.width)
        : LogicValue.ofInferWidth(initialValue).toBigInt();
    maxPosMagnitude += maxInitialValueMagnitude;
    maxNegMagnitude += maxInitialValueMagnitude;

    // calculate the largest number that we could have in intermediate
    final internalWidth = max(
        (maxPosMagnitude + maxNegMagnitude + BigInt.one).bitLength, width + 1);

    final initialValueLogicExt = initialValueLogic.zeroExtend(internalWidth);
    final minValueLogicExt =
        minValueLogic.zeroExtend(internalWidth).named('minValueExt');
    final maxValueLogicExt =
        maxValueLogic.zeroExtend(internalWidth).named('maxValueExt');

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
    sum <=
        (internalValue - zeroPoint)
            .named('internalValueOverZeroPoint')
            .getRange(0, width);

    final preAdjustmentValue =
        Logic(name: 'preAdjustmentValue', width: internalWidth);

    // here we use an `ssa` block to iteratively update the value of
    // `internalValue` based on the adjustments from the interfaces and
    // saturation/roll-over behavior
    //
    // For more details, see:
    // https://intel.github.io/rohd-website/blog/combinational-ssa/
    Combinational.ssa((s) => [
          // initialize
          s(internalValue) < initialValueLogicExt + zeroPoint,

          // perform increments and decrements per-interface
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

  /// Computes a [Sum] across the provided [logics].
  ///
  /// All [logics] are always incrementing and controlled optionally by a single
  /// [enable].
  factory Sum.ofLogics(
    List<Logic> logics, {
    dynamic initialValue = 0,
    dynamic maxValue,
    dynamic minValue = 0,
    Logic? enable,
    int? width,
    bool saturates = false,
    String name = 'sum',
  }) =>
      Sum(
          logics
              .map(
                  (e) => SumInterface(width: e.width, hasEnable: enable != null)
                    ..amount.gets(e)
                    ..enable?.gets(enable!))
              .toList(),
          initialValue: initialValue,
          maxValue: maxValue,
          minValue: minValue,
          width: width,
          saturates: saturates,
          name: name);
}
