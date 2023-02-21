//
// rotate_left.dart
// Implementation of left-rotate
//
// Author: Max Korbel
// 2023 February 17
//

import 'dart:math';

import 'package:rohd/rohd.dart';

enum _RotateDirection { left, right }

class _Rotate extends Module {
  final int maxAmount;

  final _RotateDirection _direction;

  Logic get rotated => output('rotated');

  /// TODO
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

  static Logic _rotateBy(
      int amount, Logic original, _RotateDirection direction) {
    final split = direction == _RotateDirection.left
        ? original.width - amount % original.width
        : amount % original.width;
    if (split == original.width) {
      return original;
    }

    return [
      original.getRange(0, split),
      original.getRange(split),
    ].swizzle();
  }
}

class RotateLeft extends _Rotate {
  RotateLeft(Logic original, Logic rotateAmount, {super.maxAmount})
      : super(_RotateDirection.left, original, rotateAmount);
}

class RotateRight extends _Rotate {
  RotateRight(Logic original, Logic rotateAmount, {super.maxAmount})
      : super(_RotateDirection.right, original, rotateAmount);
}

extension RotateLogic on Logic {
  ///TODO
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

  Logic rotateLeft(dynamic amount, {int? maxAmount}) =>
      _rotate(amount, maxAmount: maxAmount, direction: _RotateDirection.left);

  Logic rotateRight(dynamic amount, {int? maxAmount}) =>
      _rotate(amount, maxAmount: maxAmount, direction: _RotateDirection.right);
}

///TODO
extension RotateLogicValue on LogicValue {
  LogicValue _rotate(int amount, {required _RotateDirection direction}) {
    final split = direction == _RotateDirection.left
        ? width - amount % width
        : amount % width;
    if (split == width) {
      return this;
    }

    return [
      getRange(0, split),
      getRange(split),
    ].swizzle();
  }

  ///TODO
  LogicValue rotateLeft(int amount) =>
      _rotate(amount, direction: _RotateDirection.left);

  ///TODO
  LogicValue rotateRight(int amount) =>
      _rotate(amount, direction: _RotateDirection.right);
}
