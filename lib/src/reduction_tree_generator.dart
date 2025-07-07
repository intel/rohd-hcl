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
  late final Logic out;

  /// The control output of the tree computation.
  late final Logic? controlOut;

  /// Optional [control] input to input to operation.
  final Logic? control;

  /// The depth of the tree from the output to the leaves.
  int get depth => _computed.depth;

  /// The number of flops from the output to the leaves.
  int get latency => _computed.flopDepth;

  /// Operation to be performed at each node. Note that [operation] can widen
  /// the output. The logic function must support the operation for 2 and up to
  /// [radix] inputs. The [depth] input is the depth of the current node in the
  /// tree to the leaves.  For sequences that are not powers of [radix], the
  /// depth is the maximum depth to the leaves from this node in the tree.  The
  /// [depth] can be used to index the [control] [Logic] to change behavior at
  /// each depth of the tree.
  final Logic Function(List<Logic> inputs,
      {int depth, Logic? control, String name}) operation;

  /// Specified width of input to each reduction node (e.g., binary: radix=2)
  final int radix;

  /// When [signExtend] is `true`, use sign-extension on values,
  /// otherwise use zero-extension.
  final bool signExtend;

  /// Specified depth of nodes at which to flop (requires [clk]).
  final int? depthBetweenFlops;

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
    int depthFromLastFlop,
    int depth,
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
  /// - [operation] is the [Function] to be performed at each node. Note that
  ///   [operation] can widen the output. The [Logic] [Function] must support
  ///   the operation for (2 to [radix]) inputs.
  /// - [radix] is the width of reduction at each node in the tree (e.g.,
  ///   binary: radix=2).
  /// - [signExtend] if `true`, use sign-extension to widen [Logic] values as
  ///   needed. in the tree, otherwise use zero-extension (default).
  /// - [control] is an optional [Logic] input that is passed along with the
  ///   data being reduced and passed into the operation. Optional parameters to
  ///   be used for creating a pipelined computation tree:
  /// - [clk], [reset], [enable] are optionally provided to allow for flopping.
  /// - [depthBetweenFlops] specifies how many nodes deep separate flops.
  ReductionTreeGenerator(
    this.sequence,
    this.operation, {
    this.radix = 2,
    this.signExtend = false,
    this.depthBetweenFlops,
    this.control,
    this.clk,
    this.enable,
    this.reset,
  }) {
    if (sequence.isEmpty) {
      throw RohdHclException("Don't use ReductionTreeGenerator "
          'with an empty sequence');
    }
    if (radix < 2) {
      throw RohdHclException('Radix must be at least 2, got $radix');
    }
    controlOut = control != null ? Logic(width: control!.width) : null;
    _computed = _reductionTreeRecurse(sequence);
    out = Logic(width: _computed.value.width);
    out <= _computed.value;
    if (controlOut != null) {
      controlOut! <= _computed.controlOut!;
    }
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
  ({
    Logic value,
    int depthFromLastFlop,
    int depth,
    int flopDepth,
    Logic? controlOut
  }) _reductionTreeRecurse(List<Logic> seq) {
    if (seq.length <= radix) {
      Logic? stageControlOut;
      if (control != null) {
        stageControlOut = Logic(width: controlOut!.width);
        stageControlOut <= control!;
      } else {
        stageControlOut = null;
      }
      final value = operation(seq, depth: 0, control: control);
      return (
        value: value,
        depthFromLastFlop: 0,
        depth: 0,
        flopDepth: 0,
        controlOut: stageControlOut
      );
    } else {
      final results = <({
        Logic value,
        int depthFromLastFlop,
        int depth,
        int flopDepth,
        Logic? controlOut
      })>[];
      var pos = 0;
      for (var i = 0; i < radix; i++) {
        final end1 =
            _nextSplitDistance(seq.length - pos, radix, radix - i) + pos;
        final c = _reductionTreeRecurse(seq.getRange(pos, end1).toList());

        results.add(c);
        pos = end1;
      }
      final flopDepth = results.map((c) => c.flopDepth).reduce(max);
      final combDepth = results.map((c) => c.depthFromLastFlop).reduce(max);
      final depth = results.map((c) => c.depth).reduce(max);

      final alignedResults = results
          .map((c) => _localFlop(c.value, doFlop: c.flopDepth < flopDepth));

      final flopHere = (depthBetweenFlops != null) &&
          (combDepth > 0) & (combDepth % depthBetweenFlops! == 0);
      final floppedResults =
          alignedResults.map((r) => _localFlop(r, doFlop: flopHere));

      Logic? stageControlOut;
      if (control != null) {
        stageControlOut = Logic(width: results[0].controlOut!.width);
        stageControlOut <= _localFlop(results[0].controlOut!, doFlop: flopHere);
      } else {
        stageControlOut = null;
      }

      final alignWidth = results.map((c) => c.value.width).reduce(max);
      final resultsExtend = floppedResults.map((r) =>
          signExtend ? r.signExtend(alignWidth) : r.zeroExtend(alignWidth));

      final value = operation(resultsExtend.toList(),
          control: stageControlOut, depth: depth + 1);

      return (
        value: value,
        depthFromLastFlop: flopHere ? 0 : combDepth + 1,
        depth: depth + 1,
        controlOut: stageControlOut,
        flopDepth: flopDepth + (flopHere ? 1 : 0)
      );
    }
  }
}
