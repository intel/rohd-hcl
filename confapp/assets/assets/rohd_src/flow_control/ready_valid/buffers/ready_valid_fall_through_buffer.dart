// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_fall_through_buffer.dart
// Fall-through buffering for ready/valid traffic.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A one-entry ready/valid buffer with a combinational empty-stage bypass.
///
/// An empty buffer presents an upstream offer directly to the downstream
/// boundary. A stalled offer is captured at the clock edge and remains
/// irrevocable until it is accepted. The external upstream provider retains
/// ownership of its valid behavior, so the upstream interface is
/// contract-generic.
/// {@category Memory}
class ReadyValidFallThroughBuffer<LogicType extends Logic> extends Module
    implements ReadyValidStorageStatus {
  /// Upstream interface accepted by this buffer.
  late final ReadyValidInterface<LogicType> upstream;

  /// Downstream interface driven by this buffer.
  late final IrrevocableReadyValidInterface<LogicType> downstream;

  /// Whether the buffer currently stores an item.
  Logic get occupied => output('occupied');

  @override
  int get capacity => 1;

  @override
  Logic get occupancy => output('occupancy');

  @override
  Logic get empty => output('empty');

  @override
  Logic get full => output('full');

  /// Module clock.
  @protected
  late final Logic clk;

  /// Module reset.
  @protected
  late final Logic reset;

  /// Creates a one-entry fall-through ready/valid buffer.
  ReadyValidFallThroughBuffer(
      {required Logic clk,
      required Logic reset,
      required ReadyValidInterface<LogicType> upstream,
      required ReadyValidInterface<LogicType> downstream,
      String name = 'ready_valid_fall_through_buffer'})
      : super(
            definitionName: 'ReadyValidFallThroughBuffer_${upstream.data.name}',
            name: name) {
    this.clk = addInput('clk', clk);
    this.reset = addInput('reset', reset);
    addOutput('occupied');
    addOutput('occupancy');
    addOutput('empty');
    addOutput('full');

    this.upstream = addPairInterfacePorts(upstream, PairRole.consumer,
        uniquify: (original) => 'upstream_$original');
    this.downstream = addPairInterfaceFrom(
      IrrevocableReadyValidInterface<LogicType>(downstream.data.cloneTyped()),
      downstream,
      PairRole.provider,
      uniquify: (original) => 'downstream_$original',
    );

    final storedData = this.upstream.data.cloneTyped();
    configureSingleEntryBuffer(
      clk: this.clk,
      reset: this.reset,
      occupied: occupied,
      upstream: this.upstream,
      downstream: this.downstream,
      storedData: storedData,
      mode: SingleEntryBufferMode.fallThrough,
      name: name,
    );
    occupancy <= occupied;
    empty <= ~occupied;
    full <= occupied;
  }
}
