// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// binary_affine_transform.dart
// Immutable affine transforms over GF(2).
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd_hcl/src/binary_math/algebra/binary_matrix.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// An immutable affine transform over GF(2).
///
/// The transform computes `matrix * input + offset`, where addition is XOR.
/// Matrix row `i` and offset bit `i` produce output bit `i`.
/// {@category Binary Math}
@immutable
class BinaryAffineTransform {
  /// The linear portion of the transform.
  final BinaryMatrix matrix;

  /// The packed constant XORed with the matrix product.
  final BigInt offset;

  /// Creates a binary affine transform.
  BinaryAffineTransform(this.matrix, {BigInt? offset})
      : offset = offset ?? BigInt.zero {
    if (this.offset.isNegative || this.offset >= (BigInt.one << outputWidth)) {
      throw RohdHclException(
          'Binary affine offset ${this.offset} does not fit in '
          '$outputWidth output bits.');
    }
  }

  /// Creates an identity transform with [width] input and output bits.
  factory BinaryAffineTransform.identity(int width) =>
      BinaryAffineTransform(BinaryMatrix.identity(width));

  /// The number of input bits.
  int get inputWidth => matrix.columnCount;

  /// The number of output bits.
  int get outputWidth => matrix.rowCount;

  /// Applies this transform to packed [input].
  BigInt apply(BigInt input) => matrix.multiplyVector(input) ^ offset;

  /// Composes this transform after [before].
  ///
  /// The returned transform computes `this(before(input))`.
  BinaryAffineTransform compose(BinaryAffineTransform before) {
    if (before.outputWidth != inputWidth) {
      throw RohdHclException(
          'Cannot compose a ${before.inputWidth}-to-${before.outputWidth} '
          'binary affine transform before an '
          '$inputWidth-to-$outputWidth transform.');
    }

    return BinaryAffineTransform(
      matrix * before.matrix,
      offset: matrix.multiplyVector(before.offset) ^ offset,
    );
  }

  /// Composes [after] after this transform.
  ///
  /// The returned transform computes `after(this(input))`.
  BinaryAffineTransform then(BinaryAffineTransform after) =>
      after.compose(this);

  /// Concatenates this transform's outputs below [other]'s outputs.
  ///
  /// Both transforms consume the same input. This transform occupies the low
  /// `outputWidth` result bits and [other] occupies the remaining high bits.
  BinaryAffineTransform concatenate(BinaryAffineTransform other) {
    if (inputWidth != other.inputWidth) {
      throw RohdHclException(
          'Cannot concatenate binary affine transforms with input widths '
          '$inputWidth and ${other.inputWidth}.');
    }

    return BinaryAffineTransform(
      BinaryMatrix(
        [...matrix.rows, ...other.matrix.rows],
        columnCount: inputWidth,
      ),
      offset: offset | (other.offset << outputWidth),
    );
  }

  /// Returns this transform applied [exponent] consecutive times.
  ///
  /// This operation requires equal input and output widths. Exponent zero
  /// returns the identity transform.
  BinaryAffineTransform pow(int exponent) {
    if (inputWidth != outputWidth) {
      throw RohdHclException(
          'Only square binary affine transforms can be exponentiated.');
    }
    if (exponent < 0) {
      throw RohdHclException(
          'Binary affine transform exponent must be non-negative.');
    }

    var remaining = exponent;
    var factor = this;
    var result = BinaryAffineTransform.identity(inputWidth);
    while (remaining > 0) {
      if (remaining.isOdd) {
        result = factor.compose(result);
      }
      remaining ~/= 2;
      if (remaining > 0) {
        factor = factor.compose(factor);
      }
    }
    return result;
  }

  /// A deterministic signature suitable for generated definition names.
  String get configurationSignature =>
      '${matrix.configurationSignature}_${offset.toRadixString(16)}';

  @override
  bool operator ==(Object other) =>
      other is BinaryAffineTransform &&
      matrix == other.matrix &&
      offset == other.offset;

  @override
  int get hashCode => Object.hash(matrix, offset);

  @override
  String toString() => 'BinaryAffineTransform($inputWidth -> $outputWidth, '
      'offset: 0x${offset.toRadixString(16)})';
}
