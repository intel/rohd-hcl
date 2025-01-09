// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// binary_tree.dart
// A generator for creating binary tree reduction computations.
//
// 2025 January 8
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:math';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A generator utility which constructs a tree of 2-input / 1-output modules
/// or functions. Note that this is a pure generator class, not a [Module]
/// and is to be used in a [BinaryTreeModule] module to gather inputs to
/// feed this tree.
class BinaryTree {
  /// The final output of the tree.
  Logic get out => _out;

  /// The combinational depth of since the last flop.
  int get depth => _depth;

  /// The flop depth of the tree.
  int get flopDepth => _flopDepth;

  /// The 2-input operation to be performed at each node
  @protected
  final Logic Function(Logic a, Logic b) operation;

  @protected
  late final Logic _out;

  @protected
  late final int _depth;

  @protected
  late final int _flopDepth;

  /// Generate a node of a tree based on dividing the input [seq] into
  /// two halves and recursively constructing two child nodes to operate
  /// on each half. This generator allows for inputs of arbitrary length
  /// (NOT restricting to powers of 2).
  /// - [operation] is the operation to be performed at each node.
  /// Optional parameters to be used for creating a pipelined tree:
  /// - [clk], [reset], [enable] are optionally provided to allow for flopping.
  /// - [depthToFlop] specifies how many nodes deep before a flop is added.
  ///
  /// If the [operation] creates a wider output than its inputs and the inputs
  /// are not a power of two extension is needed on neighboring outputs to feed
  /// into dependent nodes.
  ///  - The [signExtend] option is available to use [Logic.signExtend] to
  /// widen operends, otherwise [Logic.zeroExtend] is used.
  BinaryTree(LogicArray seq, this.operation,
      {Logic? clk,
      Logic? enable,
      Logic? reset,
      int? depthToFlop,
      bool? signExtend}) {
    if (seq.elements.isEmpty) {
      throw RohdHclException("Don't use TreeOfTwoInputModules "
          'with an empty LogicArray');
    }
    if ((clk == null) & (depthToFlop != null)) {
      throw RohdHclException('clk needs to be provided in order to flop');
    }
    if (seq.dimensions[0] == 1) {
      _out = seq.elements[0];
      _depth = 0;
      _flopDepth = 0;
    } else {
      final elementWidth = seq.elements[0].width;
      final end = seq.dimensions[0];
      final half = seq.dimensions[0] ~/ 2;

      // TODO(desmonddak): find a better way to split a LogicArray on 1st dim
      final leftAry = LogicArray([half], elementWidth);
      leftAry.elements.forEachIndexed((i, e) => e <= seq.elements[i]);

      final a = BinaryTree(leftAry, operation,
          clk: clk, enable: enable, reset: reset, depthToFlop: depthToFlop);

      final rightAry = LogicArray([end - half], elementWidth);
      rightAry.elements.forEachIndexed((i, e) => e <= seq.elements[half + i]);
      final b = BinaryTree(rightAry, operation,
          clk: clk, enable: enable, reset: reset, depthToFlop: depthToFlop);

      // If uneven, align the flops as we join a and b here
      final av = condFlop(
          (a._flopDepth < b._flopDepth) ? clk : null,
          reset: reset,
          en: enable,
          a._out);
      final bv = condFlop(
          (a._flopDepth > b._flopDepth) ? clk : null,
          reset: reset,
          en: enable,
          b._out);

      final treeDepth = max(a.depth, b.depth);
      final doFlop = [
        if (depthToFlop != null)
          (treeDepth > 0) & (treeDepth % depthToFlop == 0)
        else
          false
      ].first;

      final v1 = condFlop(doFlop ? clk : null, reset: reset, en: enable, av);
      final v2 = condFlop(doFlop ? clk : null, reset: reset, en: enable, bv);

      _depth = doFlop ? 0 : treeDepth + 1;
      _flopDepth = max(a._flopDepth, b._flopDepth) + (doFlop ? 1 : 0);
      final int maxLen = max(v1.width, v2.width);
      final computed = operation(
          (signExtend ?? false) ? v1.signExtend(maxLen) : v1.zeroExtend(maxLen),
          (signExtend ?? false)
              ? v2.signExtend(maxLen)
              : v2.zeroExtend(maxLen));
      _out = computed;
    }
  }
}

/// Module using the [BinaryTree] generator.
class BinaryTreeModule extends Module {
  /// The final output of the tree.
  Logic get out => output('out');

  /// Return the cycle latency of the [BinaryTree].
  int get flopDepth => _tree.flopDepth;

  @protected
  late final BinaryTree _tree;

  /// Generate a node of the tree based on dividing the input [ary] into
  /// two halves and recursively constructing two child nodes to operate
  /// on each half.
  /// - [ary] is the input sequence to be reduced using the tree of operations.
  /// - [operation] is the operation to be performed at each node.
  /// Optional parameters to be used for creatign a pipelined tree:
  /// - [clk], [reset], [enable] are optionally provided to allow for flopping.
  /// - [depthToFlop] specifies how many nodes deep before a flop is added.
  BinaryTreeModule(LogicArray ary, Logic Function(Logic a, Logic b) operation,
      {Logic? clk,
      Logic? enable,
      Logic? reset,
      int? depthToFlop,
      super.name = 'binary_tree'}) {
    // Need to add the inputs for the logic sequence
    if (clk != null) {
      clk = addInput('clk', clk);
    }
    if (enable != null) {
      enable = addInput('enable', enable);
    }
    if (reset != null) {
      clk = addInput('clk', reset);
    }
    _tree = BinaryTree(ary, operation,
        clk: clk, enable: enable, reset: reset, depthToFlop: depthToFlop);

    addOutput('out', width: _tree.out.width) <= _tree.out;
  }
}
