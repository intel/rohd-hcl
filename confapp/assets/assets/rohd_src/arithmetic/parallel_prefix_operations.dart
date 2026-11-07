// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// parallel_prefix_operations.dart
// Implementation of operators using various parallel-prefix trees.
//
// 2023 Sep 29
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>
//   Borrowed from https://github.com/stevenmburns/rohd_sklansky.git

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// This computes the power of 2 less than x
int largestPow2LessThan(int x) => pow(2, log2Ceil(x) - 1).toInt();

/// [ParallelPrefix] is the core parallel prefix tree structure node
/// The output is a [List] of multi-bit [Logic] vectors (typically 2-bit) that
/// represent things like carry-save or generate-propagate signaling in adder
/// networks.  Each node in a parallel prefix tree transforms a row of inputs
/// to an equal length row of outputs of these multi-bit [Logic] values.
class ParallelPrefix extends Module {
  final List<Logic> _oseq = [];

  /// Output sequence value
  List<Logic> get val => UnmodifiableListView(_oseq);

  /// ParallePrefix recursion
  ParallelPrefix(List<Logic> inps, String name,
      {super.reserveName, super.reserveDefinitionName, String? definitionName})
      : super(
            name: name,
            definitionName:
                definitionName ?? 'ParallelPrefix_${name}_W${inps.length}') {
    if (inps.isEmpty) {
      throw Exception("Don't use {name} with an empty sequence");
    }
  }
}

/// A ripple shaped [ParallelPrefix] tree.
class Ripple extends ParallelPrefix {
  /// [Ripple] constructor.
  Ripple(List<Logic> inps, Logic Function(Logic, Logic) op,
      {super.reserveName, super.reserveDefinitionName, String? definitionName})
      : super(definitionName: definitionName ?? 'Ripple', inps, 'ripple') {
    final iseq = <Logic>[];

    inps.forEachIndexed((i, el) {
      iseq.add(addInput('i$i', el, width: el.width));
      _oseq.add(addOutput('o$i', width: el.width));
    });

    for (var i = 0; i < iseq.length; ++i) {
      if (i == 0) {
        _oseq[i] <= iseq[i];
      } else {
        _oseq[i] <= op(_oseq[i - 1], iseq[i]);
      }
    }
  }
}

/// [Sklansky] implements the Sklansky-shaped [ParallelPrefix] tree pattern.
class Sklansky extends ParallelPrefix {
  /// [Sklansky] constructor.
  Sklansky(List<Logic> inps, Logic Function(Logic term1, Logic term2) op,
      {super.reserveName, super.reserveDefinitionName, String? definitionName})
      : super(definitionName: definitionName ?? 'Skanskly', inps, 'sklansky') {
    final iseq = <Logic>[];

    inps.forEachIndexed((i, el) {
      iseq.add(addInput('i$i', el, width: el.width));
      _oseq.add(addOutput('o$i', width: el.width));
    });

    if (iseq.length == 1) {
      _oseq[0] <= iseq[0];
    } else {
      final n = iseq.length;
      final m = largestPow2LessThan(n);
      final u = Sklansky(iseq.getRange(0, m).toList(), op).val;
      final v = Sklansky(iseq.getRange(m, n).toList(), op).val;
      u.forEachIndexed((i, el) {
        _oseq[i] <= el;
      });
      v.forEachIndexed((i, el) {
        _oseq[m + i] <= op(u[m - 1], el);
      });
    }
  }
}

/// [KoggeStone] implements the Kogge-Stone shaped [ParallelPrefix] tree
/// pattern.
class KoggeStone extends ParallelPrefix {
  /// [KoggeStone] constructor.
  KoggeStone(List<Logic> inps, Logic Function(Logic term1, Logic term2) op,
      {super.reserveName, super.reserveDefinitionName, String? definitionName})
      : super(
            definitionName: definitionName ?? 'KoggeStone',
            inps,
            'kogge_stone') {
    final iseq = <Logic>[];

    inps.forEachIndexed((i, el) {
      iseq.add(addInput('i$i', el, width: el.width));
      _oseq.add(addOutput('o$i', width: el.width));
    });

    var skip = 1;

    while (skip < inps.length) {
      for (var i = inps.length - 1; i >= skip; --i) {
        iseq[i] = op(iseq[i - skip], iseq[i])
            .named('ks_skip${skip}_i$i', naming: Naming.mergeable);
      }
      skip *= 2;
    }

    iseq.forEachIndexed((i, el) {
      _oseq[i] <= el.named('o_$i', naming: Naming.mergeable);
    });
  }
}

/// [BrentKung] implements the Brent-Kung shaped [ParallelPrefix] tree pattern.
class BrentKung extends ParallelPrefix {
  /// [BrentKung] constructor.
  BrentKung(List<Logic> inps, Logic Function(Logic term1, Logic term2) op,
      {super.reserveName, super.reserveDefinitionName, String? definitionName})
      : super(
            definitionName: definitionName ?? 'BrentKung', inps, 'brent_kung') {
    final iseq = <Logic>[];

    inps.forEachIndexed((i, el) {
      iseq.add(addInput('i$i', el, width: el.width));
      _oseq.add(addOutput('o$i', width: el.width));
    });

    // Reduce phase
    var skip = 2;
    while (skip <= inps.length) {
      for (var i = skip - 1; i < inps.length; i += skip) {
        iseq[i] = op(iseq[i - skip ~/ 2], iseq[i])
            .named('reduce_$i', naming: Naming.mergeable);
      }
      skip *= 2;
    }

    // Prefix Phase
    skip = largestPow2LessThan(inps.length);
    while (skip > 2) {
      for (var i = 3 * (skip ~/ 2) - 1; i < inps.length; i += skip) {
        iseq[i] = op(iseq[i - skip ~/ 2], iseq[i])
            .named('prefix_$i', naming: Naming.mergeable);
      }
      skip ~/= 2;
    }

    // Final row
    for (var i = 2; i < inps.length; i += 2) {
      iseq[i] =
          op(iseq[i - 1], iseq[i]).named('final_$i', naming: Naming.mergeable);
    }

    iseq.forEachIndexed((i, el) {
      _oseq[i] <= el.named('o_$i', naming: Naming.mergeable);
    });
  }
}

/// Or scan based on [ParallelPrefix] tree.
class ParallelPrefixOrScan extends Module {
  /// Output [out] is the or of bits of the input.
  Logic get out => output('out');

  /// OrScan constructor.
  ParallelPrefixOrScan(Logic inp,
      {ParallelPrefix Function(
              List<Logic> inps, Logic Function(Logic term1, Logic term2) op)
          ppGen = KoggeStone.new,
      super.name = 'parallel_prefix_orscan',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName:
                definitionName ?? 'ParallelPrefixOrScan_W${inp.width}') {
    inp = addInput('inp', inp, width: inp.width);
    final u = ppGen(inp.elements, (a, b) => a | b);
    addOutput('out', width: inp.width) <= u.val.rswizzle();
  }
}

/// Priority Finder based on [ParallelPrefix] tree.
class ParallelPrefixPriorityFinder extends Module {
  /// Output [out] is the one-hot reduction to the first '1' in the [Logic]
  /// input.
  /// Search is from the LSB
  Logic get out => output('out');

  /// Priority Finder constructor.
  ParallelPrefixPriorityFinder(Logic inp,
      {ParallelPrefix Function(
              List<Logic> inps, Logic Function(Logic term1, Logic term2) op)
          ppGen = KoggeStone.new,
      super.name = 'parallel_prefix_finder',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'ParallelPrefixPriorityFinder_W${inp.width}') {
    inp = addInput('inp', inp, width: inp.width);
    final u = ParallelPrefixOrScan(inp, ppGen: ppGen);
    addOutput('out', width: inp.width) <=
        (u.out & ~(u.out << Const(1))).named('pos', naming: Naming.mergeable);
  }
}

/// [Adder] based on [ParallelPrefix] tree.
class ParallelPrefixAdder extends Adder {
  /// Adder constructor
  ParallelPrefixAdder(super.a, super.b,
      {super.carryIn,
      ParallelPrefix Function(
              List<Logic> inps, Logic Function(Logic term1, Logic term2) op)
          ppGen = KoggeStone.new,
      super.name = 'parallel_prefix_adder',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName:
                definitionName ?? 'ParallelPrefixAdder_W${a.width}') {
    final l = List<Logic>.generate(a.width - 1,
        (i) => [a[i + 1] & b[i + 1], a[i + 1] | b[i + 1]].swizzle());
    final cin = carryIn ?? Const(0);
    l.insert(
        0,
        [(a[0] & b[0]) | (a[0] & cin) | (b[0] & cin), a[0] | b[0] | cin]
            .swizzle()
            .named('pg_base', naming: Naming.mergeable));
    final u = ppGen(
        l,
        (lhs, rhs) => [rhs[1] | rhs[0] & lhs[1], rhs[0] & lhs[0]]
            .swizzle()
            .named('pg', naming: Naming.mergeable));
    sum <=
        [
          u.val[a.width - 1][1],
          List<Logic>.generate(
              a.width,
              (i) =>
                  ((i == 0) ? a[i] ^ b[i] ^ cin : a[i] ^ b[i] ^ u.val[i - 1][1])
                      .named('t_$i')).rswizzle()
        ].swizzle();
  }
}

/// Incrementer based on [ParallelPrefix] tree.
class ParallelPrefixIncr extends Module {
  /// Output is '1' added to the [Logic] input.
  Logic get out => output('out');

  /// Increment constructor.
  ParallelPrefixIncr(Logic inp,
      {ParallelPrefix Function(
              List<Logic> inps, Logic Function(Logic term1, Logic term2) op)
          ppGen = KoggeStone.new,
      super.name = 'parallel_prefix_incr',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName:
                definitionName ?? 'ParallelPrefixIncr_W${inp.width}') {
    inp = addInput('inp', inp, width: inp.width);
    final u = ppGen(inp.elements, (lhs, rhs) => rhs & lhs);
    addOutput('out', width: inp.width) <=
        (List<Logic>.generate(
                inp.width,
                (i) =>
                    ((i == 0) ? ~inp[i] : inp[i] ^ u.val[i - 1]).named('o_$i'))
            .rswizzle());
  }
}

/// Decrementer based on [ParallelPrefix] tree.
class ParallelPrefixDecr extends Module {
  /// Output is '1' subtracted from the [Logic] input.
  Logic get out => output('out');

  /// Decrement constructor.
  ParallelPrefixDecr(Logic inp,
      {ParallelPrefix Function(
              List<Logic> inps, Logic Function(Logic term1, Logic term2) op)
          ppGen = KoggeStone.new,
      super.name = 'parallel_prefix_decr',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName:
                definitionName ?? 'ParallelPrefixDecr_W${inp.width}') {
    inp = addInput('inp', inp, width: inp.width);
    final complement = (~inp).named('complement');
    final u = ppGen(complement.elements, (lhs, rhs) => rhs & lhs);
    addOutput('out', width: inp.width) <=
        (List<Logic>.generate(
            inp.width,
            (i) => ((i == 0) ? complement[i] : inp[i] ^ u.val[i - 1])
                .named('o_$i')).rswizzle());
  }
}
