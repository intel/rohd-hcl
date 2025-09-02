// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_agent.dart
// Agents for AXI4.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Agent component for AR/AW channel.
class Axi4RequestChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi4SystemInterface sIntf;

  /// AR/AW interface.
  late final Axi4RequestChannelInterface rIntf;

  /// Driver.
  late final Axi4RequestChannelDriver driver;

  /// Sequencer.
  late final Sequencer<Axi4RequestPacket> sequencer;

  /// Monitor.
  late final Axi4RequestChannelMonitor monitor;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// Constructs a new [Axi4RequestChannelAgent].
  Axi4RequestChannelAgent({
    required this.sIntf,
    required this.rIntf,
    required Component parent,
    String name = 'axi4RequestChannelAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    sequencer =
        Sequencer<Axi4RequestPacket>('axi4RequestChannelSequencer', this);

    driver = Axi4RequestChannelDriver(
      parent: this,
      sIntf: sIntf,
      rIntf: rIntf,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
    );

    monitor =
        Axi4RequestChannelMonitor(sIntf: sIntf, rIntf: rIntf, parent: parent);
  }
}

/// Agent component for R/W channel.
class Axi4DataChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi4SystemInterface sIntf;

  /// R/W interface.
  late final Axi4DataChannelInterface rIntf;

  /// Driver.
  late final Axi4DataChannelDriver driver;

  /// Sequencer.
  late final Sequencer<Axi4DataPacket> sequencer;

  /// Monitor.
  late final Axi4DataChannelMonitor monitor;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// Constructs a new [Axi4DataChannelAgent].
  Axi4DataChannelAgent({
    required this.sIntf,
    required this.rIntf,
    required Component parent,
    String name = 'axi4DataChannelAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    sequencer = Sequencer<Axi4DataPacket>('axi4DataChannelSequencer', this);

    driver = Axi4DataChannelDriver(
      parent: this,
      sIntf: sIntf,
      rIntf: rIntf,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
    );

    monitor =
        Axi4DataChannelMonitor(sIntf: sIntf, rIntf: rIntf, parent: parent);
  }
}

/// Agent component for B channel.
class Axi4ResponseChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi4SystemInterface sIntf;

  /// B interface.
  late final Axi4BaseBChannelInterface rIntf;

  /// Driver.
  late final Axi4ResponseChannelDriver driver;

  /// Sequencer.
  late final Sequencer<Axi4ResponsePacket> sequencer;

  /// Monitor.
  late final Axi4ResponseChannelMonitor monitor;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// Constructs a new [Axi4ResponseChannelAgent].
  Axi4ResponseChannelAgent({
    required this.sIntf,
    required this.rIntf,
    required Component parent,
    String name = 'axi4ResponseChannelAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    sequencer =
        Sequencer<Axi4ResponsePacket>('axi4ResponseChannelSequencer', this);

    driver = Axi4ResponseChannelDriver(
      parent: this,
      sIntf: sIntf,
      rIntf: rIntf,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
    );

    monitor =
        Axi4ResponseChannelMonitor(sIntf: sIntf, rIntf: rIntf, parent: parent);
  }
}
