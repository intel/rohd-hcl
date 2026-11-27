// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// binary_linear_recurrence_descriptor.dart
// Immutable linear recurrence descriptors over GF(2).
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd_hcl/src/binary_math/algebra/binary_affine_transform.dart';
import 'package:rohd_hcl/src/binary_math/algebra/binary_matrix.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// Describes a linear recurrence over GF(2).
///
/// Each advancement computes:
///
/// ```text
/// nextState = stateMatrix * state + inputMatrix * input + offset
/// ```
///
/// [inputMatrix] may be omitted for an autonomous recurrence.
/// {@category Binary Math}
@immutable
class BinaryLinearRecurrenceDescriptor {
  /// The square state-transition matrix.
  final BinaryMatrix stateMatrix;

  /// The optional matrix mapping input bits into the next state.
  final BinaryMatrix? inputMatrix;

  /// The packed constant XORed into every next state.
  final BigInt offset;

  /// Creates a binary linear recurrence descriptor.
  BinaryLinearRecurrenceDescriptor({
    required this.stateMatrix,
    this.inputMatrix,
    BigInt? offset,
  }) : offset = offset ?? BigInt.zero {
    if (stateMatrix.rowCount != stateMatrix.columnCount) {
      throw RohdHclException(
          'Binary recurrence state matrix must be square, but is '
          '${stateMatrix.rowCount}x${stateMatrix.columnCount}.');
    }
    if (inputMatrix != null && inputMatrix!.rowCount != stateWidth) {
      throw RohdHclException(
          'Binary recurrence input matrix must have $stateWidth rows, but has '
          '${inputMatrix!.rowCount}.');
    }
    if (this.offset.isNegative || this.offset >= (BigInt.one << stateWidth)) {
      throw RohdHclException(
          'Binary recurrence offset ${this.offset} does not fit in '
          '$stateWidth state bits.');
    }
  }

  /// The number of state bits.
  int get stateWidth => stateMatrix.rowCount;

  /// The number of input bits, or zero for an autonomous recurrence.
  int get inputWidth => inputMatrix?.columnCount ?? 0;

  /// Advances packed [state] by one step using packed [input].
  BigInt advance(BigInt state, {BigInt? input}) =>
      transitionForInput(input ?? BigInt.zero).apply(state);

  /// Returns the state transform for one step with constant packed [input].
  BinaryAffineTransform transitionForInput(BigInt input) {
    if (inputWidth == 0 && input != BigInt.zero) {
      throw RohdHclException(
          'Autonomous binary recurrence does not accept input $input.');
    }
    final inputContribution = inputMatrix?.multiplyVector(input) ?? BigInt.zero;
    return BinaryAffineTransform(
      stateMatrix,
      offset: inputContribution ^ offset,
    );
  }

  /// Returns the state transform for consecutive constant [inputs].
  ///
  /// The first iterable element is consumed by the first recurrence step.
  BinaryAffineTransform transitionForInputs(Iterable<BigInt> inputs) {
    var result = BinaryAffineTransform.identity(stateWidth);
    for (final input in inputs) {
      result = transitionForInput(input).compose(result);
    }
    return result;
  }

  /// Advances packed [state] through consecutive constant [inputs].
  BigInt advanceAll(BigInt state, Iterable<BigInt> inputs) =>
      transitionForInputs(inputs).apply(state);

  /// A deterministic signature suitable for generated definition names.
  String get configurationSignature => '${stateMatrix.configurationSignature}_'
      '${inputMatrix?.configurationSignature ?? "autonomous"}_'
      '${offset.toRadixString(16)}';

  @override
  bool operator ==(Object other) =>
      other is BinaryLinearRecurrenceDescriptor &&
      stateMatrix == other.stateMatrix &&
      inputMatrix == other.inputMatrix &&
      offset == other.offset;

  @override
  int get hashCode => Object.hash(stateMatrix, inputMatrix, offset);
}
