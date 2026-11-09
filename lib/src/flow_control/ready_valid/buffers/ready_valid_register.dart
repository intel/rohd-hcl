// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_register.dart
// One-entry registered ready/valid buffer.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A one-entry ready/valid register with no fall-through path.
///
/// An occupied stage may accept a replacement item on the same edge that its
/// current item is accepted downstream. Its upstream ready response depends
/// only on stored occupancy and downstream ready; its downstream offer is
/// irrevocable. The external upstream provider retains ownership of its valid
/// behavior, so the upstream interface remains contract-generic.
/// {@category Memory}
class ReadyValidRegister<LogicType extends Logic> extends Module
    implements ReadyValidStorageStatus {
  /// Upstream interface accepted by this stage.
  late final ReadyValidInterface<LogicType> upstream;

  /// Downstream interface driven by this stage.
  late final IrrevocableReadyValidInterface<LogicType> downstream;

  /// Whether the register currently stores an item.
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

  /// Creates a one-entry registered ready/valid stage.
  ReadyValidRegister(
      {required Logic clk,
      required Logic reset,
      required ReadyValidInterface<LogicType> upstream,
      required ReadyValidInterface<LogicType> downstream,
      String name = 'ready_valid_register'})
      : super(
            definitionName: 'ReadyValidRegister_${upstream.data.name}',
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
      mode: SingleEntryBufferMode.registered,
      name: name,
    );
    occupancy <= occupied;
    empty <= ~occupied;
    full <= occupied;
  }
}
