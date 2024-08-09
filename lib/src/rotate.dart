// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// rotate.dart
// Implementation of rotation for Logic and LogicValue.
//
// 2023 February 17
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A direction for something to rotate.
enum RotateDirection {
  /// Rotate to the left.
  left,

  /// Rotate to the right.
  right
}

/// Rotates a [Logic] to the specified direction.
abstract class _Rotate extends Module {
  /// The maximum amount that this [_Rotate] should support in rotation.
  final int maxAmount;

  /// The [_direction] that this [_Rotate] should rotate.
  final RotateDirection _direction;

  /// The [rotated] result.
  Logic get rotated => output('rotated');

  /// Constructs a [Module] that rotates [original] to the specified
  /// [_direction] by [rotateAmount], up to [maxAmount].
  ///
  /// If no [maxAmount] is provided, it will default to the `width` of
  /// [original].  The [maxAmount] will be not be larger than what could be
  /// represented by the maximum value of [rotateAmount].
  _Rotate(this._direction, Logic original, Logic rotateAmount,
      {int? maxAmount, super.name = 'rotate'})
      : maxAmount = min(
          maxAmount ?? original.width,
          pow(2, rotateAmount.width).toInt() - 1,
        ) {
    original = addInput('original', original, width: original.width);
    rotateAmount =
        addInput('rotate_amount', rotateAmount, width: rotateAmount.width);

    addOutput('rotated', width: original.width);

    Combinational([
      Case(rotateAmount, conditionalType: ConditionalType.unique, [
        for (var i = 1; i <= this.maxAmount; i++)
          CaseItem(
            Const(i, width: rotateAmount.width),
            [rotated < _RotateFixed._rotateBy(i, original, _direction)],
          )
      ], defaultItem: [
        rotated < original,
      ])
    ]);
  }
}

/// Rotates a [Logic] to the left.
class RotateLeft extends _Rotate {
  /// Constructs a [Module] to perform rotation to the left.
  ///
  /// Conditionally rotates by different amounts based on the value of
  /// [rotateAmount]. The [maxAmount] is the largest value for which this
  /// rotation should support, which could be greater than the `width`
  /// of [rotateAmount].
  ///
  /// If no [maxAmount] is provided, it will default to the `width` of
  /// [original].  The [maxAmount] will be not be larger than what could be
  /// represented by the maximum value of [rotateAmount].
  RotateLeft(Logic original, Logic rotateAmount, {super.maxAmount, super.name})
      : super(RotateDirection.left, original, rotateAmount);
}

/// Rotates a [Logic] to the right.
class RotateRight extends _Rotate {
  /// Constructs a [Module] to perform rotation to the right.
  ///
  /// Conditionally rotates by different amounts based on the value of
  /// [rotateAmount]. The [maxAmount] is the largest value for which this
  /// rotation should support, which could be greater than the `width`
  /// of [rotateAmount].
  ///
  /// If no [maxAmount] is provided, it will default to the `width` of
  /// [original].  The [maxAmount] will be not be larger than what could be
  /// represented by the maximum value of [rotateAmount].
  RotateRight(Logic original, Logic rotateAmount, {super.maxAmount, super.name})
      : super(RotateDirection.right, original, rotateAmount);
}

/// Rotates by a fixed amount.
class _RotateFixed extends Module {
  /// The [_direction] that this [_Rotate] should rotate.
  final RotateDirection _direction;

  /// The [rotated] result.
  Logic get rotated => output('rotated');

  final int rotateAmount;

  /// Rotates [original] by [rotateAmount] to the [_direction].
  _RotateFixed(this._direction, Logic original, this.rotateAmount,
      {super.name = 'rotate_fixed'})
      : super(definitionName: 'rotate_${_direction.name}_by_$rotateAmount') {
    original = addInput('original', original, width: original.width);
    addOutput('rotated', width: original.width);

    rotated <= _rotateBy(rotateAmount, original, _direction);
  }

  /// Rotates [original] by [rotateAmount] in the specified [direction].
  static Logic _rotateBy(
      int rotateAmount, Logic original, RotateDirection direction) {
    final split = direction == RotateDirection.left
        ? original.width - rotateAmount % original.width
        : rotateAmount % original.width;

    if (rotateAmount % original.width == 0) {
      return original;
    }

    return [
      original.getRange(0, split),
      original.getRange(split),
    ].swizzle();
  }
}

/// Rotates left by a fixed amount.
class RotateLeftFixed extends _RotateFixed {
  /// Rotates [original] by [rotateAmount] to the left.
  RotateLeftFixed(Logic original, int rotateAmount, {super.name})
      : super(RotateDirection.left, original, rotateAmount);
}

/// Rotates right by a fixed amount.
class RotateRightFixed extends _RotateFixed {
  /// Rotates [original] by [rotateAmount] to the right.
  RotateRightFixed(Logic original, int rotateAmount, {super.name})
      : super(RotateDirection.right, original, rotateAmount);
}

/// Adds rotation functions to [Logic].
extension RotateLogic on Logic {
  /// Returns a [Logic] rotated [direction] by [rotateAmount].
  ///
  /// If [rotateAmount] is an [int], a fixed swizzle is generated.
  ///
  /// If [rotateAmount] is another [Logic], a [_Rotate] is created to
  /// conditionally rotate by different amounts based on the value of
  /// [rotateAmount]. The [maxAmount] is the largest value for which
  /// this rotation should support, which could be greater than the `width`
  /// of [rotateAmount].
  ///
  /// If no [maxAmount] is provided, it will default to the `width` of
  /// `this`.  The [maxAmount] will be not be larger than what could be
  /// represented by the maximum value of [rotateAmount].
  Logic _rotate(dynamic rotateAmount,
      {required RotateDirection direction, int? maxAmount}) {
    if (rotateAmount is int) {
      assert(
          maxAmount == null || rotateAmount <= maxAmount,
          'If `maxAmount` is provided with an integer `amount`,'
          ' it should meet the restriction.');

      return direction == RotateDirection.left
          ? RotateLeftFixed(this, rotateAmount).rotated
          : RotateRightFixed(this, rotateAmount).rotated;
    } else if (rotateAmount is Logic) {
      return direction == RotateDirection.left
          ? RotateLeft(this, rotateAmount, maxAmount: maxAmount).rotated
          : RotateRight(this, rotateAmount, maxAmount: maxAmount).rotated;
    } else {
      throw RohdHclException(
          'Unknown type for amount: ${rotateAmount.runtimeType}');
    }
  }

  /// Returns a [Logic] rotated left by [rotateAmount].
  ///
  /// If [rotateAmount] is an [int], a fixed swizzle is generated.
  ///
  /// If [rotateAmount] is another [Logic], a [RotateLeft] is created to
  /// conditionally rotate by different amounts based on the value of
  /// [rotateAmount]. The [maxAmount] is the largest value for which this
  /// rotation should support, which could be greater than the `width` of
  /// [rotateAmount].
  ///
  /// If no [maxAmount] is provided, it will default to the `width` of
  /// `this`.  The [maxAmount] will be not be larger than what could be
  /// represented by the maximum value of [rotateAmount].
  Logic rotateLeft(dynamic rotateAmount, {int? maxAmount}) =>
      _rotate(rotateAmount,
          maxAmount: maxAmount, direction: RotateDirection.left);

  /// Returns a [Logic] rotated right by [rotateAmount].
  ///
  /// If [rotateAmount] is an [int], a fixed swizzle is generated.
  ///
  /// If [rotateAmount] is another [Logic], a [RotateRight] is created to
  /// conditionally rotate by different amounts based on the value of
  /// [rotateAmount]. The [maxAmount] is the largest value for which this
  /// rotation should support, which could be greater than the `width` of
  /// [rotateAmount].
  ///
  /// If no [maxAmount] is provided, it will default to the `width` of
  /// `this`.  The [maxAmount] will be not be larger than what could be
  /// represented by the maximum value of [rotateAmount].
  Logic rotateRight(dynamic rotateAmount, {int? maxAmount}) =>
      _rotate(rotateAmount,
          maxAmount: maxAmount, direction: RotateDirection.right);
}

/// Adds rotation functions to [LogicValue].
extension RotateLogicValue on LogicValue {
  /// Rotates this value by [rotateAmount] in the specified [direction].
  LogicValue _rotate(int rotateAmount, {required RotateDirection direction}) {
    final split = direction == RotateDirection.left
        ? width - rotateAmount % width
        : rotateAmount % width;

    if (rotateAmount % width == 0) {
      return this;
    }

    return [
      getRange(0, split),
      getRange(split),
    ].swizzle();
  }

  /// Rotates this value by [rotateAmount] to the left.
  LogicValue rotateLeft(int rotateAmount) =>
      _rotate(rotateAmount, direction: RotateDirection.left);

  /// Rotates this value by [rotateAmount] to the right.
  LogicValue rotateRight(int rotateAmount) =>
      _rotate(rotateAmount, direction: RotateDirection.right);
}
