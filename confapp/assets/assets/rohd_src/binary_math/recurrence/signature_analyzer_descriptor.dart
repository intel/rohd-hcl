// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// signature_analyzer_descriptor.dart
// Immutable multiple-input signature analysis descriptors.
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd_hcl/src/binary_math/algebra/binary_matrix.dart';
import 'package:rohd_hcl/src/binary_math/recurrence/binary_linear_recurrence_descriptor.dart';
import 'package:rohd_hcl/src/binary_math/recurrence/lfsr_descriptor.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// Describes a multiple-input signature analyzer.
///
/// Each input word is consumed bit zero first. For every input bit, the
/// right-shifting recurrence in [lfsrDescriptor] advances once and the input
/// bit is XORed into the newly inserted high state bit. The composed recurrence
/// processes all [inputWidth] bits in one hardware cycle.
/// {@category Binary Math}
@immutable
class SignatureAnalyzerDescriptor {
  /// The underlying LFSR convention and characteristic polynomial.
  final LfsrDescriptor lfsrDescriptor;

  /// The number of input bits accumulated per advancement.
  final int inputWidth;

  late final BinaryLinearRecurrenceDescriptor _recurrence = _createRecurrence();

  /// Creates a multiple-input signature analyzer descriptor.
  SignatureAnalyzerDescriptor({
    required this.lfsrDescriptor,
    required this.inputWidth,
  }) {
    if (inputWidth <= 0) {
      throw RohdHclException(
          'Signature analyzer input width must be positive.');
    }
  }

  /// The number of signature state bits.
  int get signatureWidth => lfsrDescriptor.width;

  /// The composed state and input recurrence.
  BinaryLinearRecurrenceDescriptor get recurrence => _recurrence;

  /// Accumulates packed [data] into packed [signature].
  BigInt accumulate(BigInt signature, BigInt data) =>
      recurrence.advance(signature, input: data);

  BinaryLinearRecurrenceDescriptor _createRecurrence() {
    final stateMatrix = lfsrDescriptor.transition(inputWidth).matrix;
    final inputColumns = <BigInt>[];
    for (var inputIndex = 0; inputIndex < inputWidth; inputIndex++) {
      var state = BigInt.zero;
      for (var step = 0; step < inputWidth; step++) {
        state = lfsrDescriptor.advance(state);
        if (step == inputIndex) {
          state ^= BigInt.one << (signatureWidth - 1);
        }
      }
      inputColumns.add(state);
    }

    final inputRows = List<BigInt>.generate(signatureWidth, (row) {
      var rowMask = BigInt.zero;
      for (var column = 0; column < inputWidth; column++) {
        if (((inputColumns[column] >> row) & BigInt.one) == BigInt.one) {
          rowMask |= BigInt.one << column;
        }
      }
      return rowMask;
    });

    return BinaryLinearRecurrenceDescriptor(
      stateMatrix: stateMatrix,
      inputMatrix: BinaryMatrix(inputRows, columnCount: inputWidth),
    );
  }

  /// A deterministic signature suitable for generated definition names.
  String get configurationSignature =>
      '${lfsrDescriptor.configurationSignature}_I$inputWidth';

  @override
  bool operator ==(Object other) =>
      other is SignatureAnalyzerDescriptor &&
      lfsrDescriptor == other.lfsrDescriptor &&
      inputWidth == other.inputWidth;

  @override
  int get hashCode => Object.hash(lfsrDescriptor, inputWidth);
}
