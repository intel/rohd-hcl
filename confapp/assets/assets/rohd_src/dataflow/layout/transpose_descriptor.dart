// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// transpose_descriptor.dart
// Row-major axis transposition.
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd_hcl/src/dataflow/layout/layout_shape.dart';
import 'package:rohd_hcl/src/dataflow/layout/permutation_descriptor.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// Describes a row-major permutation of layout axes.
///
/// Entry `i` of [axisOrder] is the input axis used as output axis `i`.
/// {@category Dataflow}
@immutable
class TransposeDescriptor {
  /// Shape before transposition.
  final LayoutShape inputShape;

  /// Output-axis-to-input-axis mapping.
  final List<int> axisOrder;

  /// Shape after transposition.
  late final LayoutShape outputShape;

  /// Linear output-to-input element mapping.
  late final PermutationDescriptor permutation;

  /// Creates an axis transpose, reversing all axes when [axisOrder] is omitted.
  TransposeDescriptor({
    required this.inputShape,
    Iterable<int>? axisOrder,
  }) : axisOrder = List<int>.unmodifiable(axisOrder ??
            List<int>.generate(
                inputShape.rank, (index) => inputShape.rank - index - 1)) {
    if (this.axisOrder.length != inputShape.rank) {
      throw RohdHclException(
        'Transpose axis order has ${this.axisOrder.length} axes but the input '
        'shape has rank ${inputShape.rank}.',
      );
    }
    PermutationDescriptor(this.axisOrder);

    outputShape = LayoutShape(
        this.axisOrder.map((inputAxis) => inputShape.dimensions[inputAxis]));
    permutation = PermutationDescriptor([
      for (var outputIndex = 0;
          outputIndex < outputShape.elementCount;
          outputIndex++)
        _sourceIndex(outputIndex),
    ]);
  }

  /// Creates a conventional row/column matrix transpose.
  factory TransposeDescriptor.matrix(
          {required int rows, required int columns}) =>
      TransposeDescriptor(
        inputShape: LayoutShape([rows, columns]),
        axisOrder: const [1, 0],
      );

  int _sourceIndex(int outputIndex) {
    final outputCoordinates = outputShape.unflatten(outputIndex);
    final inputCoordinates = List<int>.filled(inputShape.rank, 0);
    for (var outputAxis = 0; outputAxis < outputShape.rank; outputAxis++) {
      inputCoordinates[axisOrder[outputAxis]] = outputCoordinates[outputAxis];
    }
    return inputShape.flatten(inputCoordinates);
  }
}
