// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// inference_tensor_tile.dart
// Clone-safe typed tensor tile payloads.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/inference/inference_numeric_format.dart';

/// A two-dimensional typed tensor tile with runtime row and column masks.
///
/// The physical [data] dimensions are static. [rowMask] and [columnMask]
/// describe the active rectangle or edge tile at runtime.
/// {@category Inference}
class InferenceTensorTile<TLogic extends Logic, TValue> extends LogicStructure {
  /// Tensor elements in row-major order.
  final TypedLogicArray<TLogic, TValue> data;

  /// One active bit per physical row.
  final Logic rowMask;

  /// One active bit per physical column.
  final Logic columnMask;

  /// Numeric interpretation of every tensor element.
  final InferenceNumericFormat format;

  /// Number of physical rows.
  final int rowCount;

  /// Number of physical columns.
  final int columnCount;

  /// Creates a typed tensor tile.
  factory InferenceTensorTile({
    required int rowCount,
    required int columnCount,
    required TypedLogicArrayElementBuilder<TLogic> elementBuilder,
    required InferenceNumericFormat format,
    LogicValueCodec<TValue>? valueCodec,
    TypedLogicArrayElementCompatibility<TLogic>? elementCompatibility,
    String name = 'inferenceTensorTile',
    int numUnpackedDimensions = 0,
  }) {
    if (rowCount < 1 || columnCount < 1) {
      throw ArgumentError('Tensor tile dimensions must be positive.');
    }
    final data = TypedLogicArray<TLogic, TValue>(
      [rowCount, columnCount],
      elementBuilder,
      valueCodec: valueCodec,
      elementCompatibility: elementCompatibility,
      name: 'data',
      numUnpackedDimensions: numUnpackedDimensions,
    );
    if (data.elementWidth != format.elementWidth) {
      throw ArgumentError(
        'Tensor element width ${data.elementWidth} does not match numeric '
        'format width ${format.elementWidth}.',
      );
    }
    return InferenceTensorTile<TLogic, TValue>.fromData(
      data: data,
      format: format,
      name: name,
    );
  }

  /// Creates a tensor tile around validated, disconnected [data].
  factory InferenceTensorTile.fromData({
    required TypedLogicArray<TLogic, TValue> data,
    required InferenceNumericFormat format,
    String name = 'inferenceTensorTile',
  }) {
    if (data.dimensions.length != 2 ||
        data.dimensions[0] < 1 ||
        data.dimensions[1] < 1) {
      throw ArgumentError('Tensor tile data must be a non-empty 2-D array.');
    }
    if (data.elementWidth != format.elementWidth) {
      throw ArgumentError(
        'Tensor element width ${data.elementWidth} does not match numeric '
        'format width ${format.elementWidth}.',
      );
    }
    return InferenceTensorTile<TLogic, TValue>._(
      data,
      Logic(name: 'rowMask', width: data.dimensions[0]),
      Logic(name: 'columnMask', width: data.dimensions[1]),
      format,
      name: name,
    );
  }

  InferenceTensorTile._(
    this.data,
    this.rowMask,
    this.columnMask,
    this.format, {
    required String name,
  })  : rowCount = data.dimensions[0],
        columnCount = data.dimensions[1],
        super([data, rowMask, columnMask], name: name);

  /// Returns the active bit for one physical element.
  Logic activeAt(int row, int column) {
    if (row < 0 || row >= rowCount || column < 0 || column >= columnCount) {
      throw RangeError('Tensor coordinate ($row, $column) is out of range.');
    }
    return rowMask[row] & columnMask[column];
  }

  @override
  InferenceTensorTile<TLogic, TValue> clone({String? name}) =>
      InferenceTensorTile<TLogic, TValue>._(
        data.clone(name: 'data'),
        rowMask.clone(name: 'rowMask'),
        columnMask.clone(name: 'columnMask'),
        format,
        name: name ?? this.name,
      );
}

/// Creates an integer or packed-bit tensor tile.
InferenceTensorTile<Logic, LogicValue> inferenceLogicTensorTile({
  required int rowCount,
  required int columnCount,
  required InferenceNumericFormat format,
  String name = 'inferenceLogicTensorTile',
  int numUnpackedDimensions = 0,
}) =>
    InferenceTensorTile<Logic, LogicValue>.fromData(
      data: LogicArray(
        [rowCount, columnCount],
        format.elementWidth,
        name: 'data',
        numUnpackedDimensions: numUnpackedDimensions,
      ),
      format: format,
      name: name,
    );
