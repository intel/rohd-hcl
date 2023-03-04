//
// one_hot.dart
// Implementation of one hot codec for Logic
//
// Author: Desmond Kirkpatrick
// 2023 February 24
//

import 'dart:math';
import 'package:rohd/rohd.dart';

/// Compute the bit width needed to store w addresses
int log2Ceil(int w) => (log(w) / log(2)).ceil();

/// Encodes a binary number into one-hot
class BinaryToOneHot extends Module {
  /// The [encoded] one-hot result.
  Logic get encoded => output('encoded');

  /// Constructs a [Module] which encodes a 2's complement number [binary]
  /// into a one-hot, or thermometer code
  BinaryToOneHot(Logic binary) {
    binary = addInput('binary', binary, width: binary.width);
    addOutput('encoded', width: pow(2, binary.width).toInt());
    encoded <= Const(1, width: encoded.width) << binary;
  }
}

/// Computes an Or-reduction of an input
class OrReduction extends Module {
  /// The [orvalue] decoded result.
  Logic get orvalue => output('orvalue');

  /// Constructs a [Module] which computes an Or-reduction on [in]
  /// Really poor implementation to just have basic functionality
  OrReduction(Logic input) {
    addOutput('orvalue');
    Combinational([
      IfBlock([
        // Do we have a != comparator?
        Iff(input.eq(0), [orvalue < Const(0, width: 1)]),
        Else([orvalue < Const(1, width: 1)]),
      ])
    ]);
  }
}

/// Decodes a one-hot number into binary using a for-loop
class OneHotToBinary extends Module {
  /// The [binary] decoded result.
  Logic get binary => output('binary');

  /// Constructs a [Module] which decodes a one-hot or thermometer-encoded
  /// number [onehot] into a 2s complement number [binary] by encoding
  /// the position of the '1'
  OneHotToBinary(Logic onehot) {
    onehot = addInput('onehot', onehot, width: onehot.width);
    addOutput('binary', width: log2Ceil(onehot.width + 1));
    Combinational([
      Case(onehot, conditionalType: ConditionalType.unique, [
        for (var i = 0; i < onehot.width; i++)
          CaseItem(
            Const(BigInt.from(1) << i, width: onehot.width),
            [binary < Const(i, width: binary.width)],
          )
      ], defaultItem: [
        binary < Const(binary.width, width: binary.width)
      ])
    ]);
  }
}

/// Internal class for binary-tree recursion for decoding one-hot
class _NodeOneHotToBinary extends Module {
  /// The [binary] decoded result.
  Logic get binary => output('binary');

  /// Build a shorter-input module for recursion
  /// (borrowed from Chisel OHToUInt)
  _NodeOneHotToBinary(Logic onehot) {
    final wid = onehot.width;
    onehot = addInput('onehot', onehot, width: wid);

    if (wid <= 2) {
      addOutput('binary');
      //Log2 of 2-bit quantity
      if (wid == 2) {
        binary <= onehot[1];
      } else {
        binary <= Const(0, width: 1);
      }
    } else {
      final mid = 1 << (log2Ceil(wid) - 1);
      addOutput('binary', width: log2Ceil(mid + 1));
      final hi = onehot.getRange(mid).zeroExtend(mid);
      final lo = onehot.getRange(0, mid).zeroExtend(mid);
      final recurse = lo | hi;
      final response = _NodeOneHotToBinary(recurse).binary;
      binary <= [OrReduction(hi).orvalue, response].swizzle();
    }
  }
}

/// Module for binary-tree recursion for decoding one-hot
class TreeOneHotToBinary extends Module {
  /// The [binary] decoded result.
  Logic get binary => output('binary');

  /// Top level module for computing binary to one-hot using recursion
  TreeOneHotToBinary(Logic one) {
    final ret = _NodeOneHotToBinary(one).binary;
    addOutput('binary', width: ret.width);
    binary <= ret;
  }
}
