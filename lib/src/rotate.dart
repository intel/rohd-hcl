//
// rotate.dart
// Implementation of rotation for Logic and LogicValue.
//
// Author: Max Korbel
// 2023 February 17
//

import 'dart:math';

import 'package:rohd/rohd.dart';

/// A direction for something to rotate.
enum _RotateDirection {
  /// Rotate to the left.
  left,

  /// Rotate to the right.
  right
}

/// Rotates a [Logic] to the specified direction.
class _Rotate extends Module {
  /// The maximum amount that this [_Rotate] should support in rotation.
  final int maxAmount;

  /// The [_direction] that this [_Rotate] should rotate.
  final _RotateDirection _direction;

  /// The [rotated] result.
  Logic get rotated => output('rotated');

  /// Constructs a [Module] that rotates [original] to the specified
  /// [_direction] by [rotateAmount], up to [maxAmount].
  ///
  /// If no [maxAmount] is provided, it will default to the `width` of
  /// [original].  The [maxAmount] will be not be larger than what could be
  /// represented by the maximum value of [rotateAmount].
  _Rotate(this._direction, Logic original, Logic rotateAmount, {int? maxAmount})
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
        for (var i = 1; i < this.maxAmount; i++)
          CaseItem(
            Const(i, width: rotateAmount.width),
            [rotated < _rotateBy(i, original, _direction)],
          )
      ], defaultItem: [
        rotated < original,
      ])
    ]);
  }

  /// Rotates [original] by [rotateAmount] in the specified [direction].
  static Logic _rotateBy(
      int rotateAmount, Logic original, _RotateDirection direction) {
    final split = direction == _RotateDirection.left
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
  RotateLeft(Logic original, Logic rotateAmount, {super.maxAmount})
      : super(_RotateDirection.left, original, rotateAmount);
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
  RotateRight(Logic original, Logic rotateAmount, {super.maxAmount})
      : super(_RotateDirection.right, original, rotateAmount);
}

/// Adds rotation functions to [Logic].
extension RotateLogic on Logic {
  /// Returns a [Logic] rotated [direction] by [amount].
  ///
  /// If [amount] is an [int], a fixed swizzle is generated.
  ///
  /// If [amount] is another [Logic], a [_Rotate] is created to conditionally
  /// rotate by different amounts based on the value of [amount]. The
  /// [maxAmount] is the largest value for which this rotation should support,
  /// which could be greater than the `width` of [amount].
  ///
  /// If no [maxAmount] is provided, it will default to the `width` of
  /// `this`.  The [maxAmount] will be not be larger than what could be
  /// represented by the maximum value of [rotateAmount].
  Logic _rotate(dynamic amount,
      {required _RotateDirection direction, int? maxAmount}) {
    if (amount is int) {
      assert(
          maxAmount == null || amount <= maxAmount,
          'If `maxAmount` is provided with an integer `amount`,'
          ' it should meet the restriction.');

      return _Rotate._rotateBy(amount, this, direction);
    } else if (amount is Logic) {
      return direction == _RotateDirection.left
          ? RotateLeft(this, amount, maxAmount: maxAmount).rotated
          : RotateRight(this, amount, maxAmount: maxAmount).rotated;
    } else {
      // TODO: make an HCL type of exception for this
      throw Exception('Unknown type for amount: ${amount.runtimeType}');
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
          maxAmount: maxAmount, direction: _RotateDirection.left);

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
          maxAmount: maxAmount, direction: _RotateDirection.right);
}

/// Adds rotation functions to [LogicValue].
extension RotateLogicValue on LogicValue {
  /// Rotates this value by [rotateAmount] in the specified [direction].
  LogicValue _rotate(int rotateAmount, {required _RotateDirection direction}) {
    final split = direction == _RotateDirection.left
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
      _rotate(rotateAmount, direction: _RotateDirection.left);

  /// Rotates this value by [rotateAmount] to the right.
  LogicValue rotateRight(int rotateAmount) =>
      _rotate(rotateAmount, direction: _RotateDirection.right);
}
