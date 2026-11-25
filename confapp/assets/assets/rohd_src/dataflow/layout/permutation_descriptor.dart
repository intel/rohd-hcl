// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// permutation_descriptor.dart
// Immutable one-to-one static permutations.
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// An immutable one-to-one permutation.
///
/// Entry `i` is the source index connected to output index `i`. For example,
/// `[2, 0, 1]` transforms `[a, b, c]` into `[c, a, b]`.
/// {@category Dataflow}
@immutable
class PermutationDescriptor {
  final List<int> _sourceIndices;

  /// Creates and validates a permutation from output-to-source indices.
  PermutationDescriptor(Iterable<int> sourceIndices)
      : _sourceIndices = List<int>.unmodifiable(sourceIndices) {
    if (_sourceIndices.isEmpty) {
      throw RohdHclException('A permutation must contain at least one index.');
    }

    final seen = List<bool>.filled(length, false);
    for (var outputIndex = 0; outputIndex < length; outputIndex++) {
      final sourceIndex = _sourceIndices[outputIndex];
      if (sourceIndex < 0 || sourceIndex >= length) {
        throw RohdHclException(
          'Permutation source index $sourceIndex at output $outputIndex is '
          'outside the range 0 through ${length - 1}.',
        );
      }
      if (seen[sourceIndex]) {
        throw RohdHclException(
            'Permutation source index $sourceIndex appears more than once.');
      }
      seen[sourceIndex] = true;
    }
  }

  /// Creates an identity permutation of [length].
  factory PermutationDescriptor.identity(int length) =>
      PermutationDescriptor(List<int>.generate(length, (index) => index));

  /// Creates a permutation that reverses [length] elements.
  factory PermutationDescriptor.reverse(int length) => PermutationDescriptor(
      List<int>.generate(length, (index) => length - index - 1));

  /// Creates a row-write, column-read block interleaving permutation.
  ///
  /// Input elements are written row-major into [rows] by [columns]. Output
  /// elements are read column-major, so output index `c * rows + r` sources
  /// input index `r * columns + c`.
  factory PermutationDescriptor.blockInterleave(int rows, int columns) {
    if (rows <= 0 || columns <= 0) {
      throw RohdHclException('Block dimensions must be positive.');
    }
    return PermutationDescriptor([
      for (var outputIndex = 0; outputIndex < rows * columns; outputIndex++)
        (outputIndex % rows) * columns + outputIndex ~/ rows,
    ]);
  }

  /// Creates a left rotation of [length] elements by [amount].
  factory PermutationDescriptor.rotateLeft(int length, int amount) {
    if (amount < 0) {
      throw RohdHclException('Permutation rotation amount cannot be negative.');
    }
    if (length <= 0) {
      throw RohdHclException('Permutation rotation length must be positive.');
    }
    final normalizedAmount = amount % length;
    return PermutationDescriptor([
      for (var outputIndex = 0; outputIndex < length; outputIndex++)
        (outputIndex - normalizedAmount + length) % length,
    ]);
  }

  /// Creates a right rotation of [length] elements by [amount].
  factory PermutationDescriptor.rotateRight(int length, int amount) {
    if (amount < 0) {
      throw RohdHclException('Permutation rotation amount cannot be negative.');
    }
    if (length <= 0) {
      throw RohdHclException('Permutation rotation length must be positive.');
    }
    final normalizedAmount = amount % length;
    return PermutationDescriptor([
      for (var outputIndex = 0; outputIndex < length; outputIndex++)
        (outputIndex + normalizedAmount) % length,
    ]);
  }

  /// Number of permuted elements.
  int get length => _sourceIndices.length;

  /// Output-to-source index mapping.
  List<int> get sourceIndices => _sourceIndices;

  /// Whether this mapping leaves every element in place.
  bool get isIdentity {
    for (var index = 0; index < length; index++) {
      if (_sourceIndices[index] != index) {
        return false;
      }
    }
    return true;
  }

  /// Returns the source index connected to [outputIndex].
  int sourceIndex(int outputIndex) => _sourceIndices[outputIndex];

  /// Applies this permutation to [elements].
  List<T> apply<T>(List<T> elements) {
    if (elements.length != length) {
      throw RohdHclException(
          'Permutation length $length cannot reorder ${elements.length} '
          'elements.');
    }
    return List<T>.unmodifiable(
        _sourceIndices.map((sourceIndex) => elements[sourceIndex]));
  }

  /// Applies this permutation to fixed-width elements packed into [value].
  BigInt applyPacked(BigInt value, {int elementWidth = 1}) {
    if (elementWidth <= 0) {
      throw RohdHclException('Permutation element width must be positive.');
    }
    final packedWidth = length * elementWidth;
    if (value.isNegative || value >= (BigInt.one << packedWidth)) {
      throw RohdHclException(
          'Packed permutation value $value does not fit in $packedWidth bits.');
    }

    final mask = (BigInt.one << elementWidth) - BigInt.one;
    var result = BigInt.zero;
    for (var outputIndex = 0; outputIndex < length; outputIndex++) {
      final sourceIndex = _sourceIndices[outputIndex];
      final element = (value >> (sourceIndex * elementWidth)) & mask;
      result |= element << (outputIndex * elementWidth);
    }
    return result;
  }

  /// Returns the permutation that restores this permutation's input order.
  PermutationDescriptor inverse() {
    final inverseSources = List<int>.filled(length, 0);
    for (var outputIndex = 0; outputIndex < length; outputIndex++) {
      inverseSources[_sourceIndices[outputIndex]] = outputIndex;
    }
    return PermutationDescriptor(inverseSources);
  }

  /// Composes this mapping followed by [after].
  ///
  /// The returned descriptor is equivalent to
  /// `after.apply(apply(elements))`.
  PermutationDescriptor compose(PermutationDescriptor after) {
    if (length != after.length) {
      throw RohdHclException(
        'Cannot compose permutations of lengths $length and ${after.length}.',
      );
    }
    return PermutationDescriptor([
      for (final sourceInThisOutput in after._sourceIndices)
        _sourceIndices[sourceInThisOutput],
    ]);
  }

  /// A deterministic signature suitable for generated definition names.
  String get configurationSignature {
    final offsetBasis = BigInt.parse('cbf29ce484222325', radix: 16);
    final prime = BigInt.parse('100000001b3', radix: 16);
    final mask = BigInt.parse('ffffffffffffffff', radix: 16);
    var hash = offsetBasis;
    for (final sourceIndex in _sourceIndices) {
      var remaining = BigInt.from(sourceIndex);
      do {
        hash ^= remaining & BigInt.from(0xff);
        hash = (hash * prime) & mask;
        remaining >>= 8;
      } while (remaining != BigInt.zero);
      hash ^= BigInt.from(0xff);
      hash = (hash * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermutationDescriptor &&
          length == other.length &&
          _listsEqual(_sourceIndices, other._sourceIndices);

  @override
  int get hashCode => Object.hashAll(_sourceIndices);

  static bool _listsEqual(List<int> left, List<int> right) {
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }
}
