// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// one_hot.dart
// Implementation of one hot codec for Logic
//
// 2023 February 24
// Author: Desmond Kirkpatrick
//

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/utils.dart';

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

/// Decodes a one-hot number into binary using a for-loop
class OneHotToBinary extends Module {
  /// The [binary] decoded result.
  Logic get binary => output('binary');
  Logic get error => output('error');

  /// Constructs a [Module] which decodes a one-hot or thermometer-encoded
  /// number [onehot] into a 2s complement number [binary] by encoding
  /// the position of the '1'
  OneHotToBinary(Logic onehot) {
    onehot = addInput('onehot', onehot, width: onehot.width);
    addOutput('binary', width: log2Ceil(onehot.width + 1));
    addOutput('error');
    Combinational([
      Case(onehot, conditionalType: ConditionalType.unique, [
        for (var i = 0; i < onehot.width; i++)
          CaseItem(
            Const(BigInt.from(1) << i, width: onehot.width),
            [
              binary < Const(i, width: binary.width),
              error < 0,
            ],
          )
      ], defaultItem: [
        binary < Const(0, width: binary.width),
        error < 1,
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
      binary <= [hi.or(), response].swizzle();
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
