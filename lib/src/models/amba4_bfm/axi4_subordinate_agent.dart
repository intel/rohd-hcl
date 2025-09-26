// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_subordinate_agent.dart
// Agents for AXI4 in the subordinate direction.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Agent component for AR/AW channel.
class Axi4SubordinateRequestChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi4SystemInterface sIntf;

  /// AR/AW interface.
  late final Axi4RequestChannelInterface rIntf;

  /// Driver.
  late final Axi4ReadyDriver driver;

  /// Monitor.
  late final Axi4RequestChannelMonitor monitor;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Constructs a new [Axi4SubordinateRequestChannelAgent].
  Axi4SubordinateRequestChannelAgent({
    required this.sIntf,
    required this.rIntf,
    required Component parent,
    this.readyFrequency = 1.0,
    String name = 'axi4SubordinateRequestChannelAgent',
  }) : super(name, parent) {
    driver = Axi4ReadyDriver(
        parent: this,
        sIntf: sIntf,
        rIntf: rIntf,
        readyFrequency: readyFrequency);

    monitor =
        Axi4RequestChannelMonitor(sIntf: sIntf, rIntf: rIntf, parent: parent);
  }
}

/// Agent component for R/W channel.
class Axi4SubordinateDataChannelAgent extends Agent {
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

  /// Ready driver.
  late final Axi4ReadyDriver? readyDriver;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Constructs a new [Axi4SubordinateDataChannelAgent].
  Axi4SubordinateDataChannelAgent({
    required this.sIntf,
    required this.rIntf,
    required Component parent,
    String name = 'axi4SubordinateDataChannelAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
    this.readyFrequency = 1.0,
  }) : super(name, parent) {
    if (rIntf is Axi4BaseWChannelInterface) {
      readyDriver = Axi4ReadyDriver(
          parent: this,
          sIntf: sIntf,
          rIntf: rIntf,
          readyFrequency: readyFrequency);
      monitor =
          Axi4DataChannelMonitor(sIntf: sIntf, rIntf: rIntf, parent: parent);
    } else if (rIntf is Axi4BaseRChannelInterface) {
      sequencer = Sequencer<Axi4DataPacket>(
          'axi4SubordinateDataChannelSequencer', this);

      driver = Axi4DataChannelDriver(
        parent: this,
        sIntf: sIntf,
        rIntf: rIntf,
        sequencer: sequencer,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles,
      );
    }
  }
}

/// Agent component for B channel.
class Axi4SubordinateResponseChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi4SystemInterface sIntf;

  /// B interface.
  late final Axi4BaseBChannelInterface rIntf;

  /// Driver.
  late final Axi4ResponseChannelDriver driver;

  /// Sequencer.
  late final Sequencer<Axi4ResponsePacket> sequencer;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// Constructs a new [Axi4SubordinateResponseChannelAgent].
  Axi4SubordinateResponseChannelAgent({
    required this.sIntf,
    required this.rIntf,
    required Component parent,
    String name = 'axi4SubordinateResponseChannelAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    sequencer = Sequencer<Axi4ResponsePacket>(
        'axi4SubordinateResponseChannelSequencer', this);

    driver = Axi4ResponseChannelDriver(
      parent: this,
      sIntf: sIntf,
      rIntf: rIntf,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
    );
  }
}

/// Wrapper agent around the AXI read channels (AR, R).
class Axi4SubordinateReadClusterAgent extends Agent {
  /// system interface (for clocking).
  late final Axi4SystemInterface sIntf;

  /// AR interface.
  late final Axi4BaseArChannelInterface arIntf;

  /// R interface.
  late final Axi4BaseRChannelInterface rIntf;

  /// AR channel agent.
  late final Axi4SubordinateRequestChannelAgent reqAgent;

  /// R channel agent.
  late final Axi4SubordinateDataChannelAgent dataAgent;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Constructs a new [Axi4SubordinateReadClusterAgent].
  Axi4SubordinateReadClusterAgent({
    required this.sIntf,
    required this.arIntf,
    required this.rIntf,
    required Component parent,
    String name = 'axi4SubordinateReadClusterAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
    this.readyFrequency = 1.0,
  }) : super(name, parent) {
    reqAgent = Axi4SubordinateRequestChannelAgent(
        sIntf: sIntf,
        rIntf: arIntf,
        parent: parent,
        readyFrequency: readyFrequency);
    dataAgent = Axi4SubordinateDataChannelAgent(
        sIntf: sIntf,
        rIntf: rIntf,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles);
  }
}

/// Wrapper agent around the AXI write channels (AW, W, B).
class Axi4SubordinateWriteClusterAgent extends Agent {
  /// system interface (for clocking).
  late final Axi4SystemInterface sIntf;

  /// AW interface.
  late final Axi4BaseAwChannelInterface awIntf;

  /// W interface.
  late final Axi4BaseWChannelInterface wIntf;

  /// B interface.
  late final Axi4BaseBChannelInterface bIntf;

  /// AW channel agent.
  late final Axi4SubordinateRequestChannelAgent reqAgent;

  /// W channel agent.
  late final Axi4SubordinateDataChannelAgent dataAgent;

  /// B channel agent.
  late final Axi4SubordinateResponseChannelAgent respAgent;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Constructs a new [Axi4SubordinateWriteClusterAgent].
  Axi4SubordinateWriteClusterAgent({
    required this.sIntf,
    required this.awIntf,
    required this.wIntf,
    required this.bIntf,
    required Component parent,
    String name = 'axi4SubordinateWriteClusterAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
    this.readyFrequency = 1.0,
  }) : super(name, parent) {
    reqAgent = Axi4SubordinateRequestChannelAgent(
        sIntf: sIntf,
        rIntf: awIntf,
        parent: parent,
        readyFrequency: readyFrequency);
    dataAgent = Axi4SubordinateDataChannelAgent(
        sIntf: sIntf,
        rIntf: wIntf,
        parent: parent,
        readyFrequency: readyFrequency);
    respAgent = Axi4SubordinateResponseChannelAgent(
        sIntf: sIntf,
        rIntf: bIntf,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles);
  }
}

/// Wrapper agent around all AXI channels.
class Axi4SubordinateClusterAgent extends Agent {
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
  late final Axi4SubordinateReadClusterAgent readAgent;

  /// Write cluster agent.
  late final Axi4SubordinateWriteClusterAgent writeAgent;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Constructs a new [Axi4SubordinateClusterAgent].
  Axi4SubordinateClusterAgent({
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
    readAgent = Axi4SubordinateReadClusterAgent(
        sIntf: sIntf,
        arIntf: arIntf,
        rIntf: rIntf,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles,
        readyFrequency: readyFrequency);
    writeAgent = Axi4SubordinateWriteClusterAgent(
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
