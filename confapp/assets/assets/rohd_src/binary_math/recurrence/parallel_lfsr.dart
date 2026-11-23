// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// parallel_lfsr.dart
// Parallel right-shifting Fibonacci LFSR hardware.
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/binary_math/algebra/binary_linear_transform.dart';
import 'package:rohd_hcl/src/binary_math/recurrence/binary_linear_recurrence.dart';
import 'package:rohd_hcl/src/binary_math/recurrence/lfsr_descriptor.dart';

/// A right-shifting Fibonacci LFSR that advances multiple bits per clock.
///
/// [dataOut] contains [stepsPerCycle] consecutive serial output bits. Bit zero
/// is the earliest output bit. An enabled clock edge advances the state by the
/// same number of serial steps.
/// {@category Binary Math}
class ParallelLfsr extends BinaryLinearRecurrence {
  /// The LFSR convention and characteristic polynomial.
  final LfsrDescriptor lfsrDescriptor;

  /// The number of serial steps performed per enabled clock edge.
  final int stepsPerCycle;

  /// Consecutive serial outputs packed earliest-first.
  Logic get dataOut => output('data_out');

  /// Creates a parallel Fibonacci LFSR.
  ParallelLfsr({
    required super.clk,
    required this.lfsrDescriptor,
    required this.stepsPerCycle,
    super.reset,
    super.enable,
    super.load,
    super.loadState,
    super.initialState,
    super.asyncReset,
    int radix = 2,
    super.name = 'parallel_lfsr',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
          descriptor: lfsrDescriptor.parallelRecurrence(stepsPerCycle),
          radix: radix,
          definitionName: definitionName ??
              'ParallelLfsr_${lfsrDescriptor.configurationSignature}_'
                  'P${stepsPerCycle}_R${radix}_'
                  'V${(initialState ?? BigInt.zero).toRadixString(16)}_'
                  'A${asyncReset ? 1 : 0}_E${enable == null ? 0 : 1}_'
                  'L${load == null ? 0 : 1}',
        ) {
    final outputTransform = BinaryLinearTransform(
      state,
      matrix: lfsrDescriptor.outputTransform(stepsPerCycle).matrix,
      radix: radix,
    );
    addOutput('data_out', width: stepsPerCycle) <= outputTransform.result;
  }
}
