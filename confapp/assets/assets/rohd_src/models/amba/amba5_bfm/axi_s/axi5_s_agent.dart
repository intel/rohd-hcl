// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi5_s_agent.dart
// Agents for AXI5-S in both directions.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Agent component for main direction.
class Axi5StreamMainAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// Stream interface.
  late final Axi5StreamInterface stream;

  /// Driver.
  late final Axi5StreamDriver driver;

  /// Sequencer.
  late final Sequencer<Axi5StreamPacket> sequencer;

  /// The number of cycles before timing out if no transactions can be sent.
  final int? timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int? dropDelayCycles;

  /// Constructs a new [Axi5StreamMainAgent].
  Axi5StreamMainAgent({
    required this.sys,
    required this.stream,
    required Component parent,
    String name = 'axi5StreamMainAgent',
    this.timeoutCycles,
    this.dropDelayCycles,
  }) : super(name, parent) {
    sequencer = Sequencer<Axi5StreamPacket>('axi5StreamMainSequencer', this);
    driver = Axi5StreamDriver(
      parent: this,
      sys: sys,
      stream: stream,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
    );
  }
}

/// Agent component for subordinate direction.
class Axi5StreamSubordinateAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// Stream interface.
  late final Axi5StreamInterface stream;

  /// Ready driver.
  late final Axi5ReadyDriver readyDriver;

  /// Monitor.
  late final Axi5StreamMonitor monitor;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Constructs a new [Axi5StreamSubordinateAgent].
  Axi5StreamSubordinateAgent({
    required this.sys,
    required this.stream,
    required Component parent,
    String name = 'axi4StreamSubordinateAgent',
    this.readyFrequency = 1.0,
  }) : super(name, parent) {
    readyDriver = Axi5ReadyDriver(
        parent: this, sys: sys, trans: stream, readyFrequency: readyFrequency);

    monitor = Axi5StreamMonitor(sys: sys, strm: stream, parent: parent);
  }
}
