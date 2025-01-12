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

  /// Optional clock input for flopping the tree
  @protected
  late final Logic? clk;

  /// Optional reset input for flopping the tree
  @protected
  late final Logic? reset;

  /// Optional enable input for flopping the tree
  @protected
  late final Logic? enable;

  /// specified depth of nodes at which to flop
  late final int? depthToFlop;

  /// The specified reduction parameter for the tree (e.g., binary = 2).
  late final int reduce;

  /// Generate a node of a reduction tree based on dividing the input [seq] into
  /// [reduce] segments and recursively constructing two child nodes to operate
  /// on each segment.
  /// - [reduce] reduction parameter for the tree (e.g., binary = 2).
  /// - [operation] is the operation to be performed at each node.
  /// Optional parameters to be used for creatign a pipelined tree:
  /// - [clk], [reset], [enable] are optionally provided to allow for flopping.
  /// - [depthToFlop] specifies how many nodes deep before a flop is added.
  ReductionTreeNode(List<Logic> seq, this.operation,
      {this.reduce = 2, this.clk, this.enable, this.reset, this.depthToFlop}) {
    if (seq.isEmpty) {
      throw RohdHclException("Don't use ReductionTreeNode "
          'with an empty sequence');
    }
    if ((clk == null) & (depthToFlop != null)) {
      throw RohdHclException('clk needs to be provided in order to flop');
    }

    final v = iter(seq);
    _out = v.value;
    _depth = v.depth;
    _flopDepth = v.flopDepth;
  }

  /// Iteration
  ({Logic value, int depth, int flopDepth}) iter(List<Logic> seq) {
    if (seq.length < reduce) {
      return (value: operation(seq), depth: 0, flopDepth: 0);
    } else {
      final children = <({Logic value, int depth, int flopDepth})>[];
      final segment = seq.length ~/ reduce;
      var cnt = 0;
      for (var i = 0; i < reduce; i++) {
        final s = cnt;
        final e = (i < reduce - 1) ? cnt + segment : seq.length;
        final c = iter(seq.getRange(s, e).toList());
        children.add(c);
        cnt += segment;
      }
      final flopDepth = children.map((c) => c.flopDepth).reduce(max);
      final treeDepth = children.map((c) => c.depth).reduce(max);
      final doFlop = [
        if (depthToFlop != null)
          (treeDepth > 0) & (treeDepth % depthToFlop! == 0)
        else
          false
      ].first;

      final maxLen = children.map((c) => c.value.width).reduce(max);

      final alignedValues = children.map((c) => condFlop(
          (c.flopDepth < flopDepth) ? clk : null,
          reset: reset,
          en: enable,
          c.value));

      final resultsFlop = [
        for (final r in alignedValues)
          condFlop(doFlop ? clk : null, reset: reset, en: enable, r)
      ];
      final resultsFinal = [for (final r in resultsFlop) r.zeroExtend(maxLen)];
      final computed = operation(resultsFinal);
      return (
        value: computed,
        depth: doFlop ? 0 : treeDepth + 1,
        flopDepth: flopDepth + (doFlop ? 1 : 0)
      );
    }
  }
}

/// Module driving inputs to the [ReductionTreeNode] generator.
class ReductionTreeModule extends Module {
  /// Get THIS from a better pipelined example
  @protected
  late final Logic? clk;

  /// Get THIS from a better pipelined example
  @protected
  late final Logic? reset;

  /// Get THIS from a better pipelined example
  @protected
  late final Logic? enable;

  /// The final output of the tree.
  Logic get out => output('out');

  /// The combinational depth since the last flop.
  int get depth => _tree.depth;

  /// The current flop depth of the tree from this node to the leaves.
  int get flopDepth => _tree.flopDepth;

  /// The 2-input operation to be performed at each node.
  @protected
  final Logic Function(List<Logic> inputs) operation;

  /// specified depth of nodes at which to flop
  @protected
  late final int? depthToFlop;

  /// Specified width of reduction node (e.g., binary=2)
  @protected
  late final int reduce;

  @protected
  late final ReductionTreeNode _tree;

  /// Generate a node of the tree based on dividing the input [seq] into
  /// segments and recursively constructing two child nodes to operate
  /// on each segments.
  /// - [seq] is the input sequence to be reduced using the tree of operations.
  /// - [operation] is the operation to be performed at each node.
  /// - [reduce] is the width of reduction at each node in the tree (e.g.,
  /// binary = 2).
  /// Optional parameters to be used for creatign a pipelined tree:
  /// - [clk], [reset], [enable] are optionally provided to allow for flopping.
  /// - [depthToFlop] specifies how many nodes deep before a flop is added.
  ReductionTreeModule(List<Logic> seq, this.operation,
      {this.reduce = 2,
      Logic? clk,
      Logic? enable,
      Logic? reset,
      this.depthToFlop,
      super.name = 'my_tree'}) {
    if (seq.isEmpty) {
      throw RohdHclException("Don't use reductionTreeModule "
          'with an empty sequence');
    }
    seq = [
      for (var i = 0; i < seq.length; i++)
        addInput('seq$i', seq[i], width: seq[i].width)
    ];
    clk = (clk != null) ? addInput('clk', clk) : null;
    enable = (enable != null) ? addInput('enable', enable) : null;
    reset = (reset != null) ? addInput('reset', reset) : null;
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
