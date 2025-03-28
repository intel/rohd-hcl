// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// reduction_tree.dart
// A generator for creating tree reduction computations.
//
// 2025 January 10
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Recursive Node for Reduction Tree
class ReductionTree extends Module {
  /// The final output of the tree computation.
  Logic get out => output('out');

  /// The combinational depth since the last flop. The total compute depth of
  /// the tree is: depth + flopDepth * depthToflop;
  int get depth => _computed.depth;

  /// The flop depth of the tree from the output to the leaves.
  int get latency => _computed.flopDepth;

  /// Operation to be performed at each node. Note that [_operation] can widen
  /// the output. The logic function must support the operation for 2 and up to
  /// [radix] inputs.
  final Logic Function(List<Logic> inputs, {String name}) _operation;

  /// Specified width of input to each reduction node (e.g., binary: radix=2)
  late final int radix;

  /// When [signExtend] is true, use sign-extension on values,
  /// otherwise use zero-extension.
  late final bool signExtend;

  /// Specified depth of nodes at which to flop (requires [_clk]).
  late final int? depthToFlop;

  /// Optional [_clk] input to create pipeline.
  late final Logic? _clk;

  /// Optional [_reset] input to reset pipeline.
  late final Logic? _reset;

  /// Optional [_enable] input to enable pipeline.
  late final Logic? _enable;

  /// The input sequence
  late final List<Logic> _sequence;

  /// Capture the record of compute: the final value, its depth (from last
  /// flop or input), and its flopDepth if pipelined.
  late final ({Logic value, int depth, int flopDepth}) _computed;

  /// Local conditional flop using module reset/enable
  Logic _localFlop(Logic d, {bool doFlop = false}) =>
      condFlop(doFlop ? _clk : null, reset: _reset, en: _enable, d);

  /// Generate a tree based on dividing the input [sequence] of a node into
  /// segments, recursively constructing [radix] child nodes to operate
  /// on each segment.
  /// - [sequence] is the input sequence to be reduced using the tree of
  /// operations.
  /// - Logic Function(List<Logic> inputs, {String name}) [_operation]
  /// is the operation to be performed at each node. Note that [_operation]
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
  ReductionTree(List<Logic> sequence, this._operation,
      {this.radix = 2,
      this.signExtend = false,
      this.depthToFlop,
      Logic? clk,
      Logic? enable,
      Logic? reset,
      super.name = 'reduction_tree'})
      : super(
            definitionName: 'ReductionTreeNode_R${radix}_L${sequence.length}') {
    if (sequence.isEmpty) {
      throw RohdHclException("Don't use ReductionTree "
          'with an empty sequence');
    }
    _sequence = [
      for (var i = 0; i < sequence.length; i++)
        addInput('seq$i', sequence[i], width: sequence[i].width)
    ];
    _clk = (clk != null) ? addInput('clk', clk) : null;
    _enable = (enable != null) ? addInput('enable', enable) : null;
    _reset = (reset != null) ? addInput('reset', reset) : null;

    _buildLogic();
  }

  /// Compute the next splitting point taking into account trying to get
  /// nice powers of the radix as a potential split.
  static int _nextSplitDistance(
      int seqRemaining, int radix, int branchesRemaining) {
    if (branchesRemaining == 1) {
      return seqRemaining;
    }
    final power = (log(seqRemaining) / log(radix)).toInt();

    final chunk = pow(radix, power).toInt();

    if (seqRemaining - chunk - (branchesRemaining - 1) >= 0) {
      return pow(radix, power).toInt();
    }
    return pow(radix, max(power - 1, 0)).toInt();
  }

  /// Build out the recursive tree
  void _buildLogic() {
    if (_sequence.length <= radix) {
      final value = _operation(_sequence);
      addOutput('out', width: value.width) <= value;
      _computed = (value: output('out'), depth: 0, flopDepth: 0);
    } else {
      final results = <({Logic value, int depth, int flopDepth})>[];
      var pos = 0;
      for (var i = 0; i < radix; i++) {
        final end1 =
            _nextSplitDistance(_sequence.length - pos, radix, radix - i) + pos;
        final tree = ReductionTree(
            _sequence.getRange(pos, end1).toList(), _operation,
            radix: radix,
            signExtend: signExtend,
            depthToFlop: depthToFlop,
            clk: _clk,
            enable: _enable,
            reset: _reset);
        results.add(tree._computed);
        pos = end1;
      }
      final flopDepth = results.map((c) => c.flopDepth).reduce(max);
      final treeDepth = results.map((c) => c.depth).reduce(max);

      final alignedResults = results
          .map((c) => _localFlop(c.value, doFlop: c.flopDepth < flopDepth));

      final depthFlop = (depthToFlop != null) &&
          (treeDepth > 0) & (treeDepth % depthToFlop! == 0);
      final resultsFlop =
          alignedResults.map((r) => _localFlop(r, doFlop: depthFlop));

      final alignWidth = results.map((c) => c.value.width).reduce(max);
      final resultsExtend = resultsFlop.map((r) =>
          signExtend ? r.signExtend(alignWidth) : r.zeroExtend(alignWidth));

      final value = _operation(resultsExtend.toList(),
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
