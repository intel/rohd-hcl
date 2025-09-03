// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_main_agent.dart
// Agents for AXI4 in the main direction.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Agent component for AR/AW channel.
class Axi4MainRequestChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi4SystemInterface sIntf;

  /// AR/AW interface.
  late final Axi4RequestChannelInterface rIntf;

  /// Driver.
  late final Axi4RequestChannelDriver driver;

  /// Sequencer.
  late final Sequencer<Axi4RequestPacket> sequencer;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// Constructs a new [Axi4MainRequestChannelAgent].
  Axi4MainRequestChannelAgent({
    required this.sIntf,
    required this.rIntf,
    required Component parent,
    String name = 'axi4MainRequestChannelAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    sequencer =
        Sequencer<Axi4RequestPacket>('axi4MainRequestChannelSequencer', this);

    driver = Axi4RequestChannelDriver(
      parent: this,
      sIntf: sIntf,
      rIntf: rIntf,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
    );
  }
}

/// Agent component for R/W channel.
class Axi4MainDataChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi4SystemInterface sIntf;

  /// R/W interface.
  late final Axi4DataChannelInterface rIntf;

  /// Driver.
  late final Axi4DataChannelDriver? driver;

  /// Sequencer.
  late final Sequencer<Axi4DataPacket>? sequencer;

  /// Monitor.
  late final Axi4DataChannelMonitor? monitor;

  /// Ready driver.
  late final Axi4ReadyDriver? readyDriver;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Constructs a new [Axi4MainDataChannelAgent].
  Axi4MainDataChannelAgent({
    required this.sIntf,
    required this.rIntf,
    required Component parent,
    String name = 'axi4MainDataChannelAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
    this.readyFrequency = 1.0,
  }) : super(name, parent) {
    if (rIntf is Axi4BaseWChannelInterface) {
      sequencer =
          Sequencer<Axi4DataPacket>('axi4MainDataChannelSequencer', this);
      driver = Axi4DataChannelDriver(
        parent: this,
        sIntf: sIntf,
        rIntf: rIntf,
        sequencer: sequencer!,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles,
      );
    } else if (rIntf is Axi4BaseRChannelInterface) {
      readyDriver = Axi4ReadyDriver(
          parent: this,
          sIntf: sIntf,
          rIntf: rIntf,
          readyFrequency: readyFrequency);
      monitor =
          Axi4DataChannelMonitor(sIntf: sIntf, rIntf: rIntf, parent: parent);
    }
  }
}

/// Agent component for B channel.
class Axi4MainResponseChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi4SystemInterface sIntf;

  /// B interface.
  late final Axi4BaseBChannelInterface rIntf;

  /// Ready driver.
  late final Axi4ReadyDriver? readyDriver;

  /// Monitor.
  late final Axi4ResponseChannelMonitor monitor;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Constructs a new [Axi4MainResponseChannelAgent].
  Axi4MainResponseChannelAgent({
    required this.sIntf,
    required this.rIntf,
    required Component parent,
    String name = 'axi4MainResponseChannelAgent',
    this.readyFrequency = 1.0,
  }) : super(name, parent) {
    readyDriver = Axi4ReadyDriver(
        parent: this,
        sIntf: sIntf,
        rIntf: rIntf,
        readyFrequency: readyFrequency);

    monitor =
        Axi4ResponseChannelMonitor(sIntf: sIntf, rIntf: rIntf, parent: parent);
  }
}

/// Wrapper agent around the AXI read channels (AR, R).
class Axi4MainReadClusterAgent extends Agent {
  /// system interface (for clocking).
  late final Axi4SystemInterface sIntf;

  /// AR interface.
  late final Axi4BaseArChannelInterface arIntf;

  /// R interface.
  late final Axi4BaseRChannelInterface rIntf;

  /// AR channel agent.
  late final Axi4MainRequestChannelAgent reqAgent;

  /// R channel agent.
  late final Axi4MainDataChannelAgent dataAgent;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Constructs a new [Axi4MainReadClusterAgent].
  Axi4MainReadClusterAgent({
    required this.sIntf,
    required this.arIntf,
    required this.rIntf,
    required Component parent,
    String name = 'axi4MainReadClusterAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
    this.readyFrequency = 1.0,
  }) : super(name, parent) {
    reqAgent = Axi4MainRequestChannelAgent(
        sIntf: sIntf,
        rIntf: arIntf,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles);
    dataAgent = Axi4MainDataChannelAgent(
        sIntf: sIntf,
        rIntf: rIntf,
        parent: parent,
        readyFrequency: readyFrequency);
  }
}

/// Wrapper agent around the AXI write channels (AW, W, B).
class Axi4MainWriteClusterAgent extends Agent {
  /// system interface (for clocking).
  late final Axi4SystemInterface sIntf;

  /// AW interface.
  late final Axi4BaseAwChannelInterface awIntf;

  /// W interface.
  late final Axi4BaseWChannelInterface wIntf;

  /// B interface.
  late final Axi4BaseBChannelInterface bIntf;

  /// AW channel agent.
  late final Axi4MainRequestChannelAgent reqAgent;

  /// W channel agent.
  late final Axi4MainDataChannelAgent dataAgent;

  /// B channel agent.
  late final Axi4MainResponseChannelAgent respAgent;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Constructs a new [Axi4MainWriteClusterAgent].
  Axi4MainWriteClusterAgent({
    required this.sIntf,
    required this.awIntf,
    required this.wIntf,
    required this.bIntf,
    required Component parent,
    String name = 'axi4MainWriteClusterAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
    this.readyFrequency = 1.0,
  }) : super(name, parent) {
    reqAgent = Axi4MainRequestChannelAgent(
        sIntf: sIntf,
        rIntf: awIntf,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles);
    dataAgent = Axi4MainDataChannelAgent(
        sIntf: sIntf,
        rIntf: wIntf,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles);
    respAgent = Axi4MainResponseChannelAgent(
        sIntf: sIntf,
        rIntf: bIntf,
        parent: parent,
        readyFrequency: readyFrequency);
  }
}

/// Wrapper agent around all AXI channels.
class Axi4MainClusterAgent extends Agent {
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
  late final Axi4MainReadClusterAgent readAgent;

  /// Write cluster agent.
  late final Axi4MainWriteClusterAgent writeAgent;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Constructs a new [Axi4MainClusterAgent].
  Axi4MainClusterAgent({
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
    this.readyFrequency = 1.0,
  }) : super(name, parent) {
    readAgent = Axi4MainReadClusterAgent(
        sIntf: sIntf,
        arIntf: arIntf,
        rIntf: rIntf,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles,
        readyFrequency: readyFrequency);
    writeAgent = Axi4MainWriteClusterAgent(
        sIntf: sIntf,
        awIntf: awIntf,
        wIntf: wIntf,
        bIntf: bIntf,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles,
        readyFrequency: readyFrequency);
  }
}
