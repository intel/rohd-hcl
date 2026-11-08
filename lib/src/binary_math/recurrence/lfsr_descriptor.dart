// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// lfsr_descriptor.dart
// Immutable right-shifting Fibonacci LFSR descriptors.
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd_hcl/src/binary_math/algebra/binary_affine_transform.dart';
import 'package:rohd_hcl/src/binary_math/algebra/binary_matrix.dart';
import 'package:rohd_hcl/src/binary_math/algebra/binary_polynomial.dart';
import 'package:rohd_hcl/src/binary_math/recurrence/binary_linear_recurrence_descriptor.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// Describes a right-shifting Fibonacci linear-feedback shift register.
///
/// For a degree-`n` [polynomial], state bit zero is shifted out first. The new
/// state bit `n - 1` is the XOR of state bits selected by the polynomial's
/// coefficients below `x^n`. For example, `x^4 + x + 1` advances:
///
/// ```text
/// nextState[2:0] = state[3:1]
/// nextState[3]   = state[1] XOR state[0]
/// ```
///
/// The polynomial must have positive degree and a non-zero constant
/// coefficient. Primitivity is not required.
/// {@category Binary Math}
@immutable
class LfsrDescriptor {
  /// The characteristic polynomial.
  final BinaryPolynomial polynomial;

  late final BinaryLinearRecurrenceDescriptor _serialRecurrence =
      BinaryLinearRecurrenceDescriptor(stateMatrix: _createStateMatrix());

  /// Creates an LFSR descriptor using [polynomial].
  LfsrDescriptor(this.polynomial) {
    if (polynomial.degree < 1) {
      throw RohdHclException('LFSR polynomial must have positive degree.');
    }
    if (!polynomial.coefficient(0)) {
      throw RohdHclException(
          'LFSR polynomial must have a non-zero constant coefficient.');
    }
  }

  /// The number of state bits.
  int get width => polynomial.degree;

  /// The one-bit-per-step recurrence.
  BinaryLinearRecurrenceDescriptor get serialRecurrence => _serialRecurrence;

  /// Returns the recurrence that advances [steps] serial steps at once.
  BinaryLinearRecurrenceDescriptor parallelRecurrence(int steps) =>
      BinaryLinearRecurrenceDescriptor(
        stateMatrix: transition(steps).matrix,
      );

  /// Returns the state transform for [steps] serial advancements.
  BinaryAffineTransform transition(int steps) {
    _validateSteps(steps);
    return BinaryAffineTransform(_serialRecurrence.stateMatrix).pow(steps);
  }

  /// Returns the output transform for [steps] consecutive shifted-out bits.
  ///
  /// Result bit zero is the first serial output bit.
  BinaryAffineTransform outputTransform(int steps) {
    _validateSteps(steps);
    final rows = <BigInt>[];
    var stateTransform = BinaryAffineTransform.identity(width);
    final oneStep = BinaryAffineTransform(_serialRecurrence.stateMatrix);
    for (var index = 0; index < steps; index++) {
      rows.add(stateTransform.matrix.row(0));
      stateTransform = oneStep.compose(stateTransform);
    }
    return BinaryAffineTransform(BinaryMatrix(rows, columnCount: width));
  }

  /// Advances packed [state] by one serial step.
  BigInt advance(BigInt state) => _serialRecurrence.advance(state);

  /// Advances packed [state] by [steps] serial steps.
  BigInt advanceParallel(BigInt state, int steps) =>
      transition(steps).apply(state);

  /// Returns [steps] consecutive shifted-out bits packed earliest-first.
  BigInt outputBits(BigInt state, int steps) =>
      outputTransform(steps).apply(state);

  BinaryMatrix _createStateMatrix() => BinaryMatrix(
        [
          for (var row = 0; row < width - 1; row++) BigInt.one << (row + 1),
          polynomial.coefficients & ((BigInt.one << width) - BigInt.one),
        ],
        columnCount: width,
      );

  static void _validateSteps(int steps) {
    if (steps <= 0) {
      throw RohdHclException('LFSR step count must be positive.');
    }
  }

  /// A deterministic signature suitable for generated definition names.
  String get configurationSignature =>
      '${width}_${polynomial.coefficients.toRadixString(16)}';

  @override
  bool operator ==(Object other) =>
      other is LfsrDescriptor && polynomial == other.polynomial;

  @override
  int get hashCode => polynomial.hashCode;
}
