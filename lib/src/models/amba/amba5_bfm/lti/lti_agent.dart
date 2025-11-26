// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// lit_agent.dart
// Agents for LTI in both directions.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
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

  /// Monitor.
  late final LtiCreditMonitor monitor;

  /// The number of cycles before timing out if no transactions can be sent.
  final int? timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int? dropDelayCycles;

  // Internal mechanism to deal with crediting.
  final List<int> _creditCounts = [];

  /// Constructs a new [LtiMainLaChannelAgent].
  LtiMainLaChannelAgent({
    required this.sys,
    required this.la,
    required Component parent,
    String name = 'ltiMainLaChannelAgent',
    this.timeoutCycles,
    this.dropDelayCycles,
  }) : super(name, parent) {
    // credit tracking per virtual channel
    for (var i = 0; i < la.vcCount; i++) {
      _creditCounts.add(0);
    }

    sequencer =
        Sequencer<LtiLaChannelPacket>('ltiMainLaChannelAgentSequencer', this);

    driver = LtiLaChannelDriver(
      parent: this,
      sys: sys,
      la: la,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
      hasCredits: (vc) => _creditCounts[vc] > 0,
      updateCredits: (vc) => _creditCounts[vc]--,
    );

    monitor = LtiCreditMonitor(sys: sys, trans: la, parent: this);

    // credit returns
    monitor.stream.listen((c) {
      final lv = LogicValue.ofInt(c.credit, la.vcCount);
      for (var i = 0; i < lv.width; i++) {
        if (lv[i].toBool()) {
          _creditCounts[i]++;
        }
      }
    });
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

  /// Monitor.
  late final LtiCreditMonitor monitor;

  /// The number of cycles before timing out if no transactions can be sent.
  final int? timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int? dropDelayCycles;

  // Internal mechanism to deal with crediting.
  final List<int> _creditCounts = [];

  /// Constructs a new [LtiMainLcChannelAgent].
  LtiMainLcChannelAgent({
    required this.sys,
    required this.lc,
    required Component parent,
    String name = 'ltiMainLcChannelAgent',
    this.timeoutCycles,
    this.dropDelayCycles,
  }) : super(name, parent) {
    // credit tracking per virtual channel
    for (var i = 0; i < lc.vcCount; i++) {
      _creditCounts.add(0);
    }

    sequencer =
        Sequencer<LtiLcChannelPacket>('ltiMainLcChannelAgentSequencer', this);

    driver = LtiLcChannelDriver(
      parent: this,
      sys: sys,
      lc: lc,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
      hasCredits: () => _creditCounts[0] > 0, // only 1 VC
      updateCredits: () => _creditCounts[0]--,
    );

    monitor = LtiCreditMonitor(sys: sys, trans: lc, parent: this);

    // credit returns
    monitor.stream.listen((c) {
      // only 1 VC
      if (c.credit > 0) {
        _creditCounts[0]++;
      }
    });
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

  /// Management interface.
  late final LtiManagementInterface lm;

  /// LA channel agent.
  late final LtiMainLaChannelAgent reqAgent;

  /// LR channel agent.
  late final LtiMainLrChannelAgent respAgent;

  /// LC channel agent.
  late final LtiMainLcChannelAgent compAgent;

  /// LT channel agent.
  late final LtiMainLtChannelAgent? tagAgent;

  /// Management driver.
  late final LtiManagementMainDriver manDriver;

  /// The number of cycles before timing out if no transactions can be sent.
  final int? timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int? dropDelayCycles;

  /// Constructs a new [LtiMainClusterAgent].
  LtiMainClusterAgent({
    required this.sys,
    required this.la,
    required this.lr,
    required this.lc,
    required this.lm,
    required Component parent,
    this.lt,
    String name = 'ltiMainClusterAgent',
    this.timeoutCycles,
    this.dropDelayCycles,
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
    } else {
      tagAgent = null;
    }
    manDriver = LtiManagementMainDriver(sys: sys, lm: lm, parent: parent);
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

  /// Monitor.
  late final LtiCreditMonitor monitor;

  /// The number of cycles before timing out if no transactions can be sent.
  final int? timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int? dropDelayCycles;

  // Internal mechanism to deal with crediting.
  final List<int> _creditCounts = [];

  /// Constructs a new [LtiSubordinateLrChannelAgent].
  LtiSubordinateLrChannelAgent({
    required this.sys,
    required this.lr,
    required Component parent,
    String name = 'ltiSubordinateLrChannelAgent',
    this.timeoutCycles,
    this.dropDelayCycles,
  }) : super(name, parent) {
    // credit tracking per virtual channel
    for (var i = 0; i < lr.vcCount; i++) {
      _creditCounts.add(0);
    }

    sequencer = Sequencer<LtiLrChannelPacket>(
        'ltiSubordinateLrChannelAgentSequencer', this);

    driver = LtiLrChannelDriver(
      parent: this,
      sys: sys,
      lr: lr,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
      hasCredits: (vc) => _creditCounts[vc] > 0,
      updateCredits: (vc) => _creditCounts[vc]--,
    );

    monitor = LtiCreditMonitor(sys: sys, trans: lr, parent: this);

    // credit returns
    monitor.stream.listen((c) {
      final lv = LogicValue.ofInt(c.credit, lr.vcCount);
      for (var i = 0; i < lv.width; i++) {
        if (lv[i].toBool()) {
          _creditCounts[i]++;
        }
      }
    });
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

  /// Monitor.
  late final LtiCreditMonitor monitor;

  /// The number of cycles before timing out if no transactions can be sent.
  final int? timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int? dropDelayCycles;

  // Internal mechanism to deal with crediting.
  final List<int> _creditCounts = [];

  /// Constructs a new [LtiSubordinateLtChannelAgent].
  LtiSubordinateLtChannelAgent({
    required this.sys,
    required this.lt,
    required Component parent,
    String name = 'ltiSubordinateLtChannelAgent',
    this.timeoutCycles,
    this.dropDelayCycles,
  }) : super(name, parent) {
    // credit tracking per virtual channel
    for (var i = 0; i < lt.vcCount; i++) {
      _creditCounts.add(0);
    }

    sequencer = Sequencer<LtiLtChannelPacket>(
        'ltiSubordinateLtChannelAgentSequencer', this);

    driver = LtiLtChannelDriver(
      parent: this,
      sys: sys,
      lt: lt,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
      hasCredits: () => _creditCounts[0] > 0, // only 1 VC
      updateCredits: () => _creditCounts[0]--,
    );

    monitor = LtiCreditMonitor(sys: sys, trans: lt, parent: this);

    // credit returns
    monitor.stream.listen((c) {
      // only 1 VC
      if (c.credit > 0) {
        _creditCounts[0]++;
      }
    });
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

  /// Management interface.
  late final LtiManagementInterface lm;

  /// LA channel agent.
  late final LtiSubordinateLaChannelAgent reqAgent;

  /// LR channel agent.
  late final LtiSubordinateLrChannelAgent respAgent;

  /// LC channel agent.
  late final LtiSubordinateLcChannelAgent compAgent;

  /// LT channel agent.
  late final LtiSubordinateLtChannelAgent? tagAgent;

  /// Management driver.
  late final LtiManagementSubDriver manDriver;

  /// The number of cycles before timing out if no transactions can be sent.
  final int? timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int? dropDelayCycles;

  /// Constructs a new [LtiSubordinateClusterAgent].
  LtiSubordinateClusterAgent({
    required this.sys,
    required this.la,
    required this.lr,
    required this.lc,
    required this.lm,
    required Component parent,
    this.lt,
    String name = 'ltiSubordinateClusterAgent',
    this.timeoutCycles,
    this.dropDelayCycles,
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
    } else {
      tagAgent = null;
    }
    manDriver = LtiManagementSubDriver(sys: sys, lm: lm, parent: parent);
  }
}
