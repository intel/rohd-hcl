// Copyright (C) 2024-2026 Intel Corporation
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
  BitCompressor(Logic compressBits,
      {super.name = 'bit_compressor',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(definitionName: definitionName ?? 'BitCompressor') {
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
  Compressor2(super.compressBits,
      {super.name = 'compressor_2', String? definitionName})
      : super(definitionName: definitionName ?? 'Compressor2') {
    sum <= compressBits.xor();
    carry <= compressBits.and();
  }
}

/// 3-input column compressor (full-adder)
class Compressor3 extends BitCompressor {
  /// Construct a 3-input column compressor (full-adder)
  Compressor3(super.compressBits,
      {super.name = 'compressor_3', String? definitionName})
      : super(definitionName: definitionName ?? 'Compressor3') {
    sum <= compressBits.xor();
    carry <= compressBits.majority();
  }
}

/// 4:2 compressor with a horizontal carry input and output.
///
/// The weighted outputs satisfy
/// `sum(inputs) + carryIn = sum + 2 * (carry + cout)`. [cout] does not
/// depend on `carryIn`.
class Compressor4 extends BitCompressor {
  /// Carry to the next column, independent of the horizontal carry input.
  Logic get cout => output('cout');

  /// Sum of the first three inputs, before the second full-adder stage.
  @internal
  late final Logic intermediateSum;

  /// Constructs a 4:2 compressor from two 3:2 compressors.
  Compressor4(super.compressBits, Logic carryIn,
      {super.name = 'compressor_4', String? definitionName})
      : super(definitionName: definitionName ?? 'Compressor4') {
    if (compressBits.width != 4) {
      throw RohdHclException('Compressor4 requires four input bits.');
    }
    carryIn = addInput('carryIn', carryIn);
    final first = Compressor3(compressBits.slice(2, 0), name: 'first');
    intermediateSum = first.sum;
    final second = Compressor3([first.sum, compressBits[3], carryIn].concat(),
        name: 'second');
    addOutput('cout') <= first.carry;
    sum <= second.sum;
    carry <= second.carry;
  }
}

/// Estimated input-to-output delays for a compressor.
///
/// [sum] and [carry] are indexed by input bit, least-significant bit first.
/// A 4:2 table has five entries: the four `compressBits` bits followed by
/// `carryIn`. Its [cout] has the same order, with null for inputs that cannot
/// affect that output. Values are relative delays in the caller's chosen unit.
class CompressorDelayTable {
  /// Input-to-sum delays.
  final List<double> sum;

  /// Input-to-carry delays.
  final List<double> carry;

  /// Input-to-horizontal-carry delays, or null for a 2:1 or 3:2 compressor.
  final List<double?>? cout;

  /// Creates an immutable, validated delay table.
  CompressorDelayTable({
    required List<double> sum,
    required List<double> carry,
    List<double?>? cout,
  })  : sum = List.unmodifiable(sum),
        carry = List.unmodifiable(carry),
        cout = cout == null ? null : List.unmodifiable(cout) {
    if (![2, 3, 5].contains(sum.length) || carry.length != sum.length) {
      throw ArgumentError('A compressor table must have 2, 3, or 5 inputs '
          'and one sum and carry delay per input.');
    }
    if (sum.length == 5) {
      if (cout == null ||
          cout.length != 5 ||
          cout.take(3).any((delay) => delay == null) ||
          cout[3] != null ||
          cout[4] != null) {
        throw ArgumentError('A 4:2 cout must have delays for bits 0-2 and '
            'no paths from bit 3 or carryIn.');
      }
    } else if (cout != null) {
      throw ArgumentError('Only a 4:2 compressor has a cout output.');
    }
    for (final delay in [...sum, ...carry, ...?cout]) {
      if (delay != null && (!delay.isFinite || delay < 0)) {
        throw ArgumentError.value(
            delay,
            'delay',
            'Must be finite and '
                'nonnegative.');
      }
    }
  }

  /// Derives the 4:2 paths from the two full adders used by [Compressor4].
  factory CompressorDelayTable.fromFullAdderStages(
      CompressorDelayTable first, CompressorDelayTable second) {
    if (first.sum.length != 3 || second.sum.length != 3) {
      throw ArgumentError('Both stages must be 3:2 compressor tables.');
    }
    return CompressorDelayTable(
      sum: [
        for (final delay in first.sum) delay + second.sum[2],
        second.sum[1],
        second.sum[0],
      ],
      carry: [
        for (final delay in first.sum) delay + second.carry[2],
        second.carry[1],
        second.carry[0],
      ],
      cout: [...first.carry, null, null],
    );
  }

  String get _identity => [
        ...sum.map(_delayIdentity),
        ...carry.map(_delayIdentity),
        if (cout != null)
          ...cout!.map((delay) => delay == null ? 'x' : _delayIdentity(delay)),
      ].join('_');

  static String _delayIdentity(double value) => value
      .toString()
      .replaceAll('-', 'm')
      .replaceAll('+', 'p')
      .replaceAll('.', 'd');
}

/// Relative path delays used when constructing a compression tree.
///
/// Unless explicitly supplied, the 4:2 table is derived from two copies of
/// [compressor3]. Tables affect elaboration and ordering, not RTL gate delays.
class CompressionTreeDelayConfig {
  /// Half-adder input-to-output delays.
  final CompressorDelayTable compressor2;

  /// Full-adder input-to-output delays.
  final CompressorDelayTable compressor3;

  /// Four same-column inputs and horizontal carry input to each 4:2 output.
  final CompressorDelayTable compressor4;

  static final _default2 =
      CompressorDelayTable(sum: [1, 1], carry: [0.75, 0.75]);
  static final _default3 =
      CompressorDelayTable(sum: [1, 1, 1], carry: [0.75, 0.75, 0.75]);

  /// The historic 2:1 and 3:2 tree estimates.
  static final standard = CompressionTreeDelayConfig();

  /// The historic estimates used by the opt-in 4:2 tree.
  static final with42 = CompressionTreeDelayConfig(
    compressor3: CompressorDelayTable(sum: [1, 1, 1], carry: [1.5, 1.5, 1.5]),
    compressor4: CompressorDelayTable.fromFullAdderStages(
      CompressorDelayTable(sum: [2, 2, 2], carry: [3, 3, 3]),
      CompressorDelayTable(sum: [2, 2, 2], carry: [2, 2, 1]),
    ),
  );

  /// Creates a configuration, optionally overriding individual tables.
  CompressionTreeDelayConfig({
    CompressorDelayTable? compressor2,
    CompressorDelayTable? compressor3,
    CompressorDelayTable? compressor4,
  })  : compressor2 = compressor2 ?? _default2,
        compressor3 = compressor3 ?? _default3,
        compressor4 = compressor4 ??
            CompressorDelayTable.fromFullAdderStages(
                compressor3 ?? _default3, compressor3 ?? _default3) {
    if (this.compressor2.sum.length != 2 ||
        this.compressor3.sum.length != 3 ||
        this.compressor4.sum.length != 5) {
      throw ArgumentError('Expected 2:1, 3:2, and 4:2 delay tables.');
    }
  }

  /// A deterministic SystemVerilog-safe suffix for generated definitions.
  String get definitionNameSuffix =>
      '_D${compressor2._identity}_${compressor3._identity}_'
      '${compressor4._identity}';
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

  /// The [Logic] wire of the [CompressTerm].
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
    _calculateDelay();
  }

  CompressTerm._withDelays(this.type, this.logic, this.inputs, this.row,
      this.col, List<double> delays,
      {List<CompressTerm>? delayInputs}) {
    _calculateDelay(delays, delayInputs);
  }

  void _calculateDelay(
      [List<double>? inputDelays, List<CompressTerm>? delayInputs]) {
    delay = 0.0;
    final deltaDelay = switch (type) {
      CompressTermType.carry => carryDelay,
      CompressTermType.sum => sumDelay,
      CompressTermType.pp => 0.0
    };
    final pathInputs = delayInputs ?? inputs;
    for (var index = 0; index < pathInputs.length; index++) {
      final pathDelay = inputDelays?[index] ?? deltaDelay;
      if (pathInputs[index].delay + pathDelay > delay) {
        delay = pathInputs[index].delay + pathDelay;
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
        final sum = termValues.concat().xor();
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

  /// Whether to use 4:2 compressors where possible.
  final bool use42Compressors;

  /// Relative input-to-output delays used to order compression terms.
  final CompressionTreeDelayConfig delayConfig;

  /// Whether output rows retain their original column positions.
  @internal
  final bool usesColumnAlignedRows;

  /// Track if the rows have been compressed.
  bool _compressed = false;

  /// Initialize a [ColumnCompressor] for a set of partial products.
  ///
  /// If [clk] is not null then a set of flops are used to latch the output
  /// after compression (see [_extractRow]).  [reset] and [enable] are optional
  /// inputs to control these flops when [clk] is provided. If [clk] is null,
  /// the [ColumnCompressor] is built as a combinational tree of
  /// compressors.
  ///
  /// [use42Compressors] selects an alternative tree using 4:2 compressors
  /// where possible. The default retains the existing tree.
  /// [delayConfig] overrides the estimates used to select and order terms.
  ColumnCompressor(List<Logic> inRows, this._rowShift,
      {Logic? clk,
      Logic? reset,
      Logic? enable,
      this.use42Compressors = false,
      CompressionTreeDelayConfig? delayConfig,
      @visibleForTesting bool dontCompress = false,
      super.name = 'column_compressor',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : delayConfig = delayConfig ??
            (use42Compressors
                ? CompressionTreeDelayConfig.with42
                : CompressionTreeDelayConfig.standard),
        usesColumnAlignedRows = use42Compressors || delayConfig != null,
        super(
            definitionName: definitionName ??
                'ColumnCompressor_L${inRows.length}_W${inRows[0].width}'
                    '${use42Compressors ? '_C42' : ''}'
                    '${delayConfig?.definitionNameSuffix ?? ''}') {
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

  /// Convert a row to a [Logic] bitvector
  Logic _extractRow(int row) {
    final width = maxWidth();

    final rowBits = <Logic>[];
    for (var col = columns.length - 1; col >= 0; col--) {
      final colList = columns[col].toList();
      if (row < colList.length) {
        final value = colList[row].logic;

        rowBits.add(clk != null && !usesColumnAlignedRows
            ? flop(clk!, value, reset: reset, en: enable)
            : value);
      } else if (usesColumnAlignedRows) {
        rowBits.add(Const(0));
      }
    }
    if (usesColumnAlignedRows) {
      final result = rowBits.concat();
      return clk == null
          ? result
          : flop(clk!, result, reset: reset, en: enable);
    }
    rowBits.addAll(List.filled(_rowShift[row], Const(0)));
    if (width > rowBits.length) {
      return rowBits.concat().zeroExtend(width);
    }
    return rowBits.concat().getRange(0, width);
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
          final CompressorDelayTable delays;
          if (depth > 3) {
            inputs.add(queue.removeFirst());
            delays = delayConfig.compressor3;
            compressor = Compressor3([for (final i in inputs) i.logic].concat(),
                name: 'cmp3_iter${iteration}_col$col');
          } else {
            delays = delayConfig.compressor2;
            compressor = Compressor2([for (final i in inputs) i.logic].concat(),
                name: 'cmp2_iter${iteration}_col$col');
          }
          final t = CompressTerm._withDelays(
              CompressTermType.sum,
              compressor.sum.named('cmp_sum_iter${iteration}_c$col',
                  naming: Naming.mergeable),
              inputs,
              0,
              col,
              delays.sum.reversed.toList());
          terms.add(t);
          columns[col].add(t);
          if (col < columns.length - 1) {
            final t = CompressTerm._withDelays(
                CompressTermType.carry,
                compressor.carry.named('cmp_carry_iter${iteration}_c$col',
                    naming: Naming.mergeable),
                inputs,
                0,
                col,
                delays.carry.reversed.toList());
            columns[col + 1].add(t);
            terms.add(t);
          }
        }
      }
    }
    return terms;
  }

  void _compressWith42() {
    // Keep horizontal carries separate so a 4:2 cout never depends on cin.
    final horizontalCarries =
        List.generate(columns.length, (_) => ColumnQueue());
    for (var col = 0; col < columns.length; col++) {
      final queue = columns[col];
      final carries = horizontalCarries[col];
      var index = 0;
      while (queue.length + carries.length > 2) {
        if (queue.length < 4) {
          while (carries.isNotEmpty) {
            queue.add(carries.removeFirst());
          }
        }
        if (queue.length >= 4) {
          final inputs = [for (var i = 0; i < 4; i++) queue.removeFirst()];
          final hasCarryIn = carries.isNotEmpty;
          final cin = !hasCarryIn
              ? CompressTerm(CompressTermType.pp, Const(0), [], 0, col)
              : carries.removeFirst();
          final compressor = Compressor4(
            [for (final term in inputs.reversed) term.logic].concat(),
            cin.logic,
            name: 'cmp4_col${col}_${index++}',
          );
          final delayInputs = [...inputs, if (hasCarryIn) cin];
          final delays = delayConfig.compressor4;
          final partial = CompressTerm._withDelays(
              CompressTermType.sum,
              compressor.intermediateSum,
              inputs.sublist(0, 3),
              0,
              col,
              delayConfig.compressor3.sum);
          final finalInputs = [partial, inputs[3], cin];
          queue.add(CompressTerm._withDelays(CompressTermType.sum,
              compressor.sum, finalInputs, 0, col, delays.sum,
              delayInputs: delayInputs));
          if (col + 1 < columns.length) {
            columns[col + 1].add(CompressTerm._withDelays(
                CompressTermType.carry,
                compressor.carry,
                finalInputs,
                0,
                col,
                delays.carry,
                delayInputs: delayInputs));
            horizontalCarries[col + 1].add(CompressTerm._withDelays(
                CompressTermType.carry,
                compressor.cout,
                inputs.sublist(0, 3),
                0,
                col,
                delays.cout!.take(3).cast<double>().toList()));
          }
        } else {
          final inputs = [for (var i = 0; i < 3; i++) queue.removeFirst()];
          final compressor = Compressor3(
            [for (final term in inputs) term.logic].concat(),
            name: 'cmp3_col${col}_${index++}',
          );
          queue.add(CompressTerm._withDelays(
              CompressTermType.sum,
              compressor.sum,
              inputs,
              0,
              col,
              delayConfig.compressor3.sum.reversed.toList()));
          if (col + 1 < columns.length) {
            columns[col + 1].add(CompressTerm._withDelays(
                CompressTermType.carry,
                compressor.carry,
                inputs,
                0,
                col,
                delayConfig.compressor3.carry.reversed.toList()));
          }
        }
      }
      while (carries.isNotEmpty) {
        queue.add(carries.removeFirst());
      }
    }
  }

  /// Compress the partial products array to two addends
  @visibleForTesting
  void compress() {
    if (!_compressed) {
      if (use42Compressors) {
        _compressWith42();
      } else {
        final terms = <CompressTerm>[];
        var iterations = longestColumn();
        while (iterations > 0) {
          terms.addAll(_compressIter(iterations--));
          if (longestColumn() <= 2) {
            break;
          }
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
