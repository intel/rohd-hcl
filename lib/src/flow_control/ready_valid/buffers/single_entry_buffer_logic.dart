// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// single_entry_buffer_logic.dart
// Implementation of single entry buffer logic.
//
// 2026 October 9
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/transport/ready_valid_interface.dart';

/// Selects the one-entry buffer's ready and capture timing.
enum SingleEntryBufferMode {
  /// Registers the output and does not bypass an empty stage.
  registered,

  /// Allows same-cycle consume and refill through a combinational ready path.
  fallThrough,

  /// Breaks the downstream-ready path and captures only into an empty slot.
  skid,
}

/// Configures the shared state machine used by both one-entry buffer wrappers.
void configureSingleEntryBuffer<LogicType extends Logic>({
  required Logic clk,
  required Logic reset,
  required Logic occupied,
  required ReadyValidInterface<LogicType> upstream,
  required IrrevocableReadyValidInterface<LogicType> downstream,
  required LogicType storedData,
  required SingleEntryBufferMode mode,
  required String name,
  Logic? admission,
}) {
  final admissionEnabled = admission ?? Const(1);
  final readAccepted =
      (downstream.ready & downstream.valid).named('${name}_read_accepted');
  final writeAccepted =
      (upstream.ready & upstream.valid).named('${name}_write_accepted');

  if (mode == SingleEntryBufferMode.registered ||
      mode == SingleEntryBufferMode.fallThrough) {
    if (mode == SingleEntryBufferMode.registered) {
      upstream.ready <= ~occupied | downstream.ready;
      downstream.valid <= occupied;
      downstream.data <= storedData;
    } else {
      upstream.ready <= ~occupied | downstream.ready;
      downstream.valid <= occupied | upstream.valid;
      downstream.data <= mux(occupied, storedData, upstream.data);
    }

    final nextOccupied = mode == SingleEntryBufferMode.registered
        ? (writeAccepted | (occupied & ~readAccepted))
        : ((occupied & ~readAccepted) |
            (writeAccepted & (occupied | ~readAccepted)));
    Sequential(clk, reset: reset, resetValues: {
      occupied: 0
    }, [
      If(writeAccepted, then: [storedData < upstream.data]),
      occupied < nextOccupied,
    ]);
    return;
  }

  upstream.ready <= ~occupied & admissionEnabled;
  downstream.valid <= occupied | (upstream.valid & admissionEnabled);
  downstream.data <= mux(occupied, storedData, upstream.data);
  final capture =
      (~occupied & admissionEnabled & upstream.valid & ~downstream.ready)
          .named('${name}_capture');
  Sequential(clk, reset: reset, resetValues: {
    occupied: 0
  }, [
    If(capture, then: [storedData < upstream.data]),
    occupied < capture,
  ]);
}
