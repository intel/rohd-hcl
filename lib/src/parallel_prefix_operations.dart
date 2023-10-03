// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// parallel-prefix_operations.dart
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

/// ParallePrefix is the core parallel prefix tree structure
class ParallelPrefix extends Module {
  final List<Logic> _oseq = [];

  /// Output sequence value
  List<Logic> get val => _oseq;

  /// ParallePrefix recursion
  ParallelPrefix(List<Logic> inps, String name) : super(name: name) {
    if (inps.isEmpty) {
      throw Exception("Don't use {name} with an empty sequence");
    }
  }
}

/// Ripple shaped pp tree
class Ripple extends ParallelPrefix {
  /// Ripple constructor
  Ripple(List<Logic> inps, Logic Function(Logic, Logic) op)
      : super(inps, 'ripple') {
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

/// Sklansky shaped pp tree
class Sklansky extends ParallelPrefix {
  /// Sklansky constructor
  Sklansky(List<Logic> inps, Logic Function(Logic, Logic) op)
      : super(inps, 'sklansky') {
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

/// KoggeStone shaped pp tree
class KoggeStone extends ParallelPrefix {
  /// KoggeStone constructor
  KoggeStone(List<Logic> inps, Logic Function(Logic, Logic) op)
      : super(inps, 'kogge_stone') {
    final iseq = <Logic>[];

    inps.forEachIndexed((i, el) {
      iseq.add(addInput('i$i', el, width: el.width));
      _oseq.add(addOutput('o$i', width: el.width));
    });

    var skip = 1;

    while (skip < inps.length) {
      for (var i = inps.length - 1; i >= skip; --i) {
        iseq[i] = op(iseq[i - skip], iseq[i]);
      }
      skip *= 2;
    }

    iseq.forEachIndexed((i, el) {
      _oseq[i] <= el;
    });
  }
}

/// BrentKung shaped pp tree
class BrentKung extends ParallelPrefix {
  /// BrentKung constructor
  BrentKung(List<Logic> inps, Logic Function(Logic, Logic) op)
      : super(inps, 'brent_kung') {
    final iseq = <Logic>[];

    inps.forEachIndexed((i, el) {
      iseq.add(addInput('i$i', el, width: el.width));
      _oseq.add(addOutput('o$i', width: el.width));
    });

    // Reduce phase
    var skip = 2;
    while (skip <= inps.length) {
      for (var i = skip - 1; i < inps.length; i += skip) {
        iseq[i] = op(iseq[i - skip ~/ 2], iseq[i]);
      }
      skip *= 2;
    }

    // Prefix Phase
    skip = largestPow2LessThan(inps.length);
    while (skip > 2) {
      for (var i = 3 * (skip ~/ 2) - 1; i < inps.length; i += skip) {
        iseq[i] = op(iseq[i - skip ~/ 2], iseq[i]);
      }
      skip ~/= 2;
    }

    // Final row
    for (var i = 2; i < inps.length; i += 2) {
      iseq[i] = op(iseq[i - 1], iseq[i]);
    }

    iseq.forEachIndexed((i, el) {
      _oseq[i] <= el;
    });
  }
}

/// Or scan based on pp tree
class PPOrScan extends Module {
  /// Output sequence value
  Logic get out => output('out');

  /// OrScan constructor
  PPOrScan(
      Logic inp,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))
          ppGen) {
    inp = addInput('inp', inp, width: inp.width);
    final u =
        ppGen(List<Logic>.generate(inp.width, (i) => inp[i]), (a, b) => a | b);
    addOutput('out', width: inp.width) <= u.val.rswizzle();
  }
}

/// Priority Encoder based on pp tree
class PriorityEncoder extends Module {
  /// Output sequence value
  Logic get out => output('out');

  /// PriorityEncoder constructor
  PriorityEncoder(
      Logic inp,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))
          ppGen) {
    inp = addInput('inp', inp, width: inp.width);
    final u = PPOrScan(inp, ppGen);
    addOutput('out', width: inp.width) <= (u.out & ~(u.out << Const(1)));
  }
}

/// Adder based on pp tree
class PPAdder extends Module {
  /// Output sequence value
  Logic get out => output('out');

  /// Adder constructor
  PPAdder(
      Logic a,
      Logic b,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))
          ppGen) {
    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);
    final u = ppGen(
        //                                    generate,    propagate or generate
        List<Logic>.generate(
            a.width, (i) => [a[i] & b[i], a[i] | b[i]].swizzle()),
        (lhs, rhs) => [rhs[1] | rhs[0] & lhs[1], rhs[0] & lhs[0]].swizzle());
    addOutput('out', width: a.width) <=
        List<Logic>.generate(a.width,
                (i) => (i == 0) ? a[i] ^ b[i] : a[i] ^ b[i] ^ u.val[i - 1][1])
            .rswizzle();
  }
}

/// Incrementer based on pp tree
class PPIncr extends Module {
  /// Output sequence value
  Logic get out => output('out');

  /// Increment constructor
  PPIncr(
      Logic inp,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))
          ppGen) {
    inp = addInput('inp', inp, width: inp.width);
    final u = ppGen(List<Logic>.generate(inp.width, (i) => inp[i]),
        (lhs, rhs) => rhs & lhs);
    addOutput('out', width: inp.width) <=
        (List<Logic>.generate(
                inp.width, (i) => ((i == 0) ? ~inp[i] : inp[i] ^ u.val[i - 1]))
            .rswizzle());
  }
}

/// Decrementer based on pp tree
class PPDecr extends Module {
  /// Output sequence value
  Logic get out => output('out');

  /// Decrement constructor
  PPDecr(
      Logic inp,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))
          ppGen) {
    inp = addInput('inp', inp, width: inp.width);
    final u = ppGen(List<Logic>.generate(inp.width, (i) => ~inp[i]),
        (lhs, rhs) => rhs & lhs);
    addOutput('out', width: inp.width) <=
        (List<Logic>.generate(
                inp.width, (i) => ((i == 0) ? ~inp[i] : inp[i] ^ u.val[i - 1]))
            .rswizzle());
  }
}
