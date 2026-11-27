// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// prbs_generator.dart
// Serial and parallel pseudorandom binary sequence generation.
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd_hcl/src/binary_math/prbs/prbs_configuration.dart';
import 'package:rohd_hcl/src/binary_math/recurrence/parallel_lfsr.dart';

/// Generates a pseudorandom binary sequence.
///
/// [dataOut] contains [bitsPerCycle] consecutive sequence bits, with the
/// earliest bit in bit zero. Set [bitsPerCycle] to one for serial operation.
/// The generator always resets to [configuration]'s non-zero seed.
/// {@category Binary Math}
class PrbsGenerator extends ParallelLfsr {
  /// The sequence polynomial and seed.
  final PrbsConfiguration configuration;

  /// The number of sequence bits generated per enabled clock edge.
  int get bitsPerCycle => stepsPerCycle;

  /// Creates a PRBS generator.
  PrbsGenerator({
    required super.clk,
    required super.reset,
    required this.configuration,
    int bitsPerCycle = 1,
    super.enable,
    super.asyncReset,
    super.radix,
    super.name = 'prbs_generator',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
          lfsrDescriptor: configuration.lfsrDescriptor,
          stepsPerCycle: bitsPerCycle,
          initialState: configuration.seed,
          definitionName: definitionName ??
              'PrbsGenerator_${configuration.configurationSignature}_'
                  'P${bitsPerCycle}_R${radix}_'
                  'A${asyncReset ? 1 : 0}_E${enable == null ? 0 : 1}',
        );
}
