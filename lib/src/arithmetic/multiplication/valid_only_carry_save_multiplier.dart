// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// valid_only_carry_save_multiplier.dart
// Valid-only shell for a fixed-latency carry-save multiplier.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/multiplication/carry_save_multiplier.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/transport/valid_only_interface.dart';
import 'package:rohd_hcl/src/interfaces/interface_port_helpers.dart';
import 'package:rohd_hcl/src/pipeline_timing_contract.dart';

/// Multiplies valid-only operands with fixed physical-cycle latency.
///
/// Bubbles are propagated by delaying the conjunction of the operand valid
/// signals by [timing].latency clocks. This shell deliberately does not stall
/// the underlying multiplier: valid-only channels have no backpressure path.
/// {@category Arithmetic}
class ValidOnlyCarrySaveMultiplier extends Module {
  /// Timing behavior of the wrapped fixed-latency multiplier.
  final PipelineTimingContract timing;

  late final ValidOnlyInterface<Logic> _multiplicand;
  late final ValidOnlyInterface<Logic> _multiplier;
  late final ValidOnlyInterface<Logic> _product;

  /// Creates a valid-only wrapper for equally wide carry-save operands.
  ValidOnlyCarrySaveMultiplier({
    required Logic clk,
    required Logic reset,
    required ValidOnlyInterface<Logic> multiplicand,
    required ValidOnlyInterface<Logic> multiplier,
    required ValidOnlyInterface<Logic> product,
    String name = 'valid_only_carry_save_multiplier',
  })  : timing = PipelineTimingContract(
          latency: multiplicand.data.width + 1,
          initiationInterval: 1,
          stallability: PipelineStallability.none,
          acceptsBubbles: true,
          supportsFlush: false,
          maximumInFlight: multiplicand.data.width + 1,
        ),
        super(
          definitionName: 'ValidOnlyCarrySaveMultiplier_W'
              '${multiplicand.data.width}',
          name: name,
        ) {
    if (multiplicand.data.width != multiplier.data.width ||
        product.data.width != multiplicand.data.width + multiplier.data.width) {
      throw ArgumentError(
          'Operand widths must match and product width must be their sum.');
    }
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    _multiplicand = addPairInterface(multiplicand, PairRole.consumer,
        uniquify: (original) => 'multiplicand_$original');
    _multiplier = addPairInterface(multiplier, PairRole.consumer,
        uniquify: (original) => 'multiplier_$original');
    _product = addPairInterface(product, PairRole.provider,
        uniquify: (original) => 'product_$original');

    final core = CarrySaveMultiplier(
      _multiplicand.data,
      _multiplier.data,
      clk: clk,
      reset: reset,
      name: '${name}_core',
    );
    var delayedValid = _multiplicand.valid & _multiplier.valid;
    for (var stage = 0; stage < timing.latency; stage++) {
      delayedValid = flop(clk, reset: reset, delayedValid);
    }
    _product.data <= core.product;
    _product.valid <= delayedValid;
  }
}
