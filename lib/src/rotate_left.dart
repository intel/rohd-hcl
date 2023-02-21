//
// rotate_left.dart
// Implementation of left-rotate
//
// Author: Max Korbel
// 2023 February 17
//

import 'dart:math';

import 'package:rohd/rohd.dart';

class RotateLeft extends Module {
  final int maxAmount;

  Logic get rotated => output('rotated');

  Logic get _original => input('original');

  /// TODO
  RotateLeft(Logic original, Logic rotateAmount, {int? maxAmount})
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
            [rotated < _rotateBy(i, original)],
          )
      ], defaultItem: [
        rotated < original,
      ])
    ]);
  }

  static Logic _rotateBy(int amount, Logic original) {
    final split = original.width - amount % original.width;
    if (split == original.width) {
      return original;
    }

    return [
      original.getRange(0, split),
      original.getRange(split),
    ].swizzle();
  }
}

extension RotateLeftLogic on Logic {
  ///TODO
  Logic rotateLeft(dynamic amount, {int? maxAmount}) {
    if (amount is int) {
      assert(
          maxAmount == null || amount <= maxAmount,
          'If `maxAmount` is provided with an integer `amount`,'
          ' it should meet the restriction.');

      return RotateLeft._rotateBy(amount, this);
    } else if (amount is Logic) {
      return RotateLeft(this, amount, maxAmount: maxAmount).rotated;
    } else {
      // TODO: make an HCL type of exception for this
      throw Exception('Unknown type for amount: ${amount.runtimeType}');
    }
  }
}

// TODO: offer on LogicValue as well
