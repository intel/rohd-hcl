// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// reduction_tree.dart
// A generator for creating tree reduction computations.
//
// 2025 January 10
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Recursive Node for Reduction Tree
class ReductionTree extends Module {
  /// Operation to be performed at each node. Note that [operation] can widen
  /// the output. The logic function must support the operation for [2 to radix]
  /// inputs.
  @protected
  final Logic Function(List<Logic> inputs, {String name}) operation;

  /// Specified width of input to each reduction node (e.g., binary: radix=2)
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

  /// Optional [reset] input to reset pipeline.
  @protected
  late final Logic? reset;

  /// Optional [enable] input to enable pipeline.
  @protected
  late final Logic? enable;

  /// The final output of the tree computation.
  Logic get out => output('out');

  /// The combinational depth since the last flop. The total compute depth of
  /// the tree is: depth + flopDepth * depthToflop;
  int get depth => _computed.depth;

  /// The flop depth of the tree from the output to the leaves.
  int get latency => _computed.flopDepth;

  /// The input sequence
  @protected
  late final List<Logic> sequence;

  /// Capture the record of compute: the final value, its depth (from last
  /// flop or input), and its flopDepth if pipelined.
  late final ({Logic value, int depth, int flopDepth}) _computed;

  /// Local conditional flop using module reset/enable
  Logic localFlop(Logic d, {bool doFlop = false}) =>
      condFlop(doFlop ? clk : null, reset: reset, en: enable, d);

  /// Generate a tree based on dividing the input [sequence] of a node into
  /// segments, recursively constructing [radix] child nodes to operate
  /// on each segment.
  /// - [sequence] is the input sequence to be reduced using the tree of
  /// operations.
  /// - Logic Function(List<Logic> inputs, {String name}) [operation]
  /// is the operation to be performed at each node. Note that [operation]
  /// can widen the output. The logic function must support the operation for
  /// (2 to [radix]) inputs.
  /// - [radix] is the width of reduction at each node in the tree (e.g.,
  /// binary: radix=2).
  /// - [signExtend] if true, use sign-extension to widen Logic values as
  /// needed in the tree, otherwise use zero-extension (default).
  ///
  /// Optional parameters to be used for creating a pipelined computation tree:
  /// - [clk], [reset], [enable] are optionally provided to allow for flopping.
  /// - [depthToFlop] specifies how many nodes deep separate flops.
  ReductionTree(List<Logic> sequence, this.operation,
      {this.radix = 2,
      this.signExtend = false,
      this.depthToFlop,
      Logic? clk,
      Logic? enable,
      Logic? reset,
      super.name = 'reduction_tree'})
      : super(
            definitionName: 'ReductionTreeNode_R${radix}_L${sequence.length}') {
    this.sequence = [
      for (var i = 0; i < sequence.length; i++)
        addInput('seq$i', sequence[i], width: sequence[i].width)
    ];
    this.clk = (clk != null) ? addInput('clk', clk) : null;
    this.enable = (enable != null) ? addInput('enable', enable) : null;
    this.reset = (reset != null) ? addInput('reset', reset) : null;

    if (this.sequence.length < radix) {
      final value = operation(this.sequence);
      addOutput('out', width: value.width) <= value;
      _computed = (value: output('out'), depth: 0, flopDepth: 0);
    } else {
      final results = <({Logic value, int depth, int flopDepth})>[];
      final segment = this.sequence.length ~/ radix;

      var pos = 0;
      for (var i = 0; i < radix; i++) {
        final tree = ReductionTree(
            this
                .sequence
                .getRange(
                    pos, (i < radix - 1) ? pos + segment : this.sequence.length)
                .toList(),
            operation,
            radix: radix,
            signExtend: signExtend,
            depthToFlop: depthToFlop,
            clk: this.clk,
            enable: this.enable,
            reset: this.reset);
        results.add(tree._computed);
        pos += segment;
      }
      final flopDepth = results.map((c) => c.flopDepth).reduce(max);
      final treeDepth = results.map((c) => c.depth).reduce(max);

      final alignedResults = results
          .map((c) => localFlop(c.value, doFlop: c.flopDepth < flopDepth));

      final depthFlop = (depthToFlop != null) &&
          (treeDepth > 0) & (treeDepth % depthToFlop! == 0);
      final resultsFlop =
          alignedResults.map((r) => localFlop(r, doFlop: depthFlop));

      final alignWidth = results.map((c) => c.value.width).reduce(max);
      final resultsExtend = resultsFlop.map((r) =>
          signExtend ? r.signExtend(alignWidth) : r.zeroExtend(alignWidth));

      final value = operation(resultsExtend.toList(),
          name: 'reduce_d${(treeDepth + 1) + flopDepth * (depthToFlop ?? 0)}');

      addOutput('out', width: value.width) <= value;
      _computed = (
        value: output('out'),
        depth: depthFlop ? 0 : treeDepth + 1,
        flopDepth: flopDepth + (depthFlop ? 1 : 0)
      );
    }
  }
}
