// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// synchronizer.dart
// A multi-flop synchronizer for clock domain crossing.
//
// 2026 January 13
// Author: Maifee Ul Asad <maifeeulasad@gmail.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A multi-flop synchronizer for a stable single-bit control crossing.
///
/// The [Synchronizer] implements a chain of flip-flops to reduce metastability
/// when crossing signals from one clock domain to another. This is essential
/// for Clock Domain Crossing (CDC) to reduce metastability risk.
///
/// The typical implementation uses 2 or 3 flip-flop stages. The first stage
/// may capture a metastable value, but subsequent stages allow time for the
/// signal to settle before being used in the destination clock domain.
///
/// **Implementation Note**: This extends [ShiftRegister] with CDC-specific
/// constraints: minimum 2 stages, no enable signal, no async reset, and
/// the [stages] getter is inaccessible. The inherited module output ports for
/// intermediate stages still exist and must not be used by downstream logic.
///
/// Reset, when supplied, is synchronous to the destination clock. Its
/// assertion and release must meet destination-domain timing requirements.
/// Input levels must remain stable long enough to be sampled; pulses and
/// events can be lost. Multi-bit inputs are independently synchronized and
/// are not guaranteed to be coherent. Use an appropriate handshake or async
/// FIFO for changing multi-bit data. Simulation cannot prove metastability
/// safety: use technology-specific synchronizer placement and CDC constraints.
class Synchronizer extends ShiftRegister<Logic> {
  /// The synchronized output signal in the destination clock domain.
  Logic get syncData => dataOut;

  /// The number of synchronization stages (flip-flops).
  ///
  /// Minimum is 2. Higher values provide more metastability protection but
  /// increase latency.
  int get numStages => depth;

  /// Constructs a [Synchronizer] with the specified parameters.
  ///
  /// - [clk]: The destination clock domain.
  /// - [dataIn]: The signal to synchronize from the source clock domain.
  /// - [reset]: Optional reset signal for the destination domain.
  /// - [resetValue]: Value to initialize synchronizer stages on reset.
  /// - [stages]: Number of flip-flop stages (default: 2, minimum: 2).
  ///
  /// Example:
  /// ```dart
  /// final sync = Synchronizer(
  ///   destClk,
  ///   dataIn: sourceSignal,
  ///   reset: destReset,
  /// );
  /// ```
  Synchronizer(
    Logic clk, {
    required Logic dataIn,
    Logic? reset,
    dynamic resetValue = 0,
    int stages = 2,
    String name = 'synchronizer',
  }) : super(
          dataIn,
          clk: clk,
          depth: stages,
          reset: reset,
          resetValue: resetValue,
          dataName: name,
          definitionName: 'Synchronizer_S${stages}_W${dataIn.width}',
        ) {
    if (stages < 2) {
      throw RohdHclException('Synchronizer must have at least 2 stages.');
    }
  }

  /// Prevents access to intermediate stages through the Dart getter.
  ///
  /// Accessing intermediate stages of a synchronizer can lead to metastability
  /// issues. Inherited intermediate output ports must not be connected; use
  /// [syncData] instead.
  @override
  List<Logic> get stages => throw RohdHclException(
      'Cannot access intermediate stages of Synchronizer - CDC hazard! '
      'Use syncData for the synchronized output.');
}
