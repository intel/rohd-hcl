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
/// **WARNING**: This synchronizer is only suitable for control signals, not
/// data buses. For data transfer between clock domains, use an async FIFO.
class Synchronizer extends Module {
  /// The synchronized output signal in the destination clock domain.
  Logic get syncData => output('syncData');

  /// The number of synchronization stages (flip-flops).
  ///
  /// Minimum is 2. Higher values provide more metastability protection but
  /// increase latency.
  final int stages;

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
    this.stages = 2,
    super.name = 'synchronizer',
  }) : super(definitionName: 'Synchronizer_S${stages}_W${dataIn.width}') {
    if (stages < 2) {
      throw RohdHclException('Synchronizer must have at least 2 stages.');
    }

    clk = addInput('clk', clk);
    dataIn = addInput('dataIn', dataIn, width: dataIn.width);
    if (reset != null) {
      reset = addInput('reset', reset);
    }

    addOutput('syncData', width: dataIn.width);

    // Create the chain of synchronization flip-flops
    final syncStages = <Logic>[];
    for (var i = 0; i < stages; i++) {
      syncStages.add(Logic(name: 'syncStage$i', width: dataIn.width));
    }

    // Connect the stages
    final resetValues = <Logic, dynamic>{};
    for (var i = 0; i < stages; i++) {
      resetValues[syncStages[i]] = resetValue;
    }

    Sequential(
      clk,
      reset: reset,
      resetValues: resetValues,
      [
        // First stage samples the input
        syncStages[0] < dataIn,
        // Subsequent stages form the synchronization chain
        for (var i = 1; i < stages; i++) syncStages[i] < syncStages[i - 1],
      ],
    );

    // Output is the last stage
    syncData <= syncStages.last;
  }
}
