// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// reduction_tree.dart
// A generator for creating reduction tree reduction computations.
//
// 2025 January 10
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/binary_tree.dart';

/// A generator which constructs a tree of k-input / 1-output modules
/// or functions. Note that this is a pure generator class, not a [Module]
/// and is to be used in a larger module that builds the tree.
class ReductionTreeNode {
  /// The final output of the current node.
  Logic get out => _out;

  /// The combinational depth since the last flop.
  int get depth => _depth;

  /// The current flop depth of the tree from this node to the leaves.
  int get flopDepth => _flopDepth;

  /// The 2-input operation to be performed at each node.
  @protected
  final Logic Function(List<Logic> inputs) operation;

  @protected
  late final Logic _out;

  @protected
  late final int _depth;

  @protected
  late final int _flopDepth;

  @protected
  late final Logic? clk;

  @protected
  late final Logic? reset;

  @protected
  late final Logic? enable;

  late final int depthToFlop;

  /// Generate a node of a reduction tree based on dividing the input [seq] into
  /// [reduce] segments and recursively constructing two child nodes to operate
  /// on each segment.
  /// - [reduce] is the size of input to each segment for the [operation]
  /// - [operation] is the operation to be performed at each node.
  /// Optional parameters to be used for creatign a pipelined tree:
  /// - [clk], [reset], [enable] are optionally provided to allow for flopping.
  /// - [depthToFlop] specifies how many nodes deep before a flop is added.
  ReductionTreeNode(List<Logic> seq, this.operation,
      {int reduce = 2, this.clk, this.enable, this.reset, int? depthToFlop}) {
    if (seq.isEmpty) {
      throw RohdHclException("Don't use ReductionTreeNode "
          'with an empty sequence');
    }
    if ((clk == null) & (depthToFlop != null)) {
      throw RohdHclException('clk needs to be provided in order to flop');
    }
    if (seq.length < reduce) {
      _out = operation(seq);
      _depth = 0;
      _flopDepth = 0;
    } else {
      final segment = seq.length ~/ reduce;

      final children = <ReductionTreeNode>[];
      var cnt = 0;
      for (var i = 0; i < reduce; i++) {
        final s = cnt;
        final e = (i < reduce - 1) ? cnt + segment : seq.length;
        final c = ReductionTreeNode(
            seq.getRange(s, e).toList(),
            reduce: reduce,
            operation,
            clk: clk,
            enable: enable,
            reset: reset,
            depthToFlop: depthToFlop);
        children.add(c);
        cnt += segment;
      }
      final flopDepth = children.map((e) => e.flopDepth).reduce(max);
      final results = [
        for (final c in children)
          condFlop(
              (c.flopDepth < flopDepth) ? clk : null,
              reset: reset,
              en: enable,
              c.out)
      ];

      final treeDepth = children.map((e) => e.depth).reduce(max);
      final doFlop = [
        if (depthToFlop != null)
          (treeDepth > 0) & (treeDepth % depthToFlop == 0)
        else
          false
      ].first;

      final resultsFlop = [
        for (final r in results)
          condFlop(doFlop ? clk : null, reset: reset, en: enable, r)
      ];
      _depth = doFlop ? 0 : treeDepth + 1;
      _flopDepth = flopDepth + (doFlop ? 1 : 0);
      final maxLen = children.map((e) => e.out.width).reduce(max);

      final resultsFinal = [for (final r in resultsFlop) r.zeroExtend(maxLen)];
      final computed = operation(resultsFinal);
      _out = computed;
    }
  }
}

/// Module driving inputs to the [ReductionTreeNode] generator.
class ReductionTreeModule extends Module {
  /// The final output of the tree.
  Logic get out => output('out');

  /// The flop depth of the tree.
  int get flopDepth => _tree.flopDepth;

  @protected
  late final ReductionTreeNode _tree;

  /// Generate a node of the tree based on dividing the input [seq] into
  /// segments and recursively constructing two child nodes to operate
  /// on each segments.
  /// - [seq] is the input sequence to be reduced using the tree of operations.
  /// - [operation] is the operation to be performed at each node.
  /// Optional parameters to be used for creatign a pipelined tree:
  /// - [clk], [reset], [enable] are optionally provided to allow for flopping.
  /// - [depthToFlop] specifies how many nodes deep before a flop is added.
  ReductionTreeModule(
      List<Logic> seq, Logic Function(List<Logic> inputs) operation,
      {int reduce = 2,
      Logic? clk,
      Logic? enable,
      Logic? reset,
      int? depthToFlop,
      super.name = 'my_tree'}) {
    if (seq.isEmpty) {
      throw RohdHclException("Don't use reductionTreeModule "
          'with an empty sequence');
    }
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
    _tree = ReductionTreeNode(
        seq,
        reduce: reduce,
        operation,
        clk: clk,
        enable: enable,
        reset: reset,
        depthToFlop: depthToFlop);

    addOutput('out', width: _tree.out.width) <= _tree.out;
  }
}
