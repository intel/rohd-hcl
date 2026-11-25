// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_point_array.dart
// Elementwise fixed-point signal collections.
//
// 2026 November 3
// Authors:
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd_hcl/rohd_hcl.dart';

/// A fixed-size collection of [FixedPoint] signals.
///
/// Arithmetic is applied elementwise and follows the same promotion rules as
/// scalar [FixedPoint] operations. This collection intentionally uses a Dart
/// list of independent signals; use a ROHD `LogicArray` when hardware-indexed
/// packed or unpacked storage is required.
class FixedPointArray extends IterableBase<FixedPoint> {
  final List<FixedPoint> _elements;

  /// Creates a fixed-point collection from [elements].
  FixedPointArray(Iterable<FixedPoint> elements)
      : _elements = List<FixedPoint>.unmodifiable(elements);

  /// Creates [length] fixed-point signals using [generator].
  factory FixedPointArray.generate(
    int length,
    FixedPoint Function(int index) generator,
  ) =>
      FixedPointArray(List.generate(length, generator, growable: false));

  @override
  Iterator<FixedPoint> get iterator => _elements.iterator;

  /// The number of elements in this collection.
  @override
  int get length => _elements.length;

  /// Returns the element at [index].
  FixedPoint operator [](int index) => _elements[index];

  /// Adds [other] to this collection elementwise.
  FixedPointArray operator +(FixedPointArray other) =>
      _combine(other, (left, right) => left + right);

  /// Subtracts [other] from this collection elementwise.
  FixedPointArray operator -(FixedPointArray other) =>
      _combine(other, (left, right) => left - right);

  /// Multiplies [other] with this collection elementwise.
  FixedPointArray multiply(FixedPointArray other) =>
      _combine(other, (left, right) => left.multiply(right));

  FixedPointArray _combine(
    FixedPointArray other,
    FixedPoint Function(FixedPoint left, FixedPoint right) operation,
  ) {
    if (length != other.length) {
      throw ArgumentError.value(
        other,
        'other',
        'FixedPointArray lengths must match.',
      );
    }
    return FixedPointArray.generate(
      length,
      (index) => operation(this[index], other[index]),
    );
  }
}
