// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// prbs_checker.dart
// Seed-aligned pseudorandom binary sequence checking.
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/accumulation/accumulator.dart';
import 'package:rohd_hcl/src/binary_math/prbs/prbs_configuration.dart';
import 'package:rohd_hcl/src/binary_math/recurrence/parallel_lfsr.dart';
import 'package:rohd_hcl/src/bit_operations/population_count/count.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// Checks a seed-aligned pseudorandom binary sequence.
///
/// Enabled error-free words build confidence until [lockThreshold] consecutive
/// words have matched. Any mismatching enabled word clears [locked]
/// immediately. [errorCount] saturates while counting individual mismatching
/// bits, and the optional clear-errors input clears only that counter.
///
/// This checker does not perform phase acquisition. The source and checker must
/// reset to the same seed and advance under the same enable pattern.
/// {@category Binary Math}
class PrbsChecker extends ParallelLfsr {
  /// The sequence polynomial and seed.
  final PrbsConfiguration configuration;

  /// The number of sequence bits checked per enabled clock edge.
  int get bitsPerCycle => stepsPerCycle;

  /// The consecutive matching-word count required to assert [locked].
  final int lockThreshold;

  /// The width of the saturating [errorCount].
  final int errorCountWidth;

  /// The expected sequence word.
  Logic get expectedData => dataOut;

  /// The XOR difference between received and expected sequence bits.
  Logic get mismatchBits => output('mismatch_bits');

  /// High when any bit in the current received word mismatches.
  Logic get mismatch => output('mismatch');

  /// High after [lockThreshold] consecutive enabled words match.
  Logic get locked => output('locked');

  /// The saturating count of mismatching enabled bits.
  Logic get errorCount => output('error_count');

  /// Creates a seed-aligned PRBS checker.
  PrbsChecker({
    required super.clk,
    required super.reset,
    required Logic dataIn,
    required this.configuration,
    int bitsPerCycle = 1,
    this.lockThreshold = 4,
    this.errorCountWidth = 32,
    Logic? clearErrors,
    Logic? enable,
    super.asyncReset,
    super.radix,
    super.name = 'prbs_checker',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
          lfsrDescriptor: configuration.lfsrDescriptor,
          stepsPerCycle: bitsPerCycle,
          initialState: configuration.seed,
          enable: enable,
          definitionName: definitionName ??
              'PrbsChecker_${configuration.configurationSignature}_'
                  'P${bitsPerCycle}_L${lockThreshold}_C${errorCountWidth}_'
                  'R${radix}_A${asyncReset ? 1 : 0}_'
                  'E${enable == null ? 0 : 1}_'
                  'X${clearErrors == null ? 0 : 1}',
        ) {
    if (lockThreshold <= 0) {
      throw RohdHclException('PRBS lock threshold must be positive.');
    }
    if (errorCountWidth <= 0) {
      throw RohdHclException('PRBS error count width must be positive.');
    }
    if (dataIn.width != bitsPerCycle) {
      throw PortWidthMismatchException(dataIn, bitsPerCycle);
    }

    dataIn = addInput('data_in', dataIn, width: bitsPerCycle);
    if (clearErrors != null) {
      clearErrors = addInput('clear_errors', clearErrors);
    }

    final mismatchBits = addOutput('mismatch_bits', width: bitsPerCycle);
    final mismatch = addOutput('mismatch');
    final locked = addOutput('locked');
    final errorCount = addOutput('error_count', width: errorCountWidth);
    mismatchBits <= dataIn ^ expectedData;
    mismatch <= mismatchBits.or();

    final matchCountWidth = max(1, (lockThreshold + 1).log2Ceil);
    final mismatchCount = Count(mismatchBits).count;
    final localEnable = enable == null ? Const(1) : input('enable');
    final localClearErrors = clearErrors ?? Const(0);
    final matchAccumulator = Accumulator(
      Const(1),
      clk: input('clk'),
      reset: input('reset'),
      width: matchCountWidth,
      enable: localEnable & ~mismatch & ~locked,
      clear: localEnable & mismatch,
      asyncReset: asyncReset,
      name: 'matchAccumulator',
    );
    final matchCount = matchAccumulator.value;
    final errorAccumulator = Accumulator(
      mismatchCount,
      clk: input('clk'),
      reset: input('reset'),
      width: errorCountWidth,
      enable: localEnable & mismatch,
      clear: localClearErrors,
      saturates: true,
      asyncReset: asyncReset,
      name: 'errorAccumulator',
    );
    errorCount <= errorAccumulator.value;

    Sequential(
      input('clk'),
      reset: input('reset'),
      asyncReset: asyncReset,
      resetValues: {locked: 0},
      [
        If(localEnable, then: [
          If(mismatch, then: [
            locked < 0,
          ], orElse: [
            If(~locked, then: [
              If(matchCount.eq(lockThreshold - 1), then: [
                locked < 1,
              ]),
            ]),
          ]),
        ]),
      ],
    );
  }
}
