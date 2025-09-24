// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// lit_agent.dart
// Agents for LTI in both directions.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Agent component for LA channel.
class LtiMainLaChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// LA interface.
  late final LtiLaChannelInterface la;

  /// Driver.
  late final LtiLaChannelDriver driver;

  /// Sequencer.
  late final Sequencer<LtiLaChannelPacket> sequencer;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// Constructs a new [LtiMainLaChannelAgent].
  LtiMainLaChannelAgent({
    required this.sys,
    required this.la,
    required Component parent,
    String name = 'ltiMainLaChannelAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    sequencer =
        Sequencer<LtiLaChannelPacket>('ltiMainLaChannelAgentSequencer', this);

    driver = LtiLaChannelDriver(
      parent: this,
      sys: sys,
      la: la,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
    );
  }
}

/// Agent component for LR channel.
class LtiMainLrChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// LR interface.
  late final LtiLrChannelInterface lr;

  /// Driver.
  late final LtiCreditDriver driver;

  /// Sequencer.
  late final Sequencer<LtiCreditPacket> sequencer;

  /// Monitor.
  late final LtiLrChannelMonitor monitor;

  /// Constructs a new [LtiMainLrChannelAgent].
  LtiMainLrChannelAgent({
    required this.sys,
    required this.lr,
    required Component parent,
    String name = 'ltiMainLrChannelAgent',
  }) : super(name, parent) {
    monitor = LtiLrChannelMonitor(sys: sys, lr: lr, parent: parent);

    sequencer =
        Sequencer<LtiCreditPacket>('ltiMainLrChannelAgentSequencer', this);

    driver = LtiCreditDriver(
      parent: this,
      sys: sys,
      trans: lr,
      sequencer: sequencer,
    );
  }
}

/// Agent component for LC channel.
class LtiMainLcChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// LC interface.
  late final LtiLcChannelInterface lc;

  /// Driver.
  late final LtiLcChannelDriver driver;

  /// Sequencer.
  late final Sequencer<LtiLcChannelPacket> sequencer;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// Constructs a new [LtiMainLcChannelAgent].
  LtiMainLcChannelAgent({
    required this.sys,
    required this.lc,
    required Component parent,
    String name = 'ltiMainLcChannelAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    sequencer =
        Sequencer<LtiLcChannelPacket>('ltiMainLcChannelAgentSequencer', this);

    driver = LtiLcChannelDriver(
      parent: this,
      sys: sys,
      lc: lc,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
    );
  }
}

/// Agent component for LR channel.
class LtiMainLtChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// LT interface.
  late final LtiLtChannelInterface lt;

  /// Driver.
  late final LtiCreditDriver driver;

  /// Sequencer.
  late final Sequencer<LtiCreditPacket> sequencer;

  /// Monitor.
  late final LtiLtChannelMonitor monitor;

  /// Constructs a new [LtiMainLtChannelAgent].
  LtiMainLtChannelAgent({
    required this.sys,
    required this.lt,
    required Component parent,
    String name = 'ltiMainLtChannelAgent',
  }) : super(name, parent) {
    monitor = LtiLtChannelMonitor(sys: sys, lt: lt, parent: parent);

    sequencer =
        Sequencer<LtiCreditPacket>('ltiMainLtChannelAgentSequencer', this);

    driver = LtiCreditDriver(
      parent: this,
      sys: sys,
      trans: lt,
      sequencer: sequencer,
    );
  }
}

/// Wrapper agent around the LTI channels.
class LtiMainClusterAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// LA interface.
  late final LtiLaChannelInterface la;

  /// LR interface.
  late final LtiLrChannelInterface lr;

  /// LC interface.
  late final LtiLcChannelInterface lc;

  /// LT interface.
  late final LtiLtChannelInterface? lt;

  /// LA channel agent.
  late final LtiMainLaChannelAgent reqAgent;

  /// LR channel agent.
  late final LtiMainLrChannelAgent respAgent;

  /// LC channel agent.
  late final LtiMainLcChannelAgent compAgent;

  /// LT channel agent.
  late final LtiMainLtChannelAgent? tagAgent;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// Constructs a new [LtiMainClusterAgent].
  LtiMainClusterAgent({
    required this.sys,
    required this.la,
    required this.lr,
    required this.lc,
    required Component parent,
    this.lt,
    String name = 'ltiMainClusterAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    reqAgent = LtiMainLaChannelAgent(
        sys: sys,
        la: la,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles);
    respAgent = LtiMainLrChannelAgent(sys: sys, lr: lr, parent: parent);
    compAgent = LtiMainLcChannelAgent(
        sys: sys,
        lc: lc,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles);
    if (lt != null) {
      tagAgent = LtiMainLtChannelAgent(sys: sys, lt: lt!, parent: parent);
    }
  }
}

/// Agent component for LA channel.
class LtiSubordinateLaChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// LA interface.
  late final LtiLaChannelInterface la;

  /// Driver.
  late final LtiCreditDriver driver;

  /// Sequencer.
  late final Sequencer<LtiCreditPacket> sequencer;

  /// Monitor.
  late final LtiLaChannelMonitor monitor;

  /// Constructs a new [LtiSubordinateLaChannelAgent].
  LtiSubordinateLaChannelAgent({
    required this.sys,
    required this.la,
    required Component parent,
    String name = 'ltiSubordinateLaChannelAgent',
  }) : super(name, parent) {
    monitor = LtiLaChannelMonitor(sys: sys, la: la, parent: parent);

    sequencer = Sequencer<LtiCreditPacket>(
        'ltiSubordinateLaChannelAgentSequencer', this);

    driver = LtiCreditDriver(
      parent: this,
      sys: sys,
      trans: la,
      sequencer: sequencer,
    );
  }
}

/// Agent component for LR channel.
class LtiSubordinateLrChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// LR interface.
  late final LtiLrChannelInterface lr;

  /// Driver.
  late final LtiLrChannelDriver driver;

  /// Sequencer.
  late final Sequencer<LtiLrChannelPacket> sequencer;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// Constructs a new [LtiSubordinateLrChannelAgent].
  LtiSubordinateLrChannelAgent({
    required this.sys,
    required this.lr,
    required Component parent,
    String name = 'ltiSubordinateLrChannelAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    sequencer = Sequencer<LtiLrChannelPacket>(
        'ltiSubordinateLrChannelAgentSequencer', this);

    driver = LtiLrChannelDriver(
      parent: this,
      sys: sys,
      lr: lr,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
    );
  }
}

/// Agent component for LC channel.
class LtiSubordinateLcChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// LC interface.
  late final LtiLcChannelInterface lc;

  /// Driver.
  late final LtiCreditDriver driver;

  /// Sequencer.
  late final Sequencer<LtiCreditPacket> sequencer;

  /// Monitor.
  late final LtiLcChannelMonitor monitor;

  /// Constructs a new [LtiSubordinateLcChannelAgent].
  LtiSubordinateLcChannelAgent({
    required this.sys,
    required this.lc,
    required Component parent,
    String name = 'ltiSubordinateLcChannelAgent',
  }) : super(name, parent) {
    monitor = LtiLcChannelMonitor(sys: sys, lc: lc, parent: parent);

    sequencer = Sequencer<LtiCreditPacket>(
        'ltiSubordinateLcChannelAgentSequencer', this);

    driver = LtiCreditDriver(
      parent: this,
      sys: sys,
      trans: lc,
      sequencer: sequencer,
    );
  }
}

/// Agent component for LT channel.
class LtiSubordinateLtChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// LT interface.
  late final LtiLtChannelInterface lt;

  /// Driver.
  late final LtiLtChannelDriver driver;

  /// Sequencer.
  late final Sequencer<LtiLtChannelPacket> sequencer;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// Constructs a new [LtiSubordinateLtChannelAgent].
  LtiSubordinateLtChannelAgent({
    required this.sys,
    required this.lt,
    required Component parent,
    String name = 'ltiSubordinateLtChannelAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    sequencer = Sequencer<LtiLtChannelPacket>(
        'ltiSubordinateLtChannelAgentSequencer', this);

    driver = LtiLtChannelDriver(
      parent: this,
      sys: sys,
      lt: lt,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
    );
  }
}

/// Wrapper agent around the LTI channels.
class LtiSubordinateClusterAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// LA interface.
  late final LtiLaChannelInterface la;

  /// LR interface.
  late final LtiLrChannelInterface lr;

  /// LC interface.
  late final LtiLcChannelInterface lc;

  /// LT interface.
  late final LtiLtChannelInterface? lt;

  /// LA channel agent.
  late final LtiSubordinateLaChannelAgent reqAgent;

  /// LR channel agent.
  late final LtiSubordinateLrChannelAgent respAgent;

  /// LC channel agent.
  late final LtiSubordinateLcChannelAgent compAgent;

  /// LT channel agent.
  late final LtiSubordinateLtChannelAgent? tagAgent;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// Constructs a new [LtiSubordinateClusterAgent].
  LtiSubordinateClusterAgent({
    required this.sys,
    required this.la,
    required this.lr,
    required this.lc,
    required Component parent,
    this.lt,
    String name = 'ltiSubordinateClusterAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    reqAgent = LtiSubordinateLaChannelAgent(
      sys: sys,
      la: la,
      parent: parent,
    );
    respAgent = LtiSubordinateLrChannelAgent(
        sys: sys,
        lr: lr,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles);
    compAgent = LtiSubordinateLcChannelAgent(
      sys: sys,
      lc: lc,
      parent: parent,
    );
    if (lt != null) {
      tagAgent = LtiSubordinateLtChannelAgent(
          sys: sys,
          lt: lt!,
          parent: parent,
          timeoutCycles: timeoutCycles,
          dropDelayCycles: dropDelayCycles);
    }
  }
}
