// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// column_compressor.dart
// Column compression of partial prodcuts
//
// 2024 June 04
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

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
  BitCompressor(Logic compressBits, {super.name = 'bit_compressor'}) {
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
  Compressor2(super.compressBits, {super.name = 'compressor_2'}) {
    sum <= compressBits.xor();
    carry <= compressBits.and();
  }
}

/// 3-input column compressor (full-adder)
class Compressor3 extends BitCompressor {
  /// Construct a 3-input column compressor (full-adder)
  Compressor3(super.compressBits, {super.name = 'compressor_3'}) {
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

/// A compression term.
class CompressTerm implements Comparable<CompressTerm> {
  /// The type of term we have.
  late final CompressTermType type;

  /// The inputs that drove this [CompressTerm].
  late final List<CompressTerm> inputs;

  /// The row position.
  final int row;

  /// The column position.
  final int col;

  /// The Logic wire of the [CompressTerm].
  final Logic logic;

  /// Estimated delay of the output.
  late double delay;

  /// Estimated delay of a sum [CompressTerm].
  static const sumDelay = 1.0;

  /// Estimated delay of a carry [CompressTerm].
  static const carryDelay = 0.75;

  /// [CompressTerm] constructor creating a compressor based on the number of
  /// [inputs] and the [CompressTermType] of term.
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

/// A column compressor module
class ColumnCompressor extends Module {
  /// The first of two output rows.
  Logic get add0 => output('add0');

  /// The second of two output rows.
  Logic get add1 => output('add1');

  /// Columns of partial product [CompressTerm]s.
  @internal
  late final List<ColumnQueue> columns;

  /// The clk for the pipelined version of column compression.
  @protected
  Logic? clk;

  /// Optional reset for configurable pipestage
  @protected
  Logic? reset;

  /// Optional enable for configurable pipestage.
  @protected
  Logic? enable;

  late final List<Logic> _rows;

  /// Return the shift of each row
  List<int> get rowShift => _rowShift;

  final List<int> _rowShift;

  /// Track if the rows have been compressed.
  bool _compressed = false;

  /// Initialize a [ColumnCompressor] for a set of partial products.
  ///
  /// If [clk] is not null then a set of flops are used to latch the output
  /// after compression (see [_extractRow]).  [reset] and [enable] are optional
  /// inputs to control these flops when [clk] is provided. If [clk] is null,
  /// the [ColumnCompressor] is built as a combinational tree of
  /// compressors.
  ColumnCompressor(List<Logic> inRows, this._rowShift,
      {Logic? clk,
      Logic? reset,
      Logic? enable,
      @visibleForTesting bool dontCompress = false,
      super.name = 'column_compressor'})
      : super(
            definitionName:
                'ColumnCompressor_L${inRows.length}_W${inRows[0].width}') {
    this.clk = (clk != null) ? addInput('clk', clk) : null;
    this.reset = (reset != null) ? addInput('reset', reset) : null;
    this.enable = (enable != null) ? addInput('enable', enable) : null;
    _rows = [
      for (var row = 0; row < inRows.length; row++)
        addInput('row_$row', inRows[row], width: inRows[row].width)
    ];
    // pp = PartialProductMatrixStore(inputRows, rowShift);
    columns = List.generate(maxWidth(), (i) => ColumnQueue());

    for (var row = 0; row < _rows.length; row++) {
      for (var col = 0; col < _rows[row].width; col++) {
        final trueColumn = _rowShift[row] + col;
        final term = CompressTerm(
            CompressTermType.pp,
            _rows[row][col].named('pp_${row}_$col', naming: Naming.mergeable),
            [],
            row,
            trueColumn);
        columns[trueColumn].add(term);
      }
    }
    addOutput('add0', width: maxWidth());
    addOutput('add1', width: maxWidth());
    if (!dontCompress) {
      compress();
    }
  }

  /// Return the longest column length
  @internal
  int longestColumn() =>
      columns.reduce((a, b) => a.length > b.length ? a : b).length;

  /// Compute the maximum length of the rows
  @internal
  int maxWidth() {
    var maxW = 0;
    for (var row = 0; row < _rows.length; row++) {
      if (_rows[row].width + _rowShift[row] > maxW) {
        maxW = _rows[row].width + _rowShift[row];
      }
    }
    return maxW;
  }

  /// Convert a row to a Logic bitvector
  Logic _extractRow(int row) {
    final width = maxWidth();

    final rowBits = <Logic>[];
    for (var col = columns.length - 1; col >= 0; col--) {
      final colList = columns[col].toList();
      if (row < colList.length) {
        final value = colList[row].logic;

        rowBits.add(
            clk != null ? flop(clk!, value, reset: reset, en: enable) : value);
      }
    }
    rowBits.addAll(List.filled(_rowShift[row], Const(0)));
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
      final depth = queue.length;
      if (depth > iteration) {
        if (depth > 2) {
          final first = queue.removeFirst();
          final second = queue.removeFirst();
          final inputs = <CompressTerm>[first, second];
          BitCompressor compressor;
          if (depth > 3) {
            inputs.add(queue.removeFirst());
            compressor = Compressor3(
                [for (final i in inputs) i.logic].swizzle(),
                name: 'cmp3_iter${iteration}_col$col');
          } else {
            compressor = Compressor2(
                [for (final i in inputs) i.logic].swizzle(),
                name: 'cmp2_iter${iteration}_col$col');
          }
          final t = CompressTerm(
              CompressTermType.sum,
              compressor.sum.named('cmp_sum_iter${iteration}_c$col',
                  naming: Naming.mergeable),
              inputs,
              0,
              col);
          terms.add(t);
          columns[col].add(t);
          if (col < columns.length - 1) {
            final t = CompressTerm(
                CompressTermType.carry,
                compressor.carry.named('cmp_carry_iter${iteration}_c$col',
                    naming: Naming.mergeable),
                inputs,
                0,
                col);
            columns[col + 1].add(t);
            terms.add(t);
          }
        }
      }
    }
    return terms;
  }

  /// Compress the partial products array to two addends
  @visibleForTesting
  void compress() {
    if (!_compressed) {
      final terms = <CompressTerm>[];
      var iterations = longestColumn();
      while (iterations > 0) {
        terms.addAll(_compressIter(iterations--));
        if (longestColumn() <= 2) {
          break;
        }
      }
      add0 <= _extractRow(0);
      add1 <= _extractRow(1);
      _compressed = true;
    } else {
      throw RohdHclException(
          'ColumnCompressor.compress() called multiple times');
    }
  }
}
