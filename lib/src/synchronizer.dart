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

/// A multi-flop synchronizer for safely crossing clock domains.
///
/// The [Synchronizer] implements a chain of flip-flops to reduce metastability
/// when crossing signals from one clock domain to another. This is essential
/// for Clock Domain Crossing (CDC) to prevent metastability issues.
///
/// The typical implementation uses 2 or 3 flip-flop stages. The first stage
/// may capture a metastable value, but subsequent stages allow time for the
/// signal to settle before being used in the destination clock domain.
///
/// **Implementation Note**: This extends [ShiftRegister] with CDC-specific
/// constraints: minimum 2 stages, no enable signal, no async reset, and
/// intermediate stages are hidden to prevent misuse.
///
/// **WARNING**: This synchronizer is only suitable for control signals, not
/// data buses. For data transfer between clock domains, use an async FIFO.
class Synchronizer extends ShiftRegister {
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
          dataName: 'syncData',
          definitionName: 'Synchronizer_S${stages}_W${dataIn.width}',
        ) {
    if (stages < 2) {
      throw RohdHclException('Synchronizer must have at least 2 stages.');
    }
  }

  /// Hides intermediate stages to prevent CDC violations.
  ///
  /// Accessing intermediate stages of a synchronizer can lead to metastability
  /// issues. Use [syncData] to access the properly synchronized output.
  @override
  List<Logic> get stages => throw RohdHclException(
      'Cannot access intermediate stages of Synchronizer - CDC hazard! '
      'Use syncData for the synchronized output.');
}
