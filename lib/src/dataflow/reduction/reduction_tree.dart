// Copyright (C) 2025-2026 Intel Corporation
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

/// A recursive reduction tree retaining data type [T] and control type [C].
class ReductionTree<T extends Logic, C extends Logic> extends Module {
  /// The final output of the tree computation.
  late final T out;

  /// The control output of the tree computation.
  C? get controlOut => _controlOut;

  /// The depth of the tree from the output to the leaves.
  int get depth => _computed.depth;

  /// The number of flops from the output to the leaves.
  int get latency => _computed.flopDepth;

  /// Operation to be performed at each node. Note that [operation] can widen
  /// the output. The logic function must support singleton branches and up to
  /// [radix] inputs. Structured operations align their own fields and formats;
  /// plain [Logic] operands retain automatic sign/zero extension.
  /// The [depth] input is the depth of the current node in the
  /// tree to the leaves.  For sequences that are not powers of [radix], the
  /// depth is the maximum depth to the leaves from this node in the tree.  The
  /// [depth] can be used to index the [control] [Logic] to change behavior at
  /// each depth of the tree.
  T operation(List<T> inputs, {int depth = 0, C? control, String? name}) =>
      name == null
          ? _operation(inputs, depth: depth, control: control)
          : _operation(inputs, depth: depth, control: control, name: name);

  // Accessed only through the covariantly checked instance method.
  // ignore: unsafe_variance
  final T Function(List<T> inputs, {int depth, C? control, String name})
      _operation;

  /// Specified width of input to each reduction node (e.g., binary: radix=2)
  final int radix;

  /// Configuration for signed extension of values in the tree.
  @protected
  late final StaticOrRuntimeParameter signExtensionParameter;

  /// Specified depth of nodes at which to flop (requires [_clk]).
  final int? depthBetweenFlops;

  /// The combinational depth since the last flop.
  int get _depthFromLastFlop => _computed.depthFromLastFlop;

  /// Optional [_control] input to input to operation.
  late final C? _control;

  /// Optional [_controlOut] output tfor propagating pipelined control.
  late final C? _controlOut;

  /// Optional [_clk] input to create pipeline.
  late final Logic? _clk;

  /// Optional [_reset] input to reset pipeline.
  late final Logic? _reset;

  /// Optional [_enable] input to enable pipeline.
  late final Logic? _enable;

  /// The input sequence
  late final List<T> _sequence;

  /// Capture the record of compute: the final value, its depth (from last
  /// flop or input), and its flopDepth if pipelined.
  late final ({
    T value,
    int depthFromLastFlop,
    int depth,
    int flopDepth,
  }) _computed;

  /// Local conditional flop using module reset/enable
  L _localFlop<L extends Logic>(L d, {bool doFlop = false}) =>
      condFlop(doFlop ? _clk : null, reset: _reset, en: _enable, d);

  /// Generate a tree based on dividing the input [sequence] of a node into
  /// segments, recursively constructing [radix] child nodes to operate on each
  /// segment.
  /// - [sequence] is the input sequence to be reduced using the tree of
  ///   operations.
  /// - [operation] is the operation to be performed at each node. Note that
  ///   [operation] can widen the output. The logic function must support the
  ///   operation for singleton branches and up to [radix] inputs.
  /// - [radix] is the width of reduction at each node in the tree (e.g.,
  ///   binary: radix=2).
  /// - [signExtend] if `true`, use sign-extension to widen [Logic] values as
  ///   needed in the tree, otherwise use zero-extension (default).
  /// - [control] is an optional input that is passed along with the data being
  ///   reduced and passed into the operation.
  ///
  /// Optional parameters to be used for creating a pipelined computation tree:
  /// - [clk], [reset], [enable] are optionally provided to allow for flopping.
  /// - [depthBetweenFlops] specifies how many nodes deep separate flops.
  ReductionTree(
      List<T> sequence,
      T Function(List<T> inputs, {int depth, C? control, String name})
          operation,
      {this.radix = 2,
      dynamic signExtend,
      this.depthBetweenFlops,
      C? control,
      Logic? clk,
      Logic? enable,
      Logic? reset,
      super.name = 'reduction_tree',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : _operation = operation,
        super(
            definitionName: definitionName ??
                'ReductionTreeNode_R${radix}_L${sequence.length}') {
    if (sequence.isEmpty) {
      throw RohdHclException("Don't use ReductionTree "
          'with an empty sequence');
    }
    if (radix < 2) {
      throw RohdHclException('Radix must be at least 2, got $radix');
    }

    signExtensionParameter = StaticOrRuntimeParameter.ofDynamic(signExtend);
    _sequence = [
      for (var i = 0; i < sequence.length; i++)
        addTypedInput('seq$i', sequence[i])
    ];
    _control = (control != null ? addTypedInput('control', control) : null);
    _clk = (clk != null) ? addInput('clk', clk) : null;
    _enable = (enable != null) ? addInput('enable', enable) : null;
    _reset = (reset != null) ? addInput('reset', reset) : null;

    _controlOut = (_control != null
        ? addTypedOutput('controlOut', _control.cloneTyped)
        : null);

    _buildLogic();
  }

  /// Clones a reduction signal, normalizing scalar constants for `Logic`.
  @internal
  static L cloneSignal<L extends Logic>(L source, {String? name}) {
    final cloned = source is Const
        ? Logic(width: source.width, name: name)
        : source.clone(name: name);
    if (cloned is! L) {
      throw RohdHclException(
          'Reduction signals require driveable clones. Use Logic for scalar '
          'constants, not ${source.runtimeType}.');
    }
    return cloned;
  }

  /// Aligns scalar operands without erasing structured formats or enum types.
  ///
  /// Typed operations handle their own field/format alignment and may widen
  /// their outputs. Scalar reductions retain the existing bit-extension policy.
  @internal
  static L alignInput<L extends Logic>(
      L signal, int width, StaticOrRuntimeParameter signExtension,
      {Module? module}) {
    if (signal is LogicStructure || signal is LogicEnum) {
      return signal;
    }
    final extended = signExtension.runtimeConfig == null
        ? signExtension.staticConfig
            ? signal.signExtend(width)
            : signal.zeroExtend(width)
        : mux(
            module == null
                ? signExtension.runtimeConfig!
                : signExtension.getLogic(module),
            signal.signExtend(width),
            signal.zeroExtend(width));
    if (extended is! L) {
      throw RohdHclException(
          'Scalar width alignment cannot preserve ${signal.runtimeType}. '
          'Use Logic for bit-oriented reductions.');
    }
    return extended;
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
      if (_controlOut != null) {
        controlOut! <= _control!;
      }
      final value =
          operation(_sequence, depth: 0, control: _control, name: 'leaf');
      out = addTypedOutput(
          'out', ({name = 'out'}) => cloneSignal(value, name: name))
        ..gets(value);
      _computed = (
        value: out,
        depthFromLastFlop: 0,
        depth: 0,
        flopDepth: 0,
      );
    } else {
      final results = <ReductionTree<T, C>>[];
      var pos = 0;
      for (var i = 0; i < radix; i++) {
        final end1 =
            _nextSplitDistance(_sequence.length - pos, radix, radix - i) + pos;
        final tree = ReductionTree<T, C>(
            _sequence.getRange(pos, end1).toList(), operation,
            radix: radix,
            signExtend: signExtensionParameter,
            depthBetweenFlops: depthBetweenFlops,
            clk: _clk,
            enable: _enable,
            control: _control,
            reset: _reset,
            name: 'reduction_$i');
        results.add(tree);
        pos = end1;
      }
      final flopDepth = results.map((c) => c._computed.flopDepth).reduce(max);
      final combDepth = results.map((c) => c._depthFromLastFlop).reduce(max);
      final depth = results.map((c) => c._computed.depth).reduce(max);

      final alignedResults = results.map((c) => _localFlop(c._computed.value,
          doFlop: c._computed.flopDepth < flopDepth));

      final flopHere = (depthBetweenFlops != null) &&
          (combDepth > 0) & (combDepth % depthBetweenFlops! == 0);

      final floppedResults =
          alignedResults.map((r) => _localFlop(r, doFlop: flopHere));

      if (_controlOut != null) {
        controlOut! <= _localFlop(results[0].controlOut!, doFlop: flopHere);
      }

      final alignWidth =
          results.map((c) => c._computed.value.width).reduce(max);

      final resultsExtend = floppedResults.map((r) =>
          alignInput(r, alignWidth, signExtensionParameter, module: this));

      final value = operation(resultsExtend.toList(),
          control: controlOut, depth: depth + 1, name: 'reduce_d$depth');

      out = addTypedOutput(
          'out', ({name = 'out'}) => cloneSignal(value, name: name))
        ..gets(value);
      _computed = (
        value: out,
        depthFromLastFlop: flopHere ? 0 : combDepth + 1,
        depth: depth + 1,
        flopDepth: flopDepth + (flopHere ? 1 : 0),
      );
    }
  }
}
