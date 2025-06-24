// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// reduction_tree_generator.dart
// A generator for creating tree reduction computations.
//
// 2025 June 23
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Reduction Tree Generator that produces a recursive tree computation
/// inline so that the [operation] can access global signals.
class ReductionTreeGenerator {
  /// The final output of the tree computation.
  Logic get out => _out;

  late final Logic _out;

  /// The control  output of the tree computation.
  Logic? get controlOut => _controlOut;

  late final Logic? _controlOut;

  /// Optional [control] input to input to operation.
  final Logic? control;

  /// The combinational depth since the last flop.
  int get depth => _computed.depth;

  /// The flop depth of the tree from the output to the leaves.
  int get latency => _computed.flopDepth;

  /// Operation to be performed at each node. Note that [operation] can widen
  /// the output. The logic function must support the operation for 2 and up to
  /// [radix] inputs.
  final Logic Function(List<Logic> inputs,
      {int? fullDepth, Logic? control, String name}) operation;

  /// Specified width of input to each reduction node (e.g., binary: radix=2)
  final int radix;

  /// When [signExtend] is true, use sign-extension on values,
  /// otherwise use zero-extension.
  final bool signExtend;

  /// Specified depth of nodes at which to flop (requires [clk]).
  final int? depthToFlop;

  /// Optional [clk] input to create pipeline.
  final Logic? clk;

  /// Optional [reset] input to reset pipeline.
  final Logic? reset;

  /// Optional [enable] input to enable pipeline.
  final Logic? enable;

  /// The input sequence
  late final List<Logic> sequence;

  /// Capture the record of compute: the final value, its depth (from last
  /// flop or input), and its flopDepth if pipelined.
  late final ({
    Logic value,
    int depth,
    int fullDepth,
    Logic? controlOut,
    int flopDepth,
  }) _computed;

  /// Local conditional flop using module reset/enable
  Logic _localFlop(Logic d, {bool doFlop = false}) =>
      condFlop(doFlop ? clk : null, reset: reset, en: enable, d);

  /// Generate a tree based on dividing the input [sequence] of a node into
  /// segments, recursively constructing [radix] child nodes to operate on each
  /// segment.
  /// - [sequence] is the input sequence to be reduced using the tree of
  ///   operations.
  /// - Logic Function(List<Logic> inputs, {int? fullDepth, String name})
  ///   [operation] is the operation to be performed at each node. Note that
  ///   [operation] can widen the output. The logic function must support the
  ///   operation for (2 to [radix]) inputs.
  /// - [radix] is the width of reduction at each node in the tree (e.g.,
  ///   binary: radix=2).
  /// - [signExtend] if true, use sign-extension to widen Logic values as needed
  ///   in the tree, otherwise use zero-extension (default).
  /// - [control] is an optional input that is passed along with the data being
  ///   reduced and passed into the operation.
  /// Optional parameters to be used for creating a pipelined computation tree:
  /// - [clk], [reset], [enable] are optionally provided to allow for flopping.
  /// - [depthToFlop] specifies how many nodes deep separate flops.
  ReductionTreeGenerator(
    this.sequence,
    this.operation, {
    this.radix = 2,
    this.signExtend = false,
    this.depthToFlop,
    this.control,
    this.clk,
    this.enable,
    this.reset,
  }) {
    if (sequence.isEmpty) {
      throw RohdHclException("Don't use ReductionTreeGenerator "
          'with an empty sequence');
    }
    // _buildLogic();
    _controlOut = control != null ? Logic(width: control!.width) : null;
    _computed = reductionTreeRecurse(sequence);
    _out = Logic(width: _computed.value.width);
    _out <= _computed.value;
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
  ({Logic value, int depth, int fullDepth, int flopDepth, Logic? controlOut})
      reductionTreeRecurse(List<Logic> seq) {
    if (seq.length <= radix) {
      Logic? controlOut;
      if (_controlOut != null) {
        controlOut = Logic(width: _controlOut!.width);
        controlOut <= control!;
      } else {
        controlOut = null;
      }
      final value = operation(seq, fullDepth: 0, control: control);
      return (
        value: value,
        depth: 0,
        fullDepth: 0,
        flopDepth: 0,
        controlOut: controlOut
      );
    } else {
      final results = <({
        Logic value,
        int depth,
        int fullDepth,
        int flopDepth,
        Logic? controlOut
      })>[];
      var pos = 0;
      for (var i = 0; i < radix; i++) {
        final end1 =
            _nextSplitDistance(seq.length - pos, radix, radix - i) + pos;
        final c = reductionTreeRecurse(seq.getRange(pos, end1).toList());

        results.add(c);
        pos = end1;
      }
      final flopDepth = results.map((c) => c.flopDepth).reduce(max);
      final treeDepth = results.map((c) => c.depth).reduce(max);
      final fullDepth = results.map((c) => c.fullDepth).reduce(max);

      final alignedResults = results
          .map((c) => _localFlop(c.value, doFlop: c.flopDepth < flopDepth));

      final depthFlop = (depthToFlop != null) &&
          (treeDepth > 0) & (treeDepth % depthToFlop! == 0);
      final resultsFlop =
          alignedResults.map((r) => _localFlop(r, doFlop: depthFlop));

      Logic? controlOut;
      if (_controlOut != null) {
        controlOut = Logic(width: results[0].controlOut!.width);
        controlOut <= _localFlop(results[0].controlOut!, doFlop: depthFlop);
      } else {
        controlOut = null;
      }

      final alignWidth = results.map((c) => c.value.width).reduce(max);
      final resultsExtend = resultsFlop.map((r) =>
          signExtend ? r.signExtend(alignWidth) : r.zeroExtend(alignWidth));

      final value = operation(resultsExtend.toList(),
          control: controlOut, fullDepth: fullDepth + 1);

      return (
        value: value,
        depth: depthFlop ? 0 : treeDepth + 1,
        fullDepth: fullDepth + 1,
        controlOut: controlOut,
        flopDepth: flopDepth + (depthFlop ? 1 : 0)
      );
    }
  }
}
