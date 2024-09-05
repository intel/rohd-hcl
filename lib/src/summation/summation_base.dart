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
import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A base class for modules doing summation operation such as [Counter] and
/// [Sum].
abstract class SummationBase extends Module {
  /// The width of the resulting sum.
  final int width;

  /// An internal [Logic] version of the provided initial value.
  @protected
  late final Logic initialValueLogic;

  /// An internal [Logic] version of the provided minimum value.
  @protected
  late final Logic minValueLogic;

  /// An internal [Logic] version of the provided maximum value.
  @protected
  late final Logic maxValueLogic;

  /// The "internal" versions of the [SumInterface]s for this computation.
  @protected
  late final List<SumInterface> interfaces;

  /// If `true`, will saturate at the `maxValue` and `minValue`. If `false`,
  /// will wrap around (overflow/underflow) at the `maxValue` and `minValue`.
  final bool saturates;

  /// Indicates whether the sum is greater than the maximum value. The actual
  /// resulting value depends on the provided [saturates] behavior (staturation
  /// or overflow).
  Logic get overflowed => output('overflowed');

  /// Indicates whether the sum is less than the minimum value. The actual
  /// resulting value depends on the provided [saturates] behavior (saturation
  /// or underflow).
  Logic get underflowed => output('underflowed');

  /// Indicates whether the sum (including potential saturation) is currently
  /// equal to the maximum.
  Logic get equalsMax => output('equalsMax');

  /// Indicates whether the sum (including potential saturation) is currently
  /// equal to the minimum.
  Logic get equalsMin => output('equalsMin');

  /// Sums the values across the provided [interfaces] within the bounds of the
  /// [saturates] behavior, [initialValue], [maxValue], and [minValue], with the
  /// specified [width], if provided.
  SummationBase(
    List<SumInterface> interfaces, {
    dynamic initialValue = 0,
    dynamic maxValue,
    dynamic minValue = 0,
    this.saturates = false,
    int? width,
    super.name,
  }) : width =
            _inferWidth([initialValue, maxValue, minValue], width, interfaces) {
    if (interfaces.isEmpty) {
      throw RohdHclException('At least one interface must be provided.');
    }

    this.interfaces = interfaces
        .mapIndexed((i, e) => SumInterface.clone(e)
          ..pairConnectIO(this, e, PairRole.consumer,
              uniquify: (original) => '${original}_$i'))
        .toList();

    initialValueLogic = _dynamicInputToLogic('initialValue', initialValue);
    minValueLogic = _dynamicInputToLogic('minValue', minValue);
    maxValueLogic =
        _dynamicInputToLogic('maxValue', maxValue ?? biggestVal(this.width));

    addOutput('overflowed');
    addOutput('underflowed');
    addOutput('equalsMax');
    addOutput('equalsMin');
  }

  /// Takes a given `dynamic` [value] and converts it into a [Logic],
  /// potentially as an input port, if necessary.
  Logic _dynamicInputToLogic(String name, dynamic value) {
    if (value is Logic) {
      return addInput(name, value.zeroExtend(width), width: width);
    } else {
      // if it's a LogicValue, then don't assume the width is necessary
      if (value is LogicValue) {
        // ignore: parameter_assignments
        value = value.toBigInt();
      }

      if (LogicValue.ofInferWidth(value).width > width) {
        throw RohdHclException(
            'Value $value for $name is too large for width $width');
      }

      return Logic(name: name, width: width)..gets(Const(value, width: width));
    }
  }

  /// Returns the largest value that can fit within [width].
  @protected
  static BigInt biggestVal(int width) => BigInt.two.pow(width) - BigInt.one;

  /// Infers the width of the sum based on the provided values, interfaces, and
  /// optionally the provided [width].
  static int _inferWidth(
      List<dynamic> values, int? width, List<SumInterface> interfaces) {
    if (width != null) {
      if (width <= 0) {
        throw RohdHclException('Width must be greater than 0.');
      }

      if (values.any((v) => v is Logic && v.width > width)) {
        throw RohdHclException(
            'Width must be at least as large as the largest value.');
      }

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

    return max(1, maxWidthFound);
  }
}
