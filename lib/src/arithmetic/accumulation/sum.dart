// Copyright (C) 2024-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sum.dart
// A flexible sum implementation.
//
// 2024 August 26
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

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

BigInt _biggestUnsignedValue(int width) => (BigInt.one << width) - BigInt.one;

// Computes conservative bounds before the sum is wrapped or saturated.
({BigInt minimum, BigInt maximum}) _possibleSumRange(
  dynamic initialValue,
  List<SumInterface> interfaces,
  int width,
) {
  var minimum = BigInt.zero;
  late BigInt maximum;

  if (initialValue == null) {
    maximum = BigInt.zero;
  } else if (initialValue is int && initialValue >= 0) {
    minimum = BigInt.from(initialValue);
    maximum = minimum;
  } else if (initialValue is BigInt && !initialValue.isNegative) {
    minimum = initialValue;
    maximum = minimum;
  } else if (initialValue is Logic) {
    maximum = _biggestUnsignedValue(initialValue.width);
  } else if (initialValue is LogicValue) {
    maximum = _biggestUnsignedValue(initialValue.width);
  } else {
    maximum = _biggestUnsignedValue(width);
  }

  for (final intf in interfaces) {
    final amountMaximum = intf.fixedAmount == null
        ? _biggestUnsignedValue(intf.width)
        : intf.amount.value.toBigInt();

    if (intf.increments) {
      maximum += amountMaximum;
      if (intf.fixedAmount != null && !intf.hasEnable) {
        minimum += amountMaximum;
      }
    } else {
      minimum -= amountMaximum;
      if (intf.fixedAmount != null && !intf.hasEnable) {
        maximum -= amountMaximum;
      }
    }
  }

  return (minimum: minimum, maximum: maximum);
}

/// Computes a sum of any number of sources with optional configuration for
/// widths and saturation behavior.
class Sum extends SummationBase {
  /// The resulting [sum].
  Logic get sum => output('sum');

  /// Whether the range analysis finds that overflow is possible.
  @internal
  late final bool canOverflow;

  /// Whether the range analysis finds that underflow is possible.
  @internal
  late final bool canUnderflow;

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
  /// respectively. [initialValue], [maxValue], and [minValue] can be provided
  /// as [StaticOrRuntimeControl]s when a named runtime input or explicit
  /// static/runtime configuration is useful.
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
    final configuredInitialValue = SummationBase.configuredValue(initialValue);

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
    final initialValueMagnitude = configuredInitialValue == null
        ? BigInt.zero
        : configuredInitialValue is Logic
            ? SummationBase.biggestVal(configuredInitialValue.width)
            : LogicValue.ofInferWidth(configuredInitialValue).toBigInt().abs();
    final maxInitialValueMagnitude = initialValueMagnitude;
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

    final possibleRange =
        _possibleSumRange(configuredInitialValue, interfaces, width);
    canOverflow = constantMaxValue == null ||
        constantMaxValue!.isNegative ||
        possibleRange.maximum > constantMaxValue!;
    canUnderflow = constantMinValue == null ||
        constantMinValue!.isNegative ||
        possibleRange.minimum < constantMinValue!;

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
    Combinational.ssa((s) {
      final overflowUnderflowAdjustments = <Iff>[];
      if (canOverflow) {
        overflowUnderflowAdjustments.add(
          Iff.s(
            overflowed,
            s(internalValue) <
                (saturates
                    ? upperSaturation
                    : ((s(internalValue) - upperSaturation - 1) % range +
                        lowerSaturation)),
          ),
        );
      }
      if (canUnderflow) {
        final underflowAdjustment = s(internalValue) <
            (saturates
                ? lowerSaturation
                : (upperSaturation -
                    ((lowerSaturation - s(internalValue) - 1) % range)));
        if (canOverflow) {
          overflowUnderflowAdjustments.add(
            ElseIf.s(underflowed, underflowAdjustment),
          );
        } else {
          overflowUnderflowAdjustments.add(
            Iff.s(underflowed, underflowAdjustment),
          );
        }
      }

      return [
        // initialize
        s(internalValue) < initialValueLogicExt + zeroPoint,

        // perform increments and decrements per-interface
        ...interfaces
            .map((e) => e._combAdjustments(s, internalValue))
            .flattened,

        // identify if we're at a max/min case
        if (canOverflow)
          overflowed < s(internalValue).gt(upperSaturation)
        else
          overflowed < Const(0),
        if (canUnderflow)
          underflowed < s(internalValue).lt(lowerSaturation)
        else
          underflowed < Const(0),

        // useful as an internal node for debug/visibility
        preAdjustmentValue < s(internalValue),

        // handle saturation or over/underflow
        if (overflowUnderflowAdjustments.isNotEmpty)
          If.block(overflowUnderflowAdjustments),
      ];
    });

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
