// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// dti_utils.dart
// Utility functionality for DTI HW and messages.
//
// 2025 December
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';

/// Capture the connection state.
enum DtiConnectionState {
  /// Unconnected to ATU
  unconnected,

  /// Sent connection request, waiting for ack
  pendingConn,

  /// Connected to ATU
  connected,

  /// Sent disconnection request, waiting for ack
  pendingDisconn,
}

/// State of sending beats on the AXI-S interface.
enum DtiStreamBeatState {
  /// Not currently sending anything.
  idle,

  /// Currently sending beats.
  working,
}

/// Convert a virtual channel to a credit return value
LogicValue toOneHot(int index, int width) {
  final ohLit = List<int>.filled(width, 0);
  ohLit[index] = 1;
  return ohLit
      .map((e) => e == 1 ? LogicValue.one : LogicValue.zero)
      .toList()
      .rswizzle();
}
