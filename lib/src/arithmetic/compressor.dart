// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// compressor.dart
// Column compression of partial prodcuts
//
// 2024 June 04
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:io';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/booth.dart';

// TODO(desmonddak): Logic and LogicValue majority() functions

/// Base class for column compressor function
class Compressor extends Module {
  /// Input bits to compress
  @protected
  late final Logic compressBits;

  /// The addition results [sum] including carry bit
  Logic get sum => output('sum');

  /// The carry results [carry].
  Logic get carry => output('carry');

  /// Construct a column compressor
  Compressor(Logic compressBits) {
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
class Compressor2 extends Compressor {
  /// Construct a 2-input compressor (half-adder)
  Compressor2(super.compressBits) {
    sum <= compressBits.xor();
    carry <= compressBits.and();
  }
}

/// 3-input column compressor (full-adder)
class Compressor3 extends Compressor {
  /// Construct a 3-input column compressor (full-adder)
  Compressor3(super.compressBits) {
    sum <= compressBits.xor();
    carry <=
        mux(compressBits[0], compressBits.slice(2, 1).or(),
            compressBits.slice(2, 1).and());
  }
}

// ignore: public_member_api_docs
enum CompressTermType { carry, sum, pp }

/// A compression term
class CompressTerm implements Comparable<CompressTerm> {
  /// The type of term we have
  late final CompressTermType type;

  /// The inputs that drove this Term
  late List<CompressTerm> inputs = <CompressTerm>[];

  /// The row of the terminal
  final int row;

  /// The column of the term
  final int col;

  /// The Logic wire of the term
  final logic = Logic();

  /// Estimated delay of the output of this CompessTerm
  late double delay;

  /// Estimated delay of a Sum term
  static const sumDelay = 1.0;

  /// Estimated delay of a Carry term
  static const carryDelay = 0.75;

  /// CompressTerm constructor
  CompressTerm(this.type, this.row, this.col) {
    delay = 0.0;
  }

  /// Create a sum Term
  factory CompressTerm.sumTerm(List<CompressTerm> args, int row, int col) {
    final term = CompressTerm(CompressTermType.sum, row, col);
    // ignore: cascade_invocations
    term.inputs = args;
    for (final i in term.inputs) {
      if (i.delay + sumDelay > term.delay) {
        term.delay = i.delay + sumDelay;
      }
    }
    return term;
  }

  /// Create a carry Term
  factory CompressTerm.carryTerm(List<CompressTerm> args, int row, int col) {
    final term = CompressTerm(CompressTermType.carry, row, col);
    // ignore: cascade_invocations
    term.inputs = args;
    for (final i in term.inputs) {
      if (i.delay + carryDelay > term.delay) {
        term.delay = i.delay + carryDelay;
      }
    }
    return term;
  }
  @override
  int compareTo(Object other) {
    if (other is! CompressTerm) {
      throw Exception('Input must be of type CompressTerm ');
    }
    return delay > other.delay ? 1 : (delay < other.delay ? -1 : 0);
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
        final term = CompressTerm(CompressTermType.pp, row, trueColumn);
        term.logic <= pp.partialProducts[row][col];
        columns[trueColumn].add(term);
      }
    }
  }

// TODO(desmonddak): This cannot run without real logic values due to toInt()
//  which forces the user to assign values to the inputs first
//  We need a way to build the CompressionTerm without actual values
//    e.g., there needs to be a way to do the reductions with 'X' values
  /// Evaluate the logic value of a given CompressTerm
  LogicValue evaluateTerm(CompressTerm term) {
    switch (term.type) {
      case CompressTermType.pp:
        return term.logic.value;
      case CompressTermType.sum:
        // xor the eval of the terms
        final termValues = [for (term in term.inputs) evaluateTerm(term)];
        final sum = termValues.swizzle().xor();
        return sum;
      case CompressTermType.carry:
        final termValues = [for (term in term.inputs) evaluateTerm(term)];
        final termValuesInt = [
          for (var i = 0; i < termValues.length; i++) termValues[i].toInt()
        ];

        final count = (termValuesInt.isNotEmpty)
            ? termValuesInt.reduce((c, term) => c + term)
            : 0;
        final majority =
            (count > termValues.length ~/ 2 ? LogicValue.one : LogicValue.zero);
        // Alternative method:
        // final x = Logic(width: termValues.length);
        // x.put(termValues.swizzle());
        // final newCount = Count(x).index.value.toInt();
        // stdout.write('count=$count newCount=$newCount\n');
        // assert(newCount == count, 'count=$count newCount=$newCount\n');
        return majority;
    }
  }

  /// Return the longest column length
  int longestColumn() =>
      columns.reduce((a, b) => a.length > b.length ? a : b).length;

  @override
  String toString() {
    final ts = StringBuffer();
    for (var row = 0; row < longestColumn(); row++) {
      for (var col = columns.length - 1; col >= 0; col--) {
        final colList = columns[col].toList();
        if (row < colList.length) {
          ts.write('\t${colList[row]}');
        } else {
          ts.write('\t');
        }
      }
      ts.write('\n');
    }
    return ts.toString();
  }

  /// Evaluate the (un)compressed partial product array
  ///    logic=true will read the logic gate outputs at each level
  ///    print=true will print out the array
  BigInt evaluate({bool print = false, bool logic = false}) {
    final ts = StringBuffer();
    final rows = longestColumn();
    final width = pp.maxWidth();

    var accum = BigInt.zero;
    for (var row = 0; row < rows; row++) {
      final rowBits = <LogicValue>[];
      for (var col = columns.length - 1; col >= 0; col--) {
        final colList = columns[col].toList();
        if (row < colList.length) {
          final value =
              logic ? colList[row].logic.value : evaluateTerm(colList[row]);
          rowBits.add(value);
          if (print) {
            ts.write('\t${bitString(value)}');
          }
        } else if (print) {
          ts.write('\t');
        }
      }
      rowBits.addAll(List.filled(pp.rowShift[row], LogicValue.zero));
      final val = rowBits.swizzle().zeroExtend(width).toBigInt();
      accum += val;
      if (print) {
        ts.write('\t${bitString(rowBits.swizzle().zeroExtend(width))} ($val)');
        if (row == rows - 1) {
          ts.write(' Total=${accum.toSigned(width)}\n');
          stdout.write(ts);
        } else {
          ts.write('\n');
        }
      }
    }
    return accum.toSigned(width);
  }

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
          Compressor compressor;
          if (depth > 3) {
            inputs.add(queue.removeFirst());
            compressor =
                Compressor3([for (final i in inputs) i.logic].swizzle());
          } else {
            compressor =
                Compressor2([for (final i in inputs) i.logic].swizzle());
          }
          final t = CompressTerm.sumTerm(inputs, 0, col);
          t.logic <= compressor.sum;
          // assert(t.logic.value == evaluateTerm(t),
          //     'sum logic does not match evaluate');
          terms.add(t);
          columns[col].add(t);
          if (col < columns.length - 1) {
            final t = CompressTerm.carryTerm(inputs, 0, col);
            columns[col + 1].add(t);
            terms.add(t);
            t.logic <= compressor.carry;
            // assert(t.logic.value == evaluateTerm(t),
            //     'carry logic does not match evaluate.');
          }
        }
      }
    }
    return terms;
  }

  /// Compress the partial products array to two addends
  List<CompressTerm> compress() {
    final terms = <CompressTerm>[];
    var iterations = longestColumn();
    while (iterations > 0) {
      terms.addAll(_compressIter(iterations--));
      if (longestColumn() <= 2) {
        break;
      }
    }
    return terms;
  }
}
