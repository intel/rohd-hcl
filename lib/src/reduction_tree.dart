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

/// A generator which constructs a tree of k-input / 1-output modules.
class ReductionTree extends Module {
  /// The 2-input operation to be performed at each node.
  @protected
  final Logic Function(List<Logic> inputs) operation;

  /// Specified width of reduction node (e.g., binary: radix=2)
  @protected
  late final int radix;

  /// When [signExtend] is true, use sign-extension on values,
  /// otherwise use zero-extension.
  @protected
  late final bool signExtend;

  /// Specified depth of nodes at which to flop (requires [clk]).
  @protected
  late final int? depthToFlop;

  /// Optional [clk] input to create pipeline.
  @protected
  late final Logic? clk;

  /// Optional [reset] input to create pipeline.
  @protected
  late final Logic? reset;

  /// Optional [enable] input to create pipeline.
  @protected
  late final Logic? enable;

  /// The final output of the tree.
  Logic get out => output('out');

  /// The current flop depth of the tree from this node to the leaves.
  int get flopDepth => _flopDepth;

  /// The combinational depth since the last flop. The total compute depth of
  /// the tree is: depth + flopDepth * depthToflop;
  int get depth => _depth;

  /// [_out] field for storage of final tree computation output.
  @protected
  late final Logic _out;

  /// [_depth]  field for storage of full tree depth.
  @protected
  late final int _depth;

  /// [_flopDepth]  field for storage of full tree sequential depth.
  @protected
  late final int _flopDepth;

  /// Generate a node of the tree based on dividing the input [seq] into
  /// segments, recursively constructing [radix] child nodes to operate
  /// on each segment.
  /// - [seq] is the input sequence to be reduced using the tree of operations.
  /// - Logic Function(List<Logic> inputs) [operation] is the operation to be
  /// performed at each node. Note that [operation] can widen the output.
  /// - [radix] is the width of reduction at each node in the tree (e.g.,
  /// binary: radix=2).
  /// - [signExtend] if true, use sign-extension to widen [Logic] values as
  /// needed in the tree, otherwise use zero-extension (default).
  ///
  /// Optional parameters to be used for creating a pipelined computation tree:
  /// - [clk], [reset], [enable] are optionally provided to allow for flopping.
  /// - [depthToFlop] specifies how many nodes deep separate flops.
  ReductionTree(List<Logic> seq, this.operation,
      {this.radix = 2,
      Logic? clk,
      Logic? enable,
      Logic? reset,
      this.signExtend = false,
      this.depthToFlop,
      super.name = 'reduction_tree'}) {
    if (seq.isEmpty) {
      throw RohdHclException("Don't use ReductionTree "
          'with an empty sequence');
    }
    seq = [
      for (var i = 0; i < seq.length; i++)
        addInput('seq$i', seq[i], width: seq[i].width)
    ];
    this.clk = (clk != null) ? addInput('clk', clk) : null;
    this.enable = (enable != null) ? addInput('enable', enable) : null;
    this.reset = (reset != null) ? addInput('reset', reset) : null;

    final v = reductionTreeRecurse(seq);
    _out = v.value;
    _depth = v.depth;
    _flopDepth = v.flopDepth;
    addOutput('out', width: _out.width) <= _out;
  }

  /// Recursively construct the computation tree
  ({Logic value, int depth, int flopDepth}) reductionTreeRecurse(
      List<Logic> seq) {
    if (seq.length < radix) {
      return (value: operation(seq), depth: 0, flopDepth: 0);
    } else {
      final results = <({Logic value, int depth, int flopDepth})>[];
      final segment = seq.length ~/ radix;
      var cnt = 0;
      for (var i = 0; i < radix; i++) {
        final c = reductionTreeRecurse(seq
            .getRange(cnt, (i < radix - 1) ? cnt + segment : seq.length)
            .toList());
        results.add(c);
        cnt += segment;
      }
      final flopDepth = results.map((c) => c.flopDepth).reduce(max);
      final treeDepth = results.map((c) => c.depth).reduce(max);
      final doFlop = [
        if (depthToFlop != null)
          (treeDepth > 0) & (treeDepth % depthToFlop! == 0)
        else
          false
      ].first;

      final alignWidth = results.map((c) => c.value.width).reduce(max);

      final alignedResults = results.map((c) => condFlop(
          (c.flopDepth < flopDepth) ? clk : null,
          reset: reset,
          en: enable,
          c.value));

      final resultsFlop = [
        for (final r in alignedResults)
          condFlop(doFlop ? clk : null, reset: reset, en: enable, r)
      ];
      final resultsFinal = [
        for (final r in resultsFlop)
          signExtend ? r.signExtend(alignWidth) : r.zeroExtend(alignWidth)
      ];
      final computed = operation(resultsFinal);
      return (
        value: computed,
        depth: doFlop ? 0 : treeDepth + 1,
        flopDepth: flopDepth + (doFlop ? 1 : 0)
      );
    }
  }
}
