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

/// Base class for bit-level column compressor function
abstract class BitCompressor extends Module {
  /// Input bits to compress
  @protected
  late final Logic compressBits;

  /// The addition results [sum] including carry bit
  Logic get sum => output('sum');

  /// The carry results [carry].
  Logic get carry => output('carry');

  /// Construct a column compressor
  BitCompressor(Logic compressBits) {
    this.compressBits = addInput(
      'compressBits',
      compressBits,
      width: compressBits.width,
    );
    addOutput('sum');
    addOutput('carry');
  }
}

/// 2-input column compressor (half-adder)
class Compressor2 extends BitCompressor {
  /// Construct a 2-input compressor (half-adder)
  Compressor2(super.compressBits) {
    sum <= compressBits.xor();
    carry <= compressBits.and();
  }
}

/// 3-input column compressor (full-adder)
class Compressor3 extends BitCompressor {
  /// Construct a 3-input column compressor (full-adder)
  Compressor3(super.compressBits) {
    sum <= compressBits.xor();
    carry <=
        mux(compressBits[0], compressBits.slice(2, 1).or(),
            compressBits.slice(2, 1).and());
  }
}

/// Compress terms
enum CompressTermType {
  /// A carry term
  carry,

  /// A sum term
  sum,

  /// A partial product term (from the original matrix)
  pp
}

/// A compression term
class CompressTerm implements Comparable<CompressTerm> {
  /// The type of term we have
  late final CompressTermType type;

  /// The inputs that drove this Term
  late final List<CompressTerm> inputs;

  /// The row of the terminal
  final int row;

  /// The column of the term
  final int col;

  /// The Logic wire of the term
  final Logic logic;

  /// Estimated delay of the output of this CompessTerm
  late double delay;

  /// Estimated delay of a Sum term
  static const sumDelay = 1.0;

  /// Estimated delay of a Carry term
  static const carryDelay = 0.75;

  /// CompressTerm constructor
  CompressTerm(this.type, this.logic, this.inputs, this.row, this.col) {
    delay = 0.0;
    final deltaDelay = switch (type) {
      CompressTermType.carry => carryDelay,
      CompressTermType.sum => sumDelay,
      CompressTermType.pp => 0.0
    };
    for (final i in inputs) {
      if (i.delay + deltaDelay > delay) {
        delay = i.delay + deltaDelay;
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
    }
    return value;
  }

  @override
  String toString() {
    final str = StringBuffer();
    final ts = switch (type) {
      CompressTermType.pp => 'pp',
      CompressTermType.carry => 'c',
      CompressTermType.sum => 's'
    };
    str
      ..write(ts)
      ..write('$row,$col');
    return str.toString();
  }
}

/// A column of partial product terms
typedef ColumnQueue = PriorityQueue<CompressTerm>;

/// A column compressor
class ColumnCompressor {
  /// Columns of partial product CompressTerms

  late final List<ColumnQueue> columns;

  /// The partial product generator to be compressed
  final PartialProductGenerator pp;

  /// Initialize a ColumnCompressor for a set of partial products
  ColumnCompressor(this.pp) {
    columns = List.generate(pp.maxWidth(), (i) => ColumnQueue());

    for (var row = 0; row < pp.rows; row++) {
      for (var col = 0; col < pp.partialProducts[row].length; col++) {
        final trueColumn = pp.rowShift[row] + col;
        final term = CompressTerm(CompressTermType.pp,
            pp.partialProducts[row][col], [], row, trueColumn);
        columns[trueColumn].add(term);
      }
    }
  }

  /// Return the longest column length
  int longestColumn() =>
      columns.reduce((a, b) => a.length > b.length ? a : b).length;

  /// Convert a row to a Logic bitvector
  Logic extractRow(int row) {
    final width = pp.maxWidth();

    final rowBits = <Logic>[];
    for (var col = columns.length - 1; col >= 0; col--) {
      final colList = columns[col].toList();
      if (row < colList.length) {
        final value = colList[row].logic;
        rowBits.add(value);
      }
    }
    rowBits.addAll(List.filled(pp.rowShift[row], Const(0)));
    return rowBits.swizzle().zeroExtend(width);
  }

  /// Core iterator for column compressor routine
  List<CompressTerm> _compressIter(int iteration) {
    final terms = <CompressTerm>[];
    for (var col = 0; col < columns.length; col++) {
      final queue = columns[col];
      final depth = queue.length;
      if (depth > iteration) {
        if (depth > 2) {
          final first = queue.removeFirst();
          final second = queue.removeFirst();
          final inputs = <CompressTerm>[first, second];
          BitCompressor compressor;
          if (depth > 3) {
            inputs.add(queue.removeFirst());
            compressor =
                Compressor3([for (final i in inputs) i.logic].swizzle());
          } else {
            compressor =
                Compressor2([for (final i in inputs) i.logic].swizzle());
          }
          final t = CompressTerm(
              CompressTermType.sum, compressor.sum, inputs, 0, col);
          terms.add(t);
          columns[col].add(t);
          if (col < columns.length - 1) {
            final t = CompressTerm(
                CompressTermType.carry, compressor.carry, inputs, 0, col);
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
