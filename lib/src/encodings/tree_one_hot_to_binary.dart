// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tree_one_hot_to_binary.dart
// Implementation of one hot codec from one hot to binary via a tree
//
// 2023 February 24
// Author: Desmond Kirkpatrick

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Module for binary-tree recursion for decoding one-hot.
class TreeOneHotToBinary extends OneHotToBinary {
  /// Top level module for computing binary to one-hot using recursion
  TreeOneHotToBinary(super.onehot, {super.name = 'tree_one_hot_to_binary'})
      : super.base() {
    binary <= _NodeOneHotToBinary(onehot).binary;
  }
}

/// Internal class for binary-tree recursion for decoding one-hot
class _NodeOneHotToBinary extends Module {
  /// The [binary] decoded result.
  Logic get binary => output('binary');

  /// Build a shorter-input module for recursion
  /// (borrowed from Chisel OHToUInt)
  _NodeOneHotToBinary(Logic onehot) : super(name: 'node_one_hot_to_binary') {
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
      final hi = onehot.getRange(mid).zeroExtend(mid).named('hi');
      final lo = onehot.getRange(0, mid).zeroExtend(mid).named('lo');
      final recurse = lo | hi;
      final response = _NodeOneHotToBinary(recurse).binary;
      binary <= [hi.or(), response].swizzle();
    }
  }
}
