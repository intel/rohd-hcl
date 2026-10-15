// Copyright (C) 2025-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_fifo.dart
// Generic ready/valid FIFO module that pipes a [ReadyValidInterface] of a
// [LogicStructure]-derived type through an internal [Fifo] instance.
//
// 2025 October 21
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/flow_control/attachments/directional_attachments.dart';
import 'package:rohd_hcl/src/flow_control/control/fifo_core_functor.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/transport/ready_valid_interface.dart';
import 'package:rohd_hcl/src/flow_control/storage/fifo.dart';
import 'package:rohd_hcl/src/interfaces/interface_port_helpers.dart';

/// A simple generic module that wires a single upstream and downstream
/// [ReadyValidInterface] for a given [LogicType] through an internal
/// [Fifo] instance.
///
///  The internal FIFO will buffer values of the  type parameter [LogicType].
class ReadyValidFifo<LogicType extends LogicStructure> extends Module {
  /// Upstream interface accepted by this FIFO.
  late final ReadyValidInterface<LogicType> upstream;

  /// Downstream interface driven by this FIFO.
  late final ReadyValidInterface<LogicType> downstream;

  /// Internal FIFO instance
  @protected
  late final Fifo<LogicType> fifo;

  /// FIFO depth
  final int depth;

  /// Module clock
  @protected
  late final Logic clk;

  /// Module reset
  @protected
  late final Logic reset;

  /// Constructs a new [ReadyValidFifo].
  ReadyValidFifo({
    required Logic clk,
    required Logic reset,

    /// Templates describing the shape of the upstream/downstream data
    required ReadyValidInterface<LogicType> upstream,
    required ReadyValidInterface<LogicType> downstream,
    this.depth = 8,
    String name = 'ready_valid_fifo',
  }) : super(
            definitionName: 'ReadyValidFifo_${upstream.data.name}',
            name: name) {
    // Build the internal logic
    final writeEnable = Logic(name: '${name}_write_en');
    final readEnable = Logic(name: '${name}_read_en');

    // Add clock/reset ports and capture the module-local signals
    this.clk = addInput('clk', clk);
    this.reset = addInput('reset', reset);

    this.upstream = addPairInterface(
      upstream,
      PairRole.consumer,
      uniquify: (original) => 'upstream_$original',
    );
    this.downstream = addPairInterface(
      downstream,
      PairRole.provider,
      uniquify: (original) => 'downstream_$original',
    );

    // Use the upstream data shape as a template for FIFO element.
    final writeData = this.upstream.data.clone() as LogicType;
    final binding = FifoCoreFunctor<LogicType>(
      depth: depth,
      generateOccupancy: true,
    ).construct(
      FifoCoreRequest<LogicType>(
        clk: this.clk,
        reset: this.reset,
        enqueue: writeEnable,
        dequeue: readEnable,
        payload: writeData,
      ),
      name: '${name}_fifo',
    );
    fifo = binding.module;

    ReadyValidIngressAttachmentPolicy<LogicType>(
      supportsSameCycleReplacement: false,
      storageDepth: depth,
    ).attach(
      upstream: this.upstream,
      canAccept: ~binding.full,
      accept: writeEnable,
      payload: writeData,
    );
    ReadyValidEgressAttachmentPolicy<LogicType>().attach(
      downstream: this.downstream,
      offerValid: binding.outputValid,
      payload: binding.output,
      transfer: readEnable,
    );
  }
}
