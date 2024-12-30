// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// addend_compressor.dart
// Column compression of partial prodcuts
//
// 2024 June 04
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/multiplier_lib.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// Compress terms
enum CompressTermType {
  /// A cout (horizontal carry)
  cout,

  /// A carry term
  carry,

  /// A sum term
  sum,

  /// A partial product term (from the original matrix)
  pp,

  /// a cin (horizontal carry-in) term
  cin
}

/// A compression term
class CompressTerm implements Comparable<CompressTerm> {
  /// The type of term we have
  late final CompressTermType type;

  /// The inputs that drove this Term
  late final List<CompressTerm> inputs;

  /// The carry input that drove this Term
  late final List<CompressTerm>? carryInputs;

  /// The row of the terminal
  final int row;

  /// The column of the term
  final int col;

  /// The Logic wire of the term
  final Logic logic;

  /// Estimated delay of the output of this CompressTerm
  late double delay;

  /// CompressTerm constructor
  CompressTerm(BitCompressor? compressor, this.type, this.logic, this.inputs,
      this.row, this.col,
      {this.carryInputs}) {
    delay = 0.0;
    if (compressor != null) {
      final deltaDelay = compressor.evaluateDelay(type, CompressTermType.pp);
      for (final i in inputs) {
        if (i.delay + deltaDelay > delay) {
          delay = i.delay + deltaDelay;
        }
      }
      if (carryInputs != null) {
        final deltaDelay2 =
            compressor.evaluateDelay(type, CompressTermType.cin);
        for (final c in carryInputs!) {
          if (c.delay + deltaDelay2 > delay) {
            delay = c.delay + deltaDelay2;
          }
        }
      }
    }
  }
  @override
  int compareTo(Object other) {
    if (other is! CompressTerm) {
      throw Exception('Input must be of type CompressTerm ');
    }
    return delay > other.delay ? 1 : (delay < other.delay ? -1 : 0);
  }

  /// Evaluate the logic value of a given CompressTerm.
  LogicValue evaluate() {
    late LogicValue value;
    switch (type) {
      case CompressTermType.pp:
        value = logic.value;
      case CompressTermType.sum:
        // xor the eval of the terms
        final termValues = [for (final term in inputs) term.evaluate()];
        final sum = termValues.swizzle().xor();
        value = sum;
      case CompressTermType.carry:
        final termValues = [for (final term in inputs) term.evaluate()];
        final termValuesInt = [
          for (var i = 0; i < termValues.length; i++) termValues[i].toInt()
        ];

        final count = (termValuesInt.isNotEmpty)
            ? termValuesInt.reduce((c, term) => c + term)
            : 0;
        final majority =
            (count > termValues.length ~/ 2 ? LogicValue.one : LogicValue.zero);
        value = majority;
      case CompressTermType.cout:
        throw RohdHclException('cout CompressTermType should not be evaluated');

      case CompressTermType.cin:
        throw RohdHclException('cin CompressTermType should not be evaluated');
    }
    return value;
  }

  @override
  String toString() {
    final str = StringBuffer();
    final ts = switch (type) {
      CompressTermType.pp => 'pp',
      CompressTermType.carry => 'c',
      CompressTermType.cout => 'o',
      CompressTermType.sum => 's',
      CompressTermType.cin => 'i'
    };
    str
      ..write(ts)
      ..write('$row,$col');
    return str.toString();
  }
}

/// Base class for bit-level column compressor function
abstract class BitCompressor extends Module {
  /// Input bits to compress
  @protected
  late final Logic compressBits;

  /// Input terms to compress
  late final List<CompressTerm> terms;

  /// The addition results [sum] including carry bit
  Logic get sum => output('sum');

  /// The carry results [carry].
  Logic get carry => output('carry');

  late final List<List<double>> _delays;

  /// Construct a column compressor.
  BitCompressor(this.terms, {super.name = 'bitcompressor'}) {
    compressBits = [
      for (var pos = 0; pos < terms.length; pos++)
        addInput('t_$pos', terms[pos].logic)
    ].swizzle();
    addOutput('sum');
    addOutput('carry');
    _delays = List.filled(CompressTermType.values.length,
        List.filled(CompressTermType.values.length, 0));
  }

  /// Evaluate the delay between input and output
  double evaluateDelay(CompressTermType outTerm, CompressTermType inTerm) =>
      _delays[outTerm.index][inTerm.index];
}

/// 2-input column compressor (half-adder)
class Compressor2 extends BitCompressor {
  /// Construct a 2-input compressor (half-adder).
  Compressor2(super.terms, {super.name = 'bitcompressor2'}) {
    sum <= compressBits.xor();
    carry <= compressBits.and();
    _delays[CompressTermType.sum.index][CompressTermType.pp.index] = 1.0;
    _delays[CompressTermType.carry.index][CompressTermType.pp.index] = 1.5;
  }
}

/// 3-input column compressor (full-adder)
class Compressor3 extends BitCompressor {
  /// Construct a 3-input column compressor (full-adder).
  Compressor3(super.terms, {super.name = 'bitcompressor3'}) {
    sum <= compressBits.xor();
    carry <=
        mux(compressBits[0], compressBits.slice(2, 1).or(),
            compressBits.slice(2, 1).and());
    // TODO(desmonddak): wiring different inputs for different delays
    // means we may need to index by input not just type
    _delays[CompressTermType.sum.index][CompressTermType.pp.index] = 1.0;
    _delays[CompressTermType.carry.index][CompressTermType.pp.index] = 1.5;
  }
}

/// 4-input column compressor (4:2 compressor)
class Compressor4 extends BitCompressor {
  /// Horizontal carry-out [cout]
  Logic get cout => output('cout');

  /// Construct a 4-input column compressor using two 3-input compressors.
  Compressor4(List<CompressTerm> terms, List<CompressTerm> cinL,
      {super.name = 'bitcompressor4'})
      : super(terms) {
    // We need to use internal Logic and regenerate Term lists inside
    cinL = [
      for (final cin in cinL)
        CompressTerm(this, cin.type, addInput('cin', cin.logic), cin.inputs,
            cin.row, cin.col)
    ];
    final internalTerms = [
      for (var i = 0; i < compressBits.width; i++)
        CompressTerm(this, terms[i].type, compressBits.reversed[i],
            terms.sublist(0, 4), terms[i].row, terms[i].col)
    ];
    addOutput('cout');
    final c3A = Compressor3(internalTerms.sublist(1, 4));
    cout <= c3A.carry;
    final t = CompressTerm(
        c3A, CompressTermType.sum, c3A.sum, internalTerms.sublist(1, 4), 0, 0);
    final c3B = Compressor3([t, internalTerms[0], cinL[0]]);
    carry <= c3B.carry;
    sum <= c3B.sum;

    // TODO(desmonddak): wiring different inputs for different delays
    _delays[CompressTermType.sum.index][CompressTermType.pp.index] = 4.0;
    _delays[CompressTermType.sum.index][CompressTermType.cin.index] = 2.0;
    _delays[CompressTermType.carry.index][CompressTermType.pp.index] = 3.0;
    _delays[CompressTermType.carry.index][CompressTermType.cin.index] = 2.0;
    _delays[CompressTermType.cout.index][CompressTermType.pp.index] = 3.0;
    _delays[CompressTermType.cout.index][CompressTermType.cin.index] = 0.0;
  }
}

/// A column of partial product terms
typedef ColumnQueue = PriorityQueue<CompressTerm>;

/// A column compressor
class ColumnCompressor {
  /// Columns of partial product CompressTerms
  late final List<ColumnQueue> columns;

  /// Columns of partial product CompressTerms for carries (4:2 output)
  late final List<ColumnQueue> carryColumns;

  /// The partial product array to be compressed
  final PartialProductArray pp;

  /// The clk for the pipelined version of column compression.
  Logic? clk;

  /// Optional reset for configurable pipestage
  Logic? reset;

  /// Optional enable for configurable pipestage.
  Logic? enable;

  /// Use 4:2 compressors in compression tree
  bool use42Compressors;

  /// Initialize a ColumnCompressor for a set of partial products
  ///
  /// If [clk] is not null then a set of flops are used to latch the output
  /// after compression (see [extractRow]).  [reset] and [enable] are optional
  /// inputs to control these flops when [clk] is provided. If [clk] is null,
  /// the [ColumnCompressor] is built as a combinational tree of compressors.
  ///
  /// [use42Compressors] will combine 4:2, 3:2, and 2:2 compressors in building
  /// a compression tree.
  ColumnCompressor(this.pp,
      {this.use42Compressors = false, this.clk, this.reset, this.enable}) {
    columns = List.generate(pp.maxWidth(), (i) => ColumnQueue());
    // if (use42Compressors) {
    carryColumns = List.generate(pp.maxWidth(), (i) => ColumnQueue());
    // }
    for (var row = 0; row < pp.rows; row++) {
      for (var col = 0; col < pp.partialProducts[row].length; col++) {
        final trueColumn = pp.rowShift[row] + col;
        final term = CompressTerm(null, CompressTermType.pp,
            pp.partialProducts[row][col], [], row, trueColumn);
        columns[trueColumn].add(term);
      }
    }
  }

  /// Return the longest column length
  int longestColumn() =>
      columns.reduce((a, b) => a.length > b.length ? a : b).length +
      carryColumns.reduce((a, b) => a.length > b.length ? a : b).length;

  /// Convert a row to a Logic bitvector
  Logic extractRow(int row) {
    final width = pp.maxWidth();

    final rowBits = <Logic>[];
    for (var col = columns.length - 1; col >= 0; col--) {
      final colList = carryColumns[col].toList() + columns[col].toList();
      if (row < colList.length) {
        final value = colList[row].logic;

        rowBits.add(
            clk != null ? flop(clk!, value, reset: reset, en: enable) : value);
      } else {
        rowBits.add(Const(0));
      }
    }
    // rowBits.addAll(List.filled(pp.rowShift[row], Const(0)));
    if (width > rowBits.length) {
      return rowBits.swizzle().zeroExtend(width);
    }
    return rowBits.swizzle().getRange(0, width);
  }

  /// Core iterator for column compressor routine
  List<CompressTerm> _compressIter(int iteration) {
    final terms = <CompressTerm>[];
    for (var col = 0; col < columns.length; col++) {
      final queue = columns[col];
      final PriorityQueue<CompressTerm> carryQueue;
      if (use42Compressors) {
        carryQueue = carryColumns[col];
      } else {
        carryQueue = PriorityQueue<CompressTerm>();
      }
      final depth = queue.length + carryQueue.length;
      if (depth > iteration) {
        if (depth > 2) {
          final first = queue.removeFirst();
          final second = queue.removeFirst();
          final inputs = <CompressTerm>[first, second];
          BitCompressor compressor;
          if (depth > 4 && use42Compressors) {
            final cin = carryQueue.isNotEmpty
                ? carryQueue.removeFirst()
                : CompressTerm(null, CompressTermType.cin, Const(0), [], 0, 0);
            inputs
              ..add(queue.removeFirst())
              ..add(queue.removeFirst());
            compressor = Compressor4(inputs, [cin]);
            if (col < columns.length - 1) {
              final t = CompressTerm(compressor, CompressTermType.carry,
                  (compressor as Compressor4).cout, inputs, 0, col);
              carryColumns[col + 1].add(t);
            }
          } else if (depth > 3) {
            inputs.add(queue.removeFirst());
            compressor = Compressor3(inputs);
          } else {
            compressor = Compressor2(inputs);
          }
          final t = CompressTerm(
              compressor, CompressTermType.sum, compressor.sum, inputs, 0, col);
          terms.add(t);
          columns[col].add(t);
          if (col < columns.length - 1) {
            final t = CompressTerm(compressor, CompressTermType.carry,
                compressor.carry, inputs, 0, col);
            columns[col + 1].add(t);
            terms.add(t);
          }
        }
      }
    }
    return terms;
  }

  /// Compress the partial products array to two addends
  void compress() {
    final terms = <CompressTerm>[];
    var iterations = longestColumn();
    while (iterations > 0) {
      terms.addAll(_compressIter(iterations--));
      if (longestColumn() <= 2) {
        break;
      }
    }
  }
}
