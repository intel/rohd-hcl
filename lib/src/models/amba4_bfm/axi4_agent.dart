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

/// Wrapper agent around the AXI read channels (AR, R).
class Axi4ReadClusterAgent extends Agent {
  /// system interface (for clocking).
  late final Axi4SystemInterface sIntf;

  /// AR interface.
  late final Axi4BaseArChannelInterface arIntf;

  /// R interface.
  late final Axi4BaseRChannelInterface rIntf;

  /// AR channel agent.
  late final Axi4RequestChannelAgent reqAgent;

  /// R channel agent.
  late final Axi4DataChannelAgent dataAgent;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// Constructs a new [Axi4ReadClusterAgent].
  Axi4ReadClusterAgent({
    required this.sIntf,
    required this.arIntf,
    required this.rIntf,
    required Component parent,
    String name = 'axi4ReadClusterAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    reqAgent = Axi4RequestChannelAgent(
        sIntf: sIntf,
        rIntf: arIntf,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles);
    dataAgent = Axi4DataChannelAgent(
        sIntf: sIntf,
        rIntf: rIntf,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles);
  }
}

/// Wrapper agent around the AXI write channels (AW, W, B).
class Axi4WriteClusterAgent extends Agent {
  /// system interface (for clocking).
  late final Axi4SystemInterface sIntf;

  /// AW interface.
  late final Axi4BaseAwChannelInterface awIntf;

  /// W interface.
  late final Axi4BaseWChannelInterface wIntf;

  /// B interface.
  late final Axi4BaseBChannelInterface bIntf;

  /// AW channel agent.
  late final Axi4RequestChannelAgent reqAgent;

  /// W channel agent.
  late final Axi4DataChannelAgent dataAgent;

  /// B channel agent.
  late final Axi4ResponseChannelAgent respAgent;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// Constructs a new [Axi4WriteClusterAgent].
  Axi4WriteClusterAgent({
    required this.sIntf,
    required this.awIntf,
    required this.wIntf,
    required this.bIntf,
    required Component parent,
    String name = 'axi4WriteClusterAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    reqAgent = Axi4RequestChannelAgent(
        sIntf: sIntf,
        rIntf: awIntf,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles);
    dataAgent = Axi4DataChannelAgent(
        sIntf: sIntf,
        rIntf: wIntf,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles);
    respAgent = Axi4ResponseChannelAgent(
        sIntf: sIntf,
        rIntf: bIntf,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles);
  }
}

/// Wrapper agent around all AXI channels.
class Axi4ClusterAgent extends Agent {
  /// system interface (for clocking).
  late final Axi4SystemInterface sIntf;

  /// AR interface.
  late final Axi4BaseArChannelInterface arIntf;

  /// AW interface.
  late final Axi4BaseAwChannelInterface awIntf;

  /// R interface.
  late final Axi4BaseRChannelInterface rIntf;

  /// W interface.
  late final Axi4BaseWChannelInterface wIntf;

  /// B interface.
  late final Axi4BaseBChannelInterface bIntf;

  /// Read cluster agent.
  late final Axi4ReadClusterAgent readAgent;

  /// Write cluster agent.
  late final Axi4WriteClusterAgent writeAgent;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// Constructs a new [Axi4ClusterAgent].
  Axi4ClusterAgent({
    required this.sIntf,
    required this.arIntf,
    required this.awIntf,
    required this.rIntf,
    required this.wIntf,
    required this.bIntf,
    required Component parent,
    String name = 'axi4ClusterAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    readAgent = Axi4ReadClusterAgent(
        sIntf: sIntf,
        arIntf: arIntf,
        rIntf: rIntf,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles);
    writeAgent = Axi4WriteClusterAgent(
        sIntf: sIntf,
        awIntf: awIntf,
        wIntf: wIntf,
        bIntf: bIntf,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles);
  }
}
