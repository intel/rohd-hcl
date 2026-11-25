// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// layout_shape.dart
// Immutable row-major layout geometry.
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// An immutable row-major multidimensional shape.
///
/// Dimension zero is the slowest-varying dimension and the final dimension is
/// the fastest-varying dimension.
/// {@category Dataflow}
@immutable
class LayoutShape {
  final List<int> _dimensions;

  /// Creates a shape from positive [dimensions].
  LayoutShape(Iterable<int> dimensions)
      : _dimensions = List<int>.unmodifiable(dimensions) {
    if (_dimensions.isEmpty) {
      throw RohdHclException(
          'A layout shape must have at least one dimension.');
    }
    if (_dimensions.any((dimension) => dimension <= 0)) {
      throw RohdHclException('Every layout shape dimension must be positive.');
    }
  }

  /// The size of each dimension.
  List<int> get dimensions => _dimensions;

  /// The number of dimensions.
  int get rank => _dimensions.length;

  /// The total number of elements.
  int get elementCount =>
      _dimensions.fold(1, (product, dimension) => product * dimension);

  /// Converts row-major [coordinates] into a linear element index.
  int flatten(Iterable<int> coordinates) {
    final coordinateList = coordinates.toList(growable: false);
    if (coordinateList.length != rank) {
      throw RohdHclException(
        'Expected $rank layout coordinates, got ${coordinateList.length}.',
      );
    }

    var index = 0;
    for (var axis = 0; axis < rank; axis++) {
      final coordinate = coordinateList[axis];
      if (coordinate < 0 || coordinate >= _dimensions[axis]) {
        throw RohdHclException(
          'Coordinate $coordinate is outside dimension $axis with size '
          '${_dimensions[axis]}.',
        );
      }
      index = index * _dimensions[axis] + coordinate;
    }
    return index;
  }

  /// Converts a row-major linear [index] into multidimensional coordinates.
  List<int> unflatten(int index) {
    if (index < 0 || index >= elementCount) {
      throw RohdHclException(
          'Linear index $index is outside a $elementCount-element layout.');
    }

    var remaining = index;
    final coordinates = List<int>.filled(rank, 0);
    for (var axis = rank - 1; axis >= 0; axis--) {
      coordinates[axis] = remaining % _dimensions[axis];
      remaining ~/= _dimensions[axis];
    }
    return List<int>.unmodifiable(coordinates);
  }

  /// A deterministic signature suitable for generated definition names.
  String get configurationSignature => _dimensions.join('x');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayoutShape &&
          rank == other.rank &&
          _listsEqual(_dimensions, other._dimensions);

  @override
  int get hashCode => Object.hashAll(_dimensions);

  static bool _listsEqual(List<int> left, List<int> right) {
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }
}
