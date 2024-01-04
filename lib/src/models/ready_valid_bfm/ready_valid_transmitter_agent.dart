// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_transmitter_agent.dart
// An agent for transmitting over a ready/valid protocol.
//
// 2024 January 5
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// An [Agent] for transmitting over a ready/valid protocol.
class ReadyValidTransmitterAgent extends ReadyValidAgent {
  /// The [Sequencer] to send [ReadyValidPacket]s into.
  late final Sequencer<ReadyValidPacket> sequencer;

  /// Creates an [Agent] for transmitting over a ready/valid protocol.
  ///
  /// The [blockRate] is the probability (from 0 to 1) of blocking a valid from
  /// being driven.
  ReadyValidTransmitterAgent({
    required super.clk,
    required super.reset,
    required super.ready,
    required super.valid,
    required super.data,
    required super.parent,
    double blockRate = 0,
    super.name = 'readyValidTransmitterAgent',
  }) {
    sequencer = Sequencer<ReadyValidPacket>('sequencer', this);

    ReadyValidTransmitterDriver(
      clk: clk,
      reset: reset,
      ready: ready,
      valid: valid,
      data: data,
      sequencer: sequencer,
      blockRate: blockRate,
      parent: this,
    );
  }
}
