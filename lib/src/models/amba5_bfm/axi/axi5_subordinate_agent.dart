// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi5_subordinate_agent.dart
// Agents for AXI5 in the sub direction.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Agent component for AR channel.
class Axi5SubordinateArChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// AR interface.
  late final Axi5ArChannelInterface ar;

  /// Capture the type of flow control on the interface.
  late final bool useCredit;

  /// Driver for ready-valid.
  late final Axi5ReadyDriver? readyDriver;

  // TODO: credit intf driver??

  /// Monitor.
  late final Axi5ArChannelMonitor monitor;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Constructs a new [Axi5SubordinateArChannelAgent].
  Axi5SubordinateArChannelAgent({
    required this.sys,
    required this.ar,
    required Component parent,
    String name = 'axi5SubordinateArChannelAgent',
    this.useCredit = false,
    this.readyFrequency = 1.0,
  }) : super(name, parent) {
    monitor = Axi5ArChannelMonitor(sys: sys, ar: ar, parent: parent);

    if (useCredit) {
    } else {
      readyDriver = Axi5ReadyDriver(
          parent: parent, sys: sys, trans: ar, readyFrequency: readyFrequency);
    }
  }
}

/// Agent component for R channel.
class Axi5SubordinateRChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// R interface.
  late final Axi5RChannelInterface r;

  /// Driver.
  late final Axi5RChannelDriver driver;

  /// Sequencer.
  late final Sequencer<Axi5RChannelPacket> sequencer;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// Constructs a new [Axi5SubordinateRChannelAgent].
  Axi5SubordinateRChannelAgent({
    required this.sys,
    required this.r,
    required Component parent,
    String name = 'axi5SubordinateRChannelAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    sequencer = Sequencer<Axi5RChannelPacket>(
        'axi5SubordinateRChannelAgentSequencer', this);

    driver = Axi5RChannelDriver(
      parent: this,
      sys: sys,
      r: r,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
    );
  }
}

/// Agent component for AW channel.
class Axi5SubordinateAwChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// AW interface.
  late final Axi5AwChannelInterface aw;

  /// Capture the type of flow control on the interface.
  late final bool useCredit;

  /// Driver for ready-valid.
  late final Axi5ReadyDriver? readyDriver;

  // TODO: credit intf driver??

  /// Monitor.
  late final Axi5AwChannelMonitor monitor;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Constructs a new [Axi5SubordinateAwChannelAgent].
  Axi5SubordinateAwChannelAgent({
    required this.sys,
    required this.aw,
    required Component parent,
    String name = 'axi5SubordinateAwChannelAgent',
    this.useCredit = false,
    this.readyFrequency = 1.0,
  }) : super(name, parent) {
    monitor = Axi5AwChannelMonitor(sys: sys, aw: aw, parent: parent);

    if (useCredit) {
    } else {
      readyDriver = Axi5ReadyDriver(
          parent: parent, sys: sys, trans: aw, readyFrequency: readyFrequency);
    }
  }
}

/// Agent component for W channel.
class Axi5SubordinateWChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// W interface.
  late final Axi5WChannelInterface w;

  /// Capture the type of flow control on the interface.
  late final bool useCredit;

  /// Driver for ready-valid.
  late final Axi5ReadyDriver? readyDriver;

  // TODO: credit intf driver??

  /// Monitor.
  late final Axi5WChannelMonitor monitor;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Constructs a new [Axi5SubordinateWChannelAgent].
  Axi5SubordinateWChannelAgent({
    required this.sys,
    required this.w,
    required Component parent,
    String name = 'axi5SubordinateWChannelAgent',
    this.useCredit = false,
    this.readyFrequency = 1.0,
  }) : super(name, parent) {
    monitor = Axi5WChannelMonitor(sys: sys, w: w, parent: parent);

    if (useCredit) {
    } else {
      readyDriver = Axi5ReadyDriver(
          parent: parent, sys: sys, trans: w, readyFrequency: readyFrequency);
    }
  }
}

/// Agent component for B channel.
class Axi5SubordinateBChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// B interface.
  late final Axi5BChannelInterface b;

  /// Driver.
  late final Axi5BChannelDriver driver;

  /// Sequencer.
  late final Sequencer<Axi5BChannelPacket> sequencer;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// Constructs a new [Axi5SubordinateBChannelAgent].
  Axi5SubordinateBChannelAgent({
    required this.sys,
    required this.b,
    required Component parent,
    String name = 'axi5SubordinateBChannelAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    sequencer = Sequencer<Axi5BChannelPacket>(
        'axi5SubordinateBChannelAgentSequencer', this);

    driver = Axi5BChannelDriver(
      parent: this,
      sys: sys,
      b: b,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
    );
  }
}

/// Agent component for AC channel.
class Axi5SubordinateAcChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// AC interface.
  late final Axi5AcChannelInterface ac;

  /// Driver.
  late final Axi5AcChannelDriver driver;

  /// Sequencer.
  late final Sequencer<Axi5AcChannelPacket> sequencer;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// Constructs a new [Axi5SubordinateAcChannelAgent].
  Axi5SubordinateAcChannelAgent({
    required this.sys,
    required this.ac,
    required Component parent,
    String name = 'axi5MainAcChannelAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    sequencer = Sequencer<Axi5AcChannelPacket>(
        'axi5SubordinateAcChannelAgentSequencer', this);

    driver = Axi5AcChannelDriver(
      parent: this,
      sys: sys,
      ac: ac,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
    );
  }
}

/// Agent component for CR channel.
class Axi5SubordinateCrChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// CR interface.
  late final Axi5CrChannelInterface cr;

  /// Capture the type of flow control on the interface.
  late final bool useCredit;

  /// Driver for ready-valid.
  late final Axi5ReadyDriver? readyDriver;

  // TODO: credit intf driver??

  /// Monitor.
  late final Axi5CrChannelMonitor monitor;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Constructs a new [Axi5SubordinateCrChannelAgent].
  Axi5SubordinateCrChannelAgent({
    required this.sys,
    required this.cr,
    required Component parent,
    String name = 'axi5SubordinateCrChannelAgent',
    this.useCredit = false,
    this.readyFrequency = 1.0,
  }) : super(name, parent) {
    monitor = Axi5CrChannelMonitor(sys: sys, cr: cr, parent: parent);

    if (useCredit) {
    } else {
      readyDriver = Axi5ReadyDriver(
          parent: parent, sys: sys, trans: cr, readyFrequency: readyFrequency);
    }
  }
}

/// Wrapper agent around the AXI read channels (AR, R).
class Axi5SubordinateReadClusterAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// AR interface.
  late final Axi5ArChannelInterface ar;

  /// R interface.
  late final Axi5RChannelInterface r;

  /// AR channel agent.
  late final Axi5SubordinateArChannelAgent reqAgent;

  /// R channel agent.
  late final Axi5SubordinateRChannelAgent dataAgent;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Capture the type of flow control on the interface.
  late final bool useCredit;

  /// Constructs a new [Axi4MainReadClusterAgent].
  Axi5SubordinateReadClusterAgent({
    required this.sys,
    required this.ar,
    required this.r,
    required Component parent,
    String name = 'axi5SubordinateReadClusterAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
    this.useCredit = false,
    this.readyFrequency = 1.0,
  }) : super(name, parent) {
    reqAgent = Axi5SubordinateArChannelAgent(
        sys: sys,
        ar: ar,
        parent: parent,
        readyFrequency: readyFrequency,
        useCredit: useCredit);
    dataAgent = Axi5SubordinateRChannelAgent(
        sys: sys,
        r: r,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles);
  }
}

/// Wrapper agent around the AXI write channels (AW, W, B).
class Axi5SubordinateWriteClusterAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// AW interface.
  late final Axi5AwChannelInterface aw;

  /// W interface.
  late final Axi5WChannelInterface w;

  /// B interface.
  late final Axi5BChannelInterface b;

  /// AW channel agent.
  late final Axi5SubordinateAwChannelAgent reqAgent;

  /// W channel agent.
  late final Axi5SubordinateWChannelAgent dataAgent;

  /// B channel agent.
  late final Axi5SubordinateBChannelAgent respAgent;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Capture the type of flow control on the interface.
  late final bool useCredit;

  /// Constructs a new [Axi5SubordinateWriteClusterAgent].
  Axi5SubordinateWriteClusterAgent({
    required this.sys,
    required this.aw,
    required this.w,
    required this.b,
    required Component parent,
    String name = 'axi5SubordinateWriteClusterAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
    this.readyFrequency = 1.0,
    this.useCredit = false,
  }) : super(name, parent) {
    reqAgent = Axi5SubordinateAwChannelAgent(
        sys: sys,
        aw: aw,
        parent: parent,
        readyFrequency: readyFrequency,
        useCredit: useCredit);
    dataAgent = Axi5SubordinateWChannelAgent(
        sys: sys,
        w: w,
        parent: parent,
        readyFrequency: readyFrequency,
        useCredit: useCredit);
    respAgent = Axi5SubordinateBChannelAgent(
        sys: sys,
        b: b,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles);
  }
}

/// Wrapper agent around the AXI snoop channels (AC, CR).
class Axi5SubordinateSnoopClusterAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// AC interface.
  late final Axi5AcChannelInterface ac;

  /// CR interface.
  late final Axi5CrChannelInterface cr;

  /// AC channel agent.
  late final Axi5SubordinateAcChannelAgent reqAgent;

  /// CR channel agent.
  late final Axi5SubordinateCrChannelAgent respAgent;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Capture the type of flow control on the interface.
  late final bool useCredit;

  /// Constructs a new [Axi5SubordinateSnoopClusterAgent].
  Axi5SubordinateSnoopClusterAgent({
    required this.sys,
    required this.ac,
    required this.cr,
    required Component parent,
    String name = 'axi5SubordinateSnoopClusterAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
    this.readyFrequency = 1.0,
    this.useCredit = false,
  }) : super(name, parent) {
    reqAgent = Axi5SubordinateAcChannelAgent(
      sys: sys,
      ac: ac,
      parent: parent,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
    );
    respAgent = Axi5SubordinateCrChannelAgent(
        sys: sys,
        cr: cr,
        parent: parent,
        readyFrequency: readyFrequency,
        useCredit: useCredit);
  }
}

/// Axi agent for the full set of channels.
class Axi5SubordinateClusterAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// AR interface.
  late final Axi5ArChannelInterface ar;

  /// R interface.
  late final Axi5RChannelInterface r;

  /// AW interface.
  late final Axi5AwChannelInterface aw;

  /// W interface.
  late final Axi5WChannelInterface w;

  /// B interface.
  late final Axi5BChannelInterface b;

  /// AC interface.
  late final Axi5AcChannelInterface? ac;

  /// CR interface.
  late final Axi5CrChannelInterface? cr;

  /// Read agent.
  late final Axi5SubordinateReadClusterAgent read;

  /// Write agent.
  late final Axi5SubordinateWriteClusterAgent write;

  /// Snoop agent.
  late final Axi5SubordinateSnoopClusterAgent? snoop;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Capture the type of flow control on the interface.
  late final bool useCredit;

  /// Constructs a new [Axi5SubordinateClusterAgent].
  Axi5SubordinateClusterAgent({
    required this.sys,
    required this.ar,
    required this.aw,
    required this.r,
    required this.w,
    required this.b,
    required Component parent,
    this.ac,
    this.cr,
    String name = 'axi5SubordinateClusterAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
    this.readyFrequency = 1.0,
    this.useCredit = false,
    bool useSnoop = false,
  }) : super(name, parent) {
    read = Axi5SubordinateReadClusterAgent(
        sys: sys,
        ar: ar,
        r: r,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles,
        readyFrequency: readyFrequency,
        useCredit: useCredit);

    write = Axi5SubordinateWriteClusterAgent(
        sys: sys,
        aw: aw,
        w: w,
        b: b,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles,
        readyFrequency: readyFrequency,
        useCredit: useCredit);

    if (useSnoop) {
      snoop = Axi5SubordinateSnoopClusterAgent(
          sys: sys,
          ac: ac!,
          cr: cr!,
          parent: parent,
          timeoutCycles: timeoutCycles,
          dropDelayCycles: dropDelayCycles,
          readyFrequency: readyFrequency,
          useCredit: useCredit);
    }
  }
}
