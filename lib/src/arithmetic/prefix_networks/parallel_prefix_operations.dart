// Copyright (C) 2023-2026 Intel Corporation
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
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';

/// This computes the power of 2 less than x
int largestPow2LessThan(int x) => pow(2, log2Ceil(x) - 1).toInt();

/// Constructs a prefix network retaining payload type [T].
typedef ParallelPrefixGenerator<T extends Logic> = ParallelPrefix<T> Function(
    List<T> inputs, T Function(T left, T right) operation);

/// A parallel prefix network retaining the payload type [T].
///
/// The operation must be associative, but need not be commutative. Output `i`
/// combines inputs `0` through `i` in order. Structured inputs and operation
/// results must retain a matching schema; scalar width behavior is unchanged.
class ParallelPrefix<T extends Logic> extends Module {
  final List<T> _oseq = [];

  /// Output sequence value
  List<T> get val => UnmodifiableListView(_oseq);

  /// Creates a prefix network for [inps].
  ///
  /// Use an explicit `Logic` type argument for scalar constant inputs.
  ParallelPrefix(List<T> inps, String name,
      {super.reserveName, super.reserveDefinitionName, String? definitionName})
      : super(
            name: name,
            definitionName:
                definitionName ?? 'ParallelPrefix_${name}_W${inps.length}') {
    if (inps.isEmpty) {
      throw RohdHclException("Don't use $name with an empty sequence.");
    }
    if (inps.any((s) => s is LogicStructure || s is LogicEnum) &&
        inps.any((s) => !sameDeclaredPayloadShape(inps.first, s))) {
      throw RohdHclException('Prefix payload layouts must match.');
    }
  }

  T _combine(T left, T right, T Function(T left, T right) op, {String? name}) {
    final result = op(left, right);
    if ((left is LogicStructure || left is LogicEnum) &&
        !sameDeclaredPayloadShape(left, result)) {
      throw RohdHclException(
          'Prefix operations must preserve the payload layout.');
    }
    return name == null ? result : _named(result, name);
  }

  T _named(T signal, String name) =>
      ReductionTree.cloneSignal(signal, name: name)..gets(signal);
}

/// A ripple shaped [ParallelPrefix] tree.
class Ripple<T extends Logic> extends ParallelPrefix<T> {
  /// [Ripple] constructor.
  Ripple(List<T> inps, T Function(T left, T right) op,
      {super.reserveName, super.reserveDefinitionName, String? definitionName})
      : super(definitionName: definitionName ?? 'Ripple', inps, 'ripple') {
    final iseq = <T>[];

    inps.forEachIndexed((i, el) {
      final input = addTypedInput('i$i', el);
      iseq.add(input);
      _oseq.add(addTypedOutput('o$i', input.cloneTyped));
    });

    for (var i = 0; i < iseq.length; ++i) {
      if (i == 0) {
        _oseq[i] <= iseq[i];
      } else {
        _oseq[i] <= _combine(_oseq[i - 1], iseq[i], op);
      }
    }
  }
}

/// [Sklansky] implements the Sklansky-shaped [ParallelPrefix] tree pattern.
class Sklansky<T extends Logic> extends ParallelPrefix<T> {
  /// [Sklansky] constructor.
  Sklansky(List<T> inps, T Function(T term1, T term2) op,
      {super.reserveName, super.reserveDefinitionName, String? definitionName})
      : super(definitionName: definitionName ?? 'Skanskly', inps, 'sklansky') {
    final iseq = <T>[];

    inps.forEachIndexed((i, el) {
      final input = addTypedInput('i$i', el);
      iseq.add(input);
      _oseq.add(addTypedOutput('o$i', input.cloneTyped));
    });

    if (iseq.length == 1) {
      _oseq[0] <= iseq[0];
    } else {
      final n = iseq.length;
      final m = largestPow2LessThan(n);
      final u = Sklansky<T>(iseq.getRange(0, m).toList(), op).val;
      final v = Sklansky<T>(iseq.getRange(m, n).toList(), op).val;
      u.forEachIndexed((i, el) {
        _oseq[i] <= el;
      });
      v.forEachIndexed((i, el) {
        _oseq[m + i] <= _combine(u[m - 1], el, op);
      });
    }
  }
}

/// [KoggeStone] implements the Kogge-Stone shaped [ParallelPrefix] tree
/// pattern.
class KoggeStone<T extends Logic> extends ParallelPrefix<T> {
  /// [KoggeStone] constructor.
  KoggeStone(List<T> inps, T Function(T term1, T term2) op,
      {super.reserveName, super.reserveDefinitionName, String? definitionName})
      : super(
            definitionName: definitionName ?? 'KoggeStone',
            inps,
            'kogge_stone') {
    final iseq = <T>[];

    inps.forEachIndexed((i, el) {
      final input = addTypedInput('i$i', el);
      iseq.add(input);
      _oseq.add(addTypedOutput('o$i', input.cloneTyped));
    });

    var skip = 1;

    while (skip < inps.length) {
      for (var i = inps.length - 1; i >= skip; --i) {
        iseq[i] =
            _combine(iseq[i - skip], iseq[i], op, name: 'ks_skip${skip}_i$i');
      }
      skip *= 2;
    }

    iseq.forEachIndexed((i, el) {
      _oseq[i] <= _named(el, 'o_$i');
    });
  }
}

/// [BrentKung] implements the Brent-Kung shaped [ParallelPrefix] tree pattern.
class BrentKung<T extends Logic> extends ParallelPrefix<T> {
  /// [BrentKung] constructor.
  BrentKung(List<T> inps, T Function(T term1, T term2) op,
      {super.reserveName, super.reserveDefinitionName, String? definitionName})
      : super(
            definitionName: definitionName ?? 'BrentKung', inps, 'brent_kung') {
    final iseq = <T>[];

    inps.forEachIndexed((i, el) {
      final input = addTypedInput('i$i', el);
      iseq.add(input);
      _oseq.add(addTypedOutput('o$i', input.cloneTyped));
    });

    // Reduce phase
    var skip = 2;
    while (skip <= inps.length) {
      for (var i = skip - 1; i < inps.length; i += skip) {
        iseq[i] = _combine(iseq[i - skip ~/ 2], iseq[i], op, name: 'reduce_$i');
      }
      skip *= 2;
    }

    // Prefix Phase
    skip = largestPow2LessThan(inps.length);
    while (skip > 2) {
      for (var i = 3 * (skip ~/ 2) - 1; i < inps.length; i += skip) {
        iseq[i] = _combine(iseq[i - skip ~/ 2], iseq[i], op, name: 'prefix_$i');
      }
      skip ~/= 2;
    }

    // Final row
    for (var i = 2; i < inps.length; i += 2) {
      iseq[i] = _combine(iseq[i - 1], iseq[i], op, name: 'final_$i');
    }

    iseq.forEachIndexed((i, el) {
      _oseq[i] <= _named(el, 'o_$i');
    });
  }
}

/// Or scan based on [ParallelPrefix] tree.
class ParallelPrefixOrScan extends Module {
  /// Output [out] is the or of bits of the input.
  Logic get out => output('out');

  /// OrScan constructor.
  ParallelPrefixOrScan(Logic inp,
      {ParallelPrefixGenerator<Logic> ppGen = KoggeStone.new,
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
      {ParallelPrefixGenerator<Logic> ppGen = KoggeStone.new,
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

/// Named carry-generation and carry-propagation signals for prefix addition.
class GeneratePropagate extends LogicStructure {
  /// Whether this group generates a carry.
  Logic get generate => elements[0];

  /// Whether this group propagates an incoming carry.
  Logic get propagate => elements[1];

  /// Creates an unconnected generate/propagate pair.
  GeneratePropagate({String? name})
      : super([Logic(name: 'generate'), Logic(name: 'propagate')],
            name: name ?? 'generate_propagate');

  @override
  GeneratePropagate clone({String? name}) =>
      GeneratePropagate(name: name ?? this.name);
}

/// [Adder] based on a typed [ParallelPrefix] tree.
class ParallelPrefixAdder extends Adder {
  /// Creates a prefix adder whose [ppGen] carries [GeneratePropagate] records.
  ParallelPrefixAdder(super.a, super.b,
      {super.carryIn,
      ParallelPrefixGenerator<GeneratePropagate> ppGen = KoggeStone.new,
      super.name = 'parallel_prefix_adder',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName:
                definitionName ?? 'ParallelPrefixAdder_W${a.width}') {
    final aPin = super.a;
    final bPin = super.b;
    final cin = super.carryIn ?? Const(0);
    final pairs = [
      for (var i = 0; i < aPin.width; i++)
        GeneratePropagate(name: 'pg_$i')
          ..generate.gets(i == 0
              ? (aPin[0] & bPin[0]) | (aPin[0] & cin) | (bPin[0] & cin)
              : aPin[i] & bPin[i])
          ..propagate
              .gets(i == 0 ? aPin[0] | bPin[0] | cin : aPin[i] | bPin[i]),
    ];
    final u = ppGen(
        pairs,
        (lhs, rhs) => GeneratePropagate(name: 'pg')
          ..generate.gets(rhs.generate | (rhs.propagate & lhs.generate))
          ..propagate.gets(rhs.propagate & lhs.propagate));
    sum <=
        [
          u.val[aPin.width - 1].generate,
          List<Logic>.generate(
              aPin.width,
              (i) => ((i == 0)
                      ? aPin[i] ^ bPin[i] ^ cin
                      : aPin[i] ^ bPin[i] ^ u.val[i - 1].generate)
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
      {ParallelPrefixGenerator<Logic> ppGen = KoggeStone.new,
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
      {ParallelPrefixGenerator<Logic> ppGen = KoggeStone.new,
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
