// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// binary_linear_transform.dart
// Constant matrix-vector transforms over GF(2).
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/binary_math/algebra/binary_matrix.dart';
import 'package:rohd_hcl/src/dataflow/reduction/reduction_tree_generator.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// A constant matrix-vector transform over GF(2).
///
/// Computes `result = matrix * input + affineOffset`, where addition and
/// multiplication are over GF(2). Matrix row `i` produces result bit `i`.
///
/// Selected input bits in each row are combined through a balanced
/// [ReductionTreeGenerator].
/// {@category Binary Math}
class BinaryLinearTransform extends Module {
  /// The constant transform matrix.
  final BinaryMatrix matrix;

  /// The constant value XORed with the matrix product.
  final BigInt affineOffset;

  /// The radix used by each XOR reduction tree.
  final int radix;

  /// The transformed result.
  Logic get result => output('result');

  /// Creates a constant binary linear or affine transform.
  BinaryLinearTransform(
    Logic dataIn, {
    required this.matrix,
    BigInt? affineOffset,
    this.radix = 2,
    super.name = 'binary_linear_transform',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  })  : affineOffset = affineOffset ?? BigInt.zero,
        super(
          definitionName: definitionName ??
              'BinaryLinearTransform_I${matrix.columnCount}_'
                  'O${matrix.rowCount}_R${radix}_'
                  'M${matrix.configurationSignature}_'
                  'A${(affineOffset ?? BigInt.zero).toRadixString(16)}',
        ) {
    if (dataIn.width != matrix.columnCount) {
      throw PortWidthMismatchException(dataIn, matrix.columnCount);
    }
    if (this.affineOffset.isNegative ||
        this.affineOffset >= (BigInt.one << matrix.rowCount)) {
      throw RohdHclException(
          'Affine offset ${this.affineOffset} does not fit in '
          '${matrix.rowCount} output bits.');
    }
    if (radix < 2) {
      throw RohdHclException('Reduction radix must be at least 2.');
    }

    dataIn = addInput('data_in', dataIn, width: dataIn.width);
    final rowResults = [
      for (var rowIndex = 0; rowIndex < matrix.rowCount; rowIndex++)
        _buildRow(dataIn, rowIndex),
    ];
    addOutput('result', width: matrix.rowCount) <= rowResults.rconcat();
  }

  Logic _buildRow(Logic dataIn, int rowIndex) {
    final selected = [
      for (var columnIndex = 0; columnIndex < matrix.columnCount; columnIndex++)
        if (matrix.entry(rowIndex, columnIndex)) dataIn[columnIndex],
    ];
    final offset = ((affineOffset >> rowIndex) & BigInt.one).toInt();

    if (selected.isEmpty) {
      return Const(offset);
    }

    final reduced = selected.length == 1
        ? selected.single
        : ReductionTreeGenerator(
            selected,
            (inputs, {depth = 0, control, name = 'xor'}) =>
                inputs.reduce((left, right) => left ^ right),
            radix: radix,
          ).out;
    return offset == 0 ? reduced : ~reduced;
  }
}
