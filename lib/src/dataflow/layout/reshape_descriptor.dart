// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// reshape_descriptor.dart
// Row-major shape reinterpretation.
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd_hcl/src/dataflow/layout/layout_shape.dart';
import 'package:rohd_hcl/src/dataflow/layout/permutation_descriptor.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// Describes a row-major reshape that preserves linear element order.
/// {@category Dataflow}
@immutable
class ReshapeDescriptor {
  /// Shape before reshaping.
  final LayoutShape inputShape;

  /// Shape after reshaping.
  final LayoutShape outputShape;

  /// Creates a reshape between equally sized layouts.
  ReshapeDescriptor({
    required this.inputShape,
    required this.outputShape,
  }) {
    if (inputShape.elementCount != outputShape.elementCount) {
      throw RohdHclException(
        'Cannot reshape ${inputShape.elementCount} elements into '
        '${outputShape.elementCount} elements.',
      );
    }
  }

  /// Number of elements before and after reshaping.
  int get elementCount => inputShape.elementCount;

  /// Identity element mapping used by row-major reshape hardware.
  PermutationDescriptor get permutation =>
      PermutationDescriptor.identity(elementCount);

  /// Converts input [coordinates] to output coordinates.
  List<int> inputToOutput(Iterable<int> coordinates) =>
      outputShape.unflatten(inputShape.flatten(coordinates));

  /// Converts output [coordinates] to input coordinates.
  List<int> outputToInput(Iterable<int> coordinates) =>
      inputShape.unflatten(outputShape.flatten(coordinates));
}
