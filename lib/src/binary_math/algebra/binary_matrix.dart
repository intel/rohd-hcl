// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// binary_matrix.dart
// Immutable matrices over GF(2).
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/binary_math/algebra/binary_literal.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// An immutable row-major matrix with elements in GF(2).
///
/// Each entry of [rows] is a packed row mask where bit `i` represents column
/// `i`. This representation is efficient for sparse constant hardware
/// transforms and elaboration-time algebra.
/// {@category Binary Math}
@immutable
class BinaryMatrix {
  final List<BigInt> _rows;

  /// The number of columns.
  final int columnCount;

  /// Creates a matrix from packed [rows].
  BinaryMatrix(Iterable<BigInt> rows, {required this.columnCount})
      : _rows = List<BigInt>.unmodifiable(rows) {
    if (columnCount <= 0) {
      throw RohdHclException('Binary matrix column count must be positive.');
    }
    if (_rows.isEmpty) {
      throw RohdHclException('Binary matrix must have at least one row.');
    }
    final limit = BigInt.one << columnCount;
    for (final row in _rows) {
      if (row.isNegative || row >= limit) {
        throw RohdHclException(
            'Binary matrix row $row does not fit in $columnCount columns.');
      }
    }
  }

  /// Creates a matrix from arbitrary-width binary row [literals].
  ///
  /// All rows must have the same number of digits after removing underscores.
  /// The leftmost digit is the highest-numbered column, and the rightmost digit
  /// is column zero. Leading zeroes therefore contribute to [columnCount].
  factory BinaryMatrix.fromBinaryRows(Iterable<String> literals) {
    final parsedRows = [
      for (final literal in literals) _parseBinaryRow(literal)
    ];
    return BinaryMatrix._fromParsedRows(parsedRows);
  }

  /// Creates a matrix from ROHD width/radix-encoded row [literals].
  ///
  /// Rows may use any radix supported by [LogicValue.ofRadixString], but must
  /// have equal, positive encoded widths and contain no `x` or `z`.
  factory BinaryMatrix.fromRadixRows(Iterable<String> literals) =>
      BinaryMatrix._fromParsedRows([
        for (final literal in literals) parseBinaryMathRadixString(literal),
      ]);

  /// Creates a matrix from equally sized, two-state [rows].
  ///
  /// Each [LogicValue.width] becomes the matrix [columnCount], preserving
  /// leading zeroes. Values containing `x` or `z` are rejected.
  factory BinaryMatrix.fromLogicValueRows(Iterable<LogicValue> rows) =>
      BinaryMatrix._fromParsedRows([
        for (final row in rows) parseBinaryMathLogicValue(row),
      ]);

  /// Creates a matrix from a one-dimensional array of packed row [values].
  ///
  /// The array length becomes [rowCount] and its element width becomes
  /// [columnCount]. Values containing `x` or `z` are rejected.
  factory BinaryMatrix.fromLogicValueArray(LogicValueArray values) {
    if (values.dimensions.length != 1) {
      throw RohdHclException(
          'Binary matrix value arrays must have exactly one dimension.');
    }
    return BinaryMatrix.fromLogicValueRows(values.arrayValues);
  }

  factory BinaryMatrix._fromParsedRows(
      List<({BigInt value, int width})> parsedRows) {
    if (parsedRows.isEmpty) {
      throw RohdHclException('Binary matrix must have at least one row.');
    }
    final columnCount = parsedRows.first.width;
    for (var index = 1; index < parsedRows.length; index++) {
      if (parsedRows[index].width != columnCount) {
        throw RohdHclException(
            'Binary matrix rows must have equal widths: row 0 has '
            '$columnCount columns but row $index has '
            '${parsedRows[index].width}.');
      }
    }

    return BinaryMatrix(
      parsedRows.map((parsed) => parsed.value),
      columnCount: columnCount,
    );
  }

  static ({BigInt value, int width}) _parseBinaryRow(String digits) {
    final compressed = digits.replaceAll('_', '');
    if (compressed.isEmpty) {
      throw RohdHclException('Binary matrix rows must not be empty.');
    }
    return parseBinaryMathRadixString("${compressed.length}'b$digits");
  }

  /// Creates an identity matrix with [size] rows and columns.
  factory BinaryMatrix.identity(int size) {
    if (size <= 0) {
      throw RohdHclException('Binary matrix identity size must be positive.');
    }
    return BinaryMatrix(
      List<BigInt>.generate(size, (index) => BigInt.one << index),
      columnCount: size,
    );
  }

  /// The number of rows.
  int get rowCount => _rows.length;

  /// The packed rows.
  List<BigInt> get rows => _rows;

  /// Returns packed row [index].
  BigInt row(int index) => _rows[index];

  /// Returns the entry at [rowIndex], [columnIndex].
  bool entry(int rowIndex, int columnIndex) =>
      ((_rows[rowIndex] >> columnIndex) & BigInt.one) == BigInt.one;

  /// Adds two equally shaped matrices over GF(2).
  BinaryMatrix operator +(BinaryMatrix other) {
    _requireSameShape(other, 'add');
    return BinaryMatrix(
      List<BigInt>.generate(
          rowCount, (index) => _rows[index] ^ other._rows[index]),
      columnCount: columnCount,
    );
  }

  /// Multiplies this matrix by [right] over GF(2).
  BinaryMatrix operator *(BinaryMatrix right) {
    if (columnCount != right.rowCount) {
      throw RohdHclException('Cannot multiply ${rowCount}x$columnCount and '
          '${right.rowCount}x${right.columnCount} binary matrices.');
    }

    final rightTranspose = right.transpose();
    return BinaryMatrix(
      [
        for (final leftRow in _rows)
          _dotProducts(leftRow, rightTranspose._rows),
      ],
      columnCount: right.columnCount,
    );
  }

  /// Multiplies this matrix by packed [vector] over GF(2).
  ///
  /// Bit `i` of the result corresponds to matrix row `i`.
  BigInt multiplyVector(BigInt vector) {
    if (vector.isNegative || vector >= (BigInt.one << columnCount)) {
      throw RohdHclException(
          'Binary vector $vector does not fit in $columnCount columns.');
    }

    var result = BigInt.zero;
    for (var rowIndex = 0; rowIndex < rowCount; rowIndex++) {
      if (_hasOddParity(_rows[rowIndex] & vector)) {
        result |= BigInt.one << rowIndex;
      }
    }
    return result;
  }

  /// Returns the transpose of this matrix.
  BinaryMatrix transpose() => BinaryMatrix(
        [
          for (var columnIndex = 0; columnIndex < columnCount; columnIndex++)
            _column(columnIndex),
        ],
        columnCount: rowCount,
      );

  /// Returns the rank over GF(2).
  int get rank {
    final working = List<BigInt>.of(_rows);
    var pivotRow = 0;

    for (var column = columnCount - 1;
        column >= 0 && pivotRow < rowCount;
        column--) {
      final pivot = working.indexWhere(
        (row) => ((row >> column) & BigInt.one) == BigInt.one,
        pivotRow,
      );
      if (pivot < 0) {
        continue;
      }

      final temporary = working[pivotRow];
      working[pivotRow] = working[pivot];
      working[pivot] = temporary;

      for (var row = 0; row < rowCount; row++) {
        if (row != pivotRow &&
            ((working[row] >> column) & BigInt.one) == BigInt.one) {
          working[row] ^= working[pivotRow];
        }
      }
      pivotRow++;
    }
    return pivotRow;
  }

  /// A deterministic signature suitable for generated definition names.
  String get configurationSignature {
    final offsetBasis = BigInt.parse('cbf29ce484222325', radix: 16);
    final prime = BigInt.parse('100000001b3', radix: 16);
    final mask = BigInt.parse('ffffffffffffffff', radix: 16);
    var hash = offsetBasis;

    void addByte(int byte) {
      hash ^= BigInt.from(byte);
      hash = (hash * prime) & mask;
    }

    void addInteger(BigInt value) {
      var remaining = value;
      do {
        addByte((remaining & BigInt.from(0xff)).toInt());
        remaining >>= 8;
      } while (remaining != BigInt.zero);
      addByte(0xff);
    }

    addInteger(BigInt.from(rowCount));
    addInteger(BigInt.from(columnCount));
    _rows.forEach(addInteger);
    return hash.toRadixString(16).padLeft(16, '0');
  }

  BigInt _column(int columnIndex) {
    var result = BigInt.zero;
    for (var rowIndex = 0; rowIndex < rowCount; rowIndex++) {
      if (entry(rowIndex, columnIndex)) {
        result |= BigInt.one << rowIndex;
      }
    }
    return result;
  }

  static BigInt _dotProducts(BigInt leftRow, Iterable<BigInt> rightColumns) {
    var result = BigInt.zero;
    var column = 0;
    for (final rightColumn in rightColumns) {
      if (_hasOddParity(leftRow & rightColumn)) {
        result |= BigInt.one << column;
      }
      column++;
    }
    return result;
  }

  static bool _hasOddParity(BigInt value) {
    var remaining = value;
    var parity = false;
    while (remaining != BigInt.zero) {
      parity = !parity;
      remaining &= remaining - BigInt.one;
    }
    return parity;
  }

  void _requireSameShape(BinaryMatrix other, String operation) {
    if (rowCount != other.rowCount || columnCount != other.columnCount) {
      throw RohdHclException('Cannot $operation ${rowCount}x$columnCount and '
          '${other.rowCount}x${other.columnCount} binary matrices.');
    }
  }

  @override
  bool operator ==(Object other) {
    if (other is! BinaryMatrix ||
        columnCount != other.columnCount ||
        rowCount != other.rowCount) {
      return false;
    }
    for (var index = 0; index < rowCount; index++) {
      if (_rows[index] != other._rows[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(columnCount, Object.hashAll(_rows));

  @override
  String toString() => _rows
      .map((row) => row.toRadixString(2).padLeft(columnCount, '0'))
      .join('\n');
}
