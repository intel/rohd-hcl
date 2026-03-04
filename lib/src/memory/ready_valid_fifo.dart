// Copyright (C) 2025 Intel Corporation
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
import 'package:rohd_hcl/rohd_hcl.dart';

/// A simple generic module that wires a single upstream and downstream
/// [ReadyValidInterface] for a given [LogicType] through an internal
/// [Fifo] instance.
///
///  The internal FIFO will buffer values of the  type parameter [LogicType].
class ReadyValidFifo<LogicType extends LogicStructure> extends Module {
  /// Upstream interface (input requests)
  late final ReadyValidInterface<LogicType> upstream;

  /// Downstream interface (output responses)
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

    // Clone and connect the provided interfaces to module-local interfaces
    // (consumer role for upstream, provider role for downstream).
    this.upstream = upstream.clone()
      ..pairConnectIO(this, upstream, PairRole.consumer,
          uniquify: (original) => 'upstream_$original');

    this.downstream = downstream.clone()
      ..pairConnectIO(this, downstream, PairRole.provider,
          uniquify: (original) => 'downstream_$original');

    // Use the upstream data shape as a template for FIFO element.
    final writeData = this.upstream.data.clone() as LogicType;

    fifo = Fifo<LogicType>(this.clk, this.reset,
        writeEnable: writeEnable,
        readEnable: readEnable,
        writeData: writeData,
        depth: depth,
        generateOccupancy: true,
        name: '${name}_fifo');

    // Connect upstream valid/data to FIFO write when not full.
    writeEnable <= this.upstream.valid & ~fifo.full;
    writeData <= this.upstream.data;

    // Drive upstream ready when FIFO can accept
    this.upstream.ready <= ~fifo.full;

    // Downstream side: read when downstream ready and fifo not empty.
    final shouldRead = this.downstream.ready & ~fifo.empty;
    readEnable <= shouldRead;

    // Drive downstream valid and data from FIFO readData.
    this.downstream.valid <= ~fifo.empty;
    final readData = this.upstream.data.clone() as LogicType;
    readData <= fifo.readData;
    this.downstream.data <= readData;
  }
}
