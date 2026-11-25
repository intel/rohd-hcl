// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// binary_hardware_conversions.dart
// ROHD value and constant conversions for binary mathematics.
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/binary_math/algebra/binary_matrix.dart';
import 'package:rohd_hcl/src/binary_math/algebra/binary_polynomial.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// ROHD conversions for a [BinaryPolynomial].
extension BinaryPolynomialHardwareConversion on BinaryPolynomial {
  /// The minimum packed width, using one bit for the zero polynomial.
  int get packedWidth => max(1, degree + 1);

  /// Returns the packed coefficients as a two-state [LogicValue].
  ///
  /// If provided, [width] may zero-extend the natural [packedWidth], but may
  /// not truncate a non-zero coefficient.
  LogicValue toLogicValue({int? width}) {
    final resultWidth = width ?? packedWidth;
    if (resultWidth < packedWidth) {
      throw RohdHclException(
          'Width $resultWidth cannot contain a binary polynomial requiring '
          '$packedWidth bits.');
    }
    return LogicValue.ofBigInt(coefficients, resultWidth);
  }

  /// Returns the packed coefficients as a binary-preferred [Const].
  Const toConst({int? width}) =>
      Const(toLogicValue(width: width), preferredRadix: 2);
}

/// ROHD conversions for a [BinaryMatrix].
extension BinaryMatrixHardwareConversion on BinaryMatrix {
  /// Returns packed row [index] as a two-state [LogicValue].
  LogicValue rowValue(int index) =>
      LogicValue.ofBigInt(row(index), columnCount);

  /// Returns all packed rows as two-state [LogicValue]s.
  List<LogicValue> get rowValues =>
      List<LogicValue>.unmodifiable(List.generate(rowCount, rowValue));

  /// Returns the packed rows as a one-dimensional [LogicValueArray].
  LogicValueArray get rowValueArray => LogicValueArray.fromFlat(
        [rowCount],
        rowValues,
        elementWidth: columnCount,
      );

  /// Returns packed row [index] as a binary-preferred [Const].
  Const rowConst(int index) => Const(rowValue(index), preferredRadix: 2);

  /// Returns constant packed rows as a one-dimensional [LogicArray].
  ///
  /// Each array leaf is one [columnCount]-bit matrix row. Set
  /// [numUnpackedDimensions] to `1` to emit the row dimension unpacked in
  /// generated SystemVerilog.
  LogicArray toLogicArray({
    String? name,
    int numUnpackedDimensions = 0,
  }) {
    final rows = LogicArray(
      [rowCount],
      columnCount,
      name: name,
      numUnpackedDimensions: numUnpackedDimensions,
    );
    for (var row = 0; row < rowCount; row++) {
      rows.arrayElements[row] <= rowConst(row);
    }
    return rows;
  }
}
