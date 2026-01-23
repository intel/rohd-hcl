// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// apb_completer.dart
// Base implementation for APB completer HW and associated variants.
//
// 2025 December
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// For APB completion.
enum ApbCompleterState {
  /// Waiting for a transaction.
  idle,

  /// Selected, waiting for transaction enable.
  selected,

  /// Executing the transaction.
  access,
}

/// A generic implementation for an APB Completer.
abstract class ApbCompleter extends Module {
  /// APB interface.
  late final ApbInterface apb;

  /// FSM for completion states.
  @protected
  late final FiniteStateMachine<ApbCompleterState> fsm;

  /// Indicator that data from APB can be consumed downstream.
  /// This can be used as an input for the consuming logic.
  @protected
  late final Logic downstreamValid;

  /// Indicator that data from downstream is consumable on APB
  /// This must be properly driven in any child class.
  @protected
  late final Logic upstreamValid;

  /// Constructor.
  ApbCompleter({required ApbInterface apb, super.name = 'apb_completer'}) {
    this.apb = apb.clone()
      ..connectIO(this, apb,
          inputTags: {
            ApbDirection.fromRequester,
            ApbDirection.fromRequesterExceptSelect,
            ApbDirection.misc
          },
          outputTags: {ApbDirection.fromCompleter},
          uniquify: (orig) => '${name}_$orig');

    downstreamValid = Logic(name: 'downstreamValid');
    upstreamValid = Logic(name: 'upstreamValid');
    fsm = FiniteStateMachine<ApbCompleterState>(
        this.apb.clk, ~this.apb.resetN, ApbCompleterState.idle, [
      // IDLE
      //    move to SELECTED when we get a SELx
      State(
        ApbCompleterState.idle,
        events: {
          this.apb.sel[0] & ~this.apb.enable: ApbCompleterState.selected,
        },
        actions: [
          downstreamValid < 0,
        ],
      ),
      // SELECTED move when we get an ENABLE if the transaction has latency,
      //    move to ACCESS state if the transaction has no latency, can move
      //    directly back to IDLE for performance
      State(
        ApbCompleterState.selected,
        events: {
          this.apb.enable & ~upstreamValid: ApbCompleterState.access,
          this.apb.enable & upstreamValid: ApbCompleterState.idle,
        },
        actions: [
          downstreamValid < this.apb.enable,
        ],
      ),
      // ACCESS
      //    move to IDLE when the transaction is done
      State(
        ApbCompleterState.access,
        events: {
          upstreamValid: ApbCompleterState.idle,
        },
        actions: [
          downstreamValid < 1,
        ],
      ),
    ]);

    _build();
  }

  // no power management built in so we ignore apb.wakeup if present
  void _build() {
    apb.ready <=
        (fsm.currentState.eq(Const(ApbCompleterState.selected.index,
                    width: fsm.currentState.width)) |
                fsm.currentState.eq(Const(ApbCompleterState.access.index,
                    width: fsm.currentState.width))) &
            upstreamValid;
  }
}
