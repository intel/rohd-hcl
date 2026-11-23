// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// lfsr.dart
// Tap-configured right-shifting Fibonacci LFSR.
//
// 2026 November 15
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd_hcl/src/binary_math/recurrence/lfsr_descriptor.dart';
import 'package:rohd_hcl/src/binary_math/recurrence/parallel_lfsr.dart';

/// A right-shifting Fibonacci LFSR configured by feedback taps.
///
/// `feedbackTaps` are unique zero-based state-bit indices. On each step, the
/// XOR of those bits enters the most-significant bit and bit zero shifts out.
/// [dataOut] packs [stepsPerCycle] consecutive output bits, earliest in bit
/// zero. Taps need not include bit zero; no maximal-period claim is made.
///
/// Reset takes priority over load, which takes priority over enable. A load
/// occurs even when enable is low. The default initial state is zero; provide
/// a reset and nonzero [initialState] when a nonzero starting state is needed.
/// {@category Binary Math}
class Lfsr extends ParallelLfsr {
  /// Creates an LFSR using [feedbackTaps] and [stateWidth].
  ///
  /// Taps must be nonempty and in `0..stateWidth - 1`. [load] and [loadState]
  /// must be supplied together. A nonzero [initialState] requires [reset].
  Lfsr({
    required super.clk,
    required int stateWidth,
    required List<int> feedbackTaps,
    super.stepsPerCycle = 1,
    super.reset,
    super.enable,
    super.load,
    super.loadState,
    super.initialState,
    super.asyncReset,
    super.name = 'lfsr',
    super.reserveName,
    super.reserveDefinitionName,
    super.definitionName,
  }) : super(
          lfsrDescriptor: LfsrDescriptor.fromFeedbackTaps(
            stateWidth: stateWidth,
            feedbackTaps: feedbackTaps,
          ),
        );
}
