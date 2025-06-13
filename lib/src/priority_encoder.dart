// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// priority_encoder.dart
// Priority encoders.
//
// 2025 February 13
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Base class for priority encoders.
abstract class PriorityEncoder extends Module {
  /// The input bitvector
  @protected
  Logic get inp => input('inp');

  /// Output [out] is the bit position of the first '1' in the Logic input.
  /// Search starts from the LSB.
  Logic get out => output('out');

  /// Optional output that says the encoded position is valid.
  Logic? get valid => tryOutput('valid');

  /// Construct a [PriorityEncoder].
  /// - [out] is the number of trailing zeros or the position of first trailing
  /// one.  Will be set to one past the length of the input [inp] if
  /// there are no bits set in [inp].
  /// - Optional [valid] output is set if the output position is valid
  PriorityEncoder(Logic inp,
      {bool generateValid = false,
      super.name = 'priority_encoder',
      String? definitionName})
      : super(
            definitionName: definitionName ?? 'PriorityEncoder_W${inp.width}') {
    inp = addInput('inp', inp, width: inp.width);

    if (generateValid) {
      addOutput('valid');
    }
    addOutput('out', width: log2Ceil(inp.width + 1));
  }
}

/// Priority finder based on or() operations
class RecursivePriorityEncoder extends PriorityEncoder {
  /// [RecursivePriorityEncoder] constructor
  RecursivePriorityEncoder(super.inp,
      {super.generateValid, super.name = 'recursive_priority_encoder'})
      : super(definitionName: 'RecursivePriorityEncoder_W${inp.width}') {
    final lo = recurseFinder(inp.elements);
    valid?.gets(lo.lt(inp.width));
    final sz = output('out').width;
    out <= ((lo.width < sz) ? lo.zeroExtend(sz) : lo.getRange(0, sz));
  }

  /// Recursively find the trailing 1
  Logic recurseFinder(List<Logic> seq, [int depth = 0]) {
    if (seq.length == 1) {
      return ~seq[0];
    } else if (seq.length == 2) {
      final l = seq[0].named('leftLeafLead_d$depth');
      final r = seq[1].named('rightLeafLead_d$depth');
      final ret = Logic(width: 2, name: 'leaf_d$depth');
      Combinational([
        If.block([
          Iff(l, [
            ret < Const(0, width: 2),
          ]),
          ElseIf(r, [
            ret < [Const(0), Const(1)].swizzle(),
          ]),
          Else([
            ret < [Const(1), Const(0)].swizzle(),
          ]),
        ]),
      ]);
      return ret;
    } else {
      final divisor = (log(seq.length - 1) / log(2)).floor();
      final split = pow(2.0, divisor).toInt();

      final left = recurseFinder(seq.getRange(0, split).toList(), depth + 1);
      var right =
          recurseFinder(seq.getRange(split, seq.length).toList(), depth + 1);
      if (right.width < left.width) {
        right = right.zeroExtend(left.width);
      }
      final l = left[-1].named('leftLead_d$depth');
      final r = right[-1].named('rightLead_d$depth');
      final ret = Logic(width: right.width + 1, name: 'merge_d$depth');
      final rhs = ((right.width > 1)
              ? [Const(0), Const(1), right.slice(-2, 0)]
                  .swizzle()
                  .named('zo_right_d$depth')
              : [Const(0), Const(1)].swizzle().named('zo_d$depth'))
          .named('right_d$depth');
      Combinational([
        If.block([
          Iff(l & r, [
            ret <
                [Const(1), Const(0, width: right.width)]
                    .swizzle()
                    .named('lr_d$depth'),
          ]),
          ElseIf(~l, [
            ret < [Const(0), left.slice(-1, 0)].swizzle().named('zl_d$depth'),
          ]),
          Else([
            ret < rhs,
          ]),
        ]),
      ]);
      return ret;
    }
  }
}

/// Recursive Tree Node for Priority Encoding.
class RecursiveModulePriorityEncoderNode extends Module {
  /// Output is the binary encoding of the trailing 1 position
  /// at this node.
  Logic get ret => output('ret');

  /// Construct the Node for a Recursive Priority Tree
  RecursiveModulePriorityEncoderNode(Logic seq,
      {super.name = 'priority_encode_node', int depth = 0})
      : super(definitionName: 'PriorityEncodeNode_W${seq.width}') {
    seq = addInput('seq', seq, width: seq.width);
    if (seq.width == 1) {
      addOutput('ret') <= ~seq[0];
    } else if (seq.width == 2) {
      final l = seq[0].named('leftLeafLead');
      final r = seq[1].named('rightLeafLead');
      addOutput('ret', width: 2);
      Combinational([
        If.block([
          Iff(l, [
            ret < Const(0, width: 2),
          ]),
          ElseIf(r, [
            ret < [Const(0), Const(1)].swizzle(),
          ]),
          Else([
            ret < [Const(1), Const(0)].swizzle(),
          ]),
        ]),
      ]);
    } else {
      final divisor = (log(seq.width - 1) / log(2)).floor();
      final split = pow(2.0, divisor).toInt();

      final left = RecursiveModulePriorityEncoderNode(seq.getRange(0, split),
              name: 'left', depth: depth + 1)
          .ret;
      var right = RecursiveModulePriorityEncoderNode(
              seq.getRange(split, seq.width),
              name: 'right',
              depth: depth + 1)
          .ret;
      if (right.width < left.width) {
        right = right.zeroExtend(left.width);
      }
      final l = left[-1].named('leftLead');
      final r = right[-1].named('rightLead');
      addOutput('ret', width: right.width + 1);
      final rhs = ((right.width > 1)
              ? [Const(0), Const(1), right.slice(-2, 0)]
                  .swizzle()
                  .named('zo_right')
              : [Const(0), Const(1)].swizzle().named('zo'))
          .named('rhs');
      Combinational([
        If.block([
          Iff(l & r, [
            ret <
                [Const(1), Const(0, width: right.width)].swizzle().named('lr'),
          ]),
          ElseIf(~l, [
            ret < [Const(0), left.slice(-1, 0)].swizzle().named('zl'),
          ]),
          Else([
            ret < rhs,
          ]),
        ]),
      ]);
    }
  }
}

/// Priority finder based on or() operations, using a tree of modules.
class RecursiveModulePriorityEncoder extends PriorityEncoder {
  /// [RecursiveModulePriorityEncoder] constructor builds a tree
  /// of [RecursiveModulePriorityEncoderNode]s to compute the position
  /// of the trailing 1 from the LSB of [inp].
  RecursiveModulePriorityEncoder(super.inp,
      {super.generateValid, super.name = 'recursive_module_priority_encoder'})
      : super(definitionName: 'RecursiveModulePriorityEncoder_W${inp.width}') {
    final topNode = RecursiveModulePriorityEncoderNode(inp);
    final lo = topNode.ret;
    if (valid != null) {
      valid! <= topNode.ret.lt(inp.width);
    }
    final sz = output('out').width;
    out <= ((lo.width < sz) ? lo.zeroExtend(sz) : lo.getRange(0, sz));
  }
}

/// Priority Encoder based on ParallelPrefix tree
class ParallelPrefixPriorityEncoder extends PriorityEncoder {
  /// Build a [PriorityEncoder] using a [ParallelPrefix] tree.
  /// - [ppGen] is the type of [ParallelPrefix] tree to use
  ParallelPrefixPriorityEncoder(super.inp,
      {ParallelPrefix Function(
              List<Logic> inps, Logic Function(Logic term1, Logic term2) op)
          ppGen = KoggeStone.new,
      super.generateValid,
      super.name = 'parallel_prefix_encoder'})
      : super(definitionName: 'ParallelPrefixPriorityEncoder_W${inp.width}') {
    final sz = log2Ceil(inp.width + 1);
    final u = ParallelPrefixPriorityFinder(inp, ppGen: ppGen);
    final pos = OneHotToBinary(u.out)
        .binary
        .zeroExtend(sz)
        .named('pos', naming: Naming.mergeable);
    if (valid != null) {
      valid! <= pos.or() | inp[0];
    }
    out <=
        mux(pos.or() | inp[0], pos, Const(inp.width + 1, width: sz))
            .named('encoded_pos', naming: Naming.mergeable);
  }
}
