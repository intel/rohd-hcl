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

/// A generator which constructs a tree of 2-input / 1-output modules
/// or functions. Note that this is a pure generator class, not a [Module]
/// and is to be used in a larger module that builds the tree.
class BinaryTreeNode {
  /// The final output of the tree.
  Logic get out => _out;

  /// The combinational depth of since the last flop.
  int get depth => _depth;

  /// The flop depth of the tree.
  int get flopDepth => _flopDepth;

  /// The 2-input operation to be performed at each node
  @protected
  final Logic Function(Logic a, Logic b) op;

  @protected
  late final Logic _out;

  @protected
  late final int _depth;

  @protected
  late final int _flopDepth;

  /// Generate a node of the tree based on dividing the input [seq] into
  /// two halves and recursively constructing two child nodes to operate
  /// on each half.
  /// - [op] is the operation to be performed at each node.
  /// Optional parameters to be used for creatign a pipelined tree:
  /// - [clk], [reset], [enable] are optionally provided to allow for flopping.
  /// - [depthToFlop] specifies how many nodes deep before a flop is added.
  BinaryTreeNode(List<Logic> seq, this.op,
      {Logic? clk, Logic? enable, Logic? reset, int? depthToFlop}) {
    if (seq.isEmpty) {
      throw RohdHclException("Don't use TreeOfTwoInputModules "
          'with an empty sequence');
    }
    if ((clk == null) & (depthToFlop != null)) {
      throw RohdHclException('clk needs to be provided in order to flop');
    }
    if (seq.length == 1) {
      _out = seq[0];
      _depth = 0;
      _flopDepth = 0;
    } else {
      final a = BinaryTreeNode(seq.getRange(0, seq.length ~/ 2).toList(), op,
          clk: clk, enable: enable, reset: reset, depthToFlop: depthToFlop);
      final b = BinaryTreeNode(
          seq.getRange(seq.length ~/ 2, seq.length).toList(), op,
          clk: clk, enable: enable, reset: reset, depthToFlop: depthToFlop);

      final treeDepth = max(a.depth, b.depth);

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
      final computed = op(v1.zeroExtend(maxLen), v2.zeroExtend(maxLen));
      _out = computed;
    }
  }
}

/// Module using the [BinaryTreeNode] generator.
class BinaryTreeModule extends Module {
  /// The final output of the tree.
  ///
  Logic get out => output('out');

  /// The flop depth of the tree.
  int get flopDepth => _tree.flopDepth;

  @protected
  late final BinaryTreeNode _tree;

  /// Generate a node of the tree based on dividing the input [seq] into
  /// two halves and recursively constructing two child nodes to operate
  /// on each half.
  /// - [seq] is the input sequence to be reduced using the tree of operations.
  /// - [op] is the operation to be performed at each node.
  /// Optional parameters to be used for creatign a pipelined tree:
  /// - [clk], [reset], [enable] are optionally provided to allow for flopping.
  /// - [depthToFlop] specifies how many nodes deep before a flop is added.
  BinaryTreeModule(List<Logic> seq, Logic Function(Logic a, Logic b) op,
      {Logic? clk,
      Logic? enable,
      Logic? reset,
      int? depthToFlop,
      super.name = 'my_tree'}) {
    seq = [
      for (var i = 0; i < seq.length; i++)
        addInput('seq$i', seq[i], width: seq[i].width)
    ];

    if (clk != null) {
      clk = addInput('clk', clk);
    }
    if (enable != null) {
      enable = addInput('enable', enable);
    }
    if (reset != null) {
      clk = addInput('clk', reset);
    }
    _tree = BinaryTreeNode(seq, op,
        clk: clk, enable: enable, reset: reset, depthToFlop: depthToFlop);

    addOutput('out', width: _tree.out.width) <= _tree.out;
  }
}

/// A generator utility which constructs a tree of 2-input / 1-output modules
/// or functions. Note that this is a pure generator class, not a [Module]
/// and is to be used in a [BinaryTreeAryModule] module to gather inputs to
/// feed this tree.
class BinaryTreeNodeAry {
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

  /// This class is experimental:  an effort to use [LogicArray] instead
  /// of [List<Logic>] to generalize the binary tree construction.
  /// - A fundamental issue is about extension of operands:  the base case
  /// of [Logic]s in a [List] can easily use sign extension or zero extension.
  /// But when we think of a [LogicArray] as a list of 1-less-dimension
  /// [LogicArray]s, we can still do a binary tree, but not easily
  /// with sign extension if needed (or is it sensible).
  /// Yet we want the base case to be supported as well.
  /// Perhaps the solution is to not allow sign extension on higher-dimensional
  /// [LogicArray], just support it when it is one-dimensional.

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
  BinaryTreeNodeAry(LogicArray seq, this.operation,
      {Logic? clk, Logic? enable, Logic? reset, int? depthToFlop}) {
    if (seq.elements.isEmpty) {
      throw RohdHclException("Don't use TreeOfTwoInputModules "
          'with an empty LogicArray');
    }
    if ((clk == null) & (depthToFlop != null)) {
      throw RohdHclException('clk needs to be provided in order to flop');
    }
    // _out is a 1 dimension less LogicArray
    final reducedDimensions = List<int>.from(seq.dimensions)..removeAt(0);
    print('reduced; ${reducedDimensions.length}');

    if (reducedDimensions.length > 1) {
      _out = LogicArray(reducedDimensions, seq.elementWidth);
    } else {
      _out = Logic(width: seq.elementWidth);
    }
    if (seq.dimensions[0] == 1) {
      _out <= seq.elements[0];
      _depth = 0;
      _flopDepth = 0;
    } else {
      final elementWidth = seq.elements[0].width;
      final end = seq.dimensions[0];
      final half = seq.dimensions[0] ~/ 2;

      // TODO(desmonddak): find a better way to split a LogicArray on 1st dim
      final leftAry = LogicArray([half], elementWidth);
      leftAry.elements.forEachIndexed((i, e) => e <= seq.elements[i]);

      final a = BinaryTreeNodeAry(leftAry, operation,
          clk: clk, enable: enable, reset: reset, depthToFlop: depthToFlop);

      final rightAry = LogicArray([end - half], elementWidth);
      rightAry.elements.forEachIndexed((i, e) => e <= seq.elements[half + i]);
      final b = BinaryTreeNodeAry(rightAry, operation,
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
      final computed = operation(v1, v2);
      _out <= computed;
    }
  }
}

/// Module using the [BinaryTreeNodeAry] generator.
class BinaryTreeAryModule extends Module {
  /// The final output of the tree.
  Logic get out => output('out');

  /// Return the cycle latency of the [BinaryTreeNodeAry].
  int get flopDepth => _tree.flopDepth;

  @protected
  late final BinaryTreeNodeAry _tree;

  /// Generate a node of the tree based on dividing the input [ary] into
  /// two halves and recursively constructing two child nodes to operate
  /// on each half.
  /// - [ary] is the input sequence to be reduced using the tree of operations.
  /// - [operation] is the operation to be performed at each node.
  /// Optional parameters to be used for creatign a pipelined tree:
  /// - [clk], [reset], [enable] are optionally provided to allow for flopping.
  /// - [depthToFlop] specifies how many nodes deep before a flop is added.
  BinaryTreeAryModule(
      LogicArray ary, Logic Function(Logic a, Logic b) operation,
      {Logic? clk,
      Logic? enable,
      Logic? reset,
      int? depthToFlop,
      super.name = 'binary_tree'}) {
    ary = addInputArray('array', ary,
        dimensions: ary.dimensions, elementWidth: ary.elementWidth);
    if (clk != null) {
      clk = addInput('clk', clk);
    }
    if (enable != null) {
      enable = addInput('enable', enable);
    }
    if (reset != null) {
      clk = addInput('clk', reset);
    }
    _tree = BinaryTreeNodeAry(ary, operation,
        clk: clk, enable: enable, reset: reset, depthToFlop: depthToFlop);

    addOutput('out', width: _tree.out.width) <= _tree.out;
  }
}
