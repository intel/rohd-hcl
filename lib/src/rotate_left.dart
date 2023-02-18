//
// rotate_left.dart
// Implementation of left-rotate
//
// Author: Max Korbel
// 2023 February 17
//

import 'package:rohd/rohd.dart';

extension RotateLeftLogic on Logic {
  Logic rotateLeft(dynamic amount) {
    // TODO: move this to a module?
    if (amount is int) {
      final amountModulo = amount % width;

      if (amountModulo == 0) {
        return this;
      }

      return [
        getRange(0, amountModulo),
        getRange(amountModulo),
      ].swizzle();
    } else if (amount is Logic) {
      final amountModulo = amount % width;

      return (this << amountModulo) |
          (this >> (Const(width, width: width) - amountModulo));
    } else {
      // TODO: make an HCL type of exception for this
      throw Exception('Unknown type for amount: ${amount.runtimeType}');
    }
  }
}

// TODO: offer on LogicValue as well