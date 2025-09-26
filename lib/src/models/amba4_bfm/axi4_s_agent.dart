// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_s_agent.dart
// Agents for AXI4 in both directions.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Agent component for main direction.
class Axi4StreamMainAgent extends Agent {
  /// system interface (for clocking).
  late final Axi4SystemInterface sIntf;

  /// Stream interface.
  late final Axi4StreamInterface rIntf;

  /// Driver.
  late final Axi4StreamDriver driver;

  /// Sequencer.
  late final Sequencer<Axi4StreamPacket> sequencer;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// Constructs a new [Axi4StreamMainAgent].
  Axi4StreamMainAgent({
    required this.sIntf,
    required this.rIntf,
    required Component parent,
    String name = 'axi4StreamMainAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    sequencer = Sequencer<Axi4StreamPacket>('axi4StreamMainSequencer', this);
    driver = Axi4StreamDriver(
      parent: this,
      sIntf: sIntf,
      rIntf: rIntf,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
    );
  }
}

/// Agent component for subordinate direction.
class Axi4StreamSubordinateAgent extends Agent {
  /// system interface (for clocking).
  late final Axi4SystemInterface sIntf;

  /// Stream interface.
  late final Axi4StreamInterface rIntf;

  /// Ready driver.
  late final Axi4ReadyDriver readyDriver;

  /// Monitor.
  late final Axi4StreamMonitor monitor;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Constructs a new [Axi4StreamSubordinateAgent].
  Axi4StreamSubordinateAgent({
    required this.sIntf,
    required this.rIntf,
    required Component parent,
    String name = 'axi4StreamSubordinateAgent',
    this.readyFrequency = 1.0,
  }) : super(name, parent) {
    readyDriver = Axi4ReadyDriver(
        parent: this,
        sIntf: sIntf,
        rIntf: rIntf,
        readyFrequency: readyFrequency);

    monitor = Axi4StreamMonitor(sIntf: sIntf, rIntf: rIntf, parent: parent);
  }
}
