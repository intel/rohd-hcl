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
  TreeOneHotToBinary(super.onehot,
      {super.generateError, super.name = 'tree_one_hot_to_binary'})
      : super.base() {
    final node = _NodeOneHotToBinary(onehot, generateMultiple: generateError);
    binary <= node.binary;

    if (generateError) {
      error! <= ~onehot.or() | node.multiple!;
    }
  }
}

/// Internal class for binary-tree recursion for decoding one-hot
class _NodeOneHotToBinary extends Module {
  /// The [binary] decoded result.
  Logic get binary => output('binary');

  /// If `true`, then the [multiple] output will be generated.
  final bool generateMultiple;

  /// Indicates that multiple bits (>1) were asserted.
  Logic? get multiple => tryOutput('multiple');

  /// Build a shorter-input module for recursion
  /// (borrowed from Chisel OHToUInt)
  _NodeOneHotToBinary(Logic onehot, {this.generateMultiple = false})
      : super(
            name: 'node_one_hot_to_binary',
            definitionName: 'NodeOneHotToBinary_W${onehot.width}') {
    final wid = onehot.width;
    onehot = addInput('onehot', onehot, width: wid);

    if (generateMultiple) {
      addOutput('multiple');
    }

    if (wid <= 2) {
      addOutput('binary');
      //Log2 of 2-bit quantity
      if (wid == 2) {
        binary <= onehot[1];

        if (generateMultiple) {
          multiple! <= onehot.and();
        }
      } else {
        binary <= Const(0);

        if (generateMultiple) {
          multiple! <= Const(0);
        }
      }
    } else {
      final mid = 1 << (log2Ceil(wid) - 1);
      addOutput('binary', width: log2Ceil(mid + 1));
      final hi = onehot.getRange(mid).zeroExtend(mid).named('hi');
      final lo = onehot.getRange(0, mid).zeroExtend(mid).named('lo');
      final recurse = lo | hi;
      final anyHi = hi.or().named('any_hi');
      final subNode =
          _NodeOneHotToBinary(recurse, generateMultiple: generateMultiple);
      final response = subNode.binary;
      binary <= [anyHi, response].swizzle();

      if (generateMultiple) {
        final anyLo = lo.or().named('any_lo');
        multiple! <= (anyHi & anyLo) | subNode.multiple!;
      }
    }
  }
}
