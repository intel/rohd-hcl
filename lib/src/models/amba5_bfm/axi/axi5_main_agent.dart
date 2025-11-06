// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi5_main_agent.dart
// Agents for AXI5 in the main direction.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Agent component for AR channel.
class Axi5MainArChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// AR interface.
  late final Axi5ArChannelInterface ar;

  /// Driver.
  late final Axi5ArChannelDriver driver;

  /// Sequencer.
  late final Sequencer<Axi5ArChannelPacket> sequencer;

  /// The number of cycles before timing out if no transactions can be sent.
  final int? timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int? dropDelayCycles;

  /// Constructs a new [Axi5MainArChannelAgent].
  Axi5MainArChannelAgent({
    required this.sys,
    required this.ar,
    required Component parent,
    String name = 'axi5MainArChannelAgent',
    this.timeoutCycles,
    this.dropDelayCycles,
  }) : super(name, parent) {
    sequencer =
        Sequencer<Axi5ArChannelPacket>('axi5MainArChannelAgentSequencer', this);

    driver = Axi5ArChannelDriver(
      parent: this,
      sys: sys,
      ar: ar,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
    );
  }
}

/// Agent component for R channel.
class Axi5MainRChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// R interface.
  late final Axi5RChannelInterface r;

  /// Capture the type of flow control on the interface.
  late final bool useCredit;

  /// Driver for ready-valid.
  late final Axi5ReadyDriver? readyDriver;

  // TODO: credit intf driver??

  /// Monitor.
  late final Axi5RChannelMonitor monitor;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Constructs a new [Axi5MainRChannelAgent].
  Axi5MainRChannelAgent({
    required this.sys,
    required this.r,
    required Component parent,
    String name = 'axi5MainRChannelAgent',
    this.useCredit = false,
    this.readyFrequency = 1.0,
  }) : super(name, parent) {
    monitor = Axi5RChannelMonitor(sys: sys, r: r, parent: parent);

    if (useCredit) {
    } else {
      readyDriver = Axi5ReadyDriver(
          parent: parent, sys: sys, trans: r, readyFrequency: readyFrequency);
    }
  }
}

/// Agent component for AW channel.
class Axi5MainAwChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// AW interface.
  late final Axi5AwChannelInterface aw;

  /// Driver.
  late final Axi5AwChannelDriver driver;

  /// Sequencer.
  late final Sequencer<Axi5AwChannelPacket> sequencer;

  /// The number of cycles before timing out if no transactions can be sent.
  final int? timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int? dropDelayCycles;

  /// Constructs a new [Axi5MainAwChannelAgent].
  Axi5MainAwChannelAgent({
    required this.sys,
    required this.aw,
    required Component parent,
    String name = 'axi5MainAwChannelAgent',
    this.timeoutCycles,
    this.dropDelayCycles,
  }) : super(name, parent) {
    sequencer =
        Sequencer<Axi5AwChannelPacket>('axi5MainAwChannelAgentSequencer', this);

    driver = Axi5AwChannelDriver(
      parent: this,
      sys: sys,
      aw: aw,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
    );
  }
}

/// Agent component for W channel.
class Axi5MainWChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// W interface.
  late final Axi5WChannelInterface w;

  /// Driver.
  late final Axi5WChannelDriver driver;

  /// Sequencer.
  late final Sequencer<Axi5WChannelPacket> sequencer;

  /// The number of cycles before timing out if no transactions can be sent.
  final int? timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int? dropDelayCycles;

  /// Constructs a new [Axi5MainWChannelAgent].
  Axi5MainWChannelAgent({
    required this.sys,
    required this.w,
    required Component parent,
    String name = 'axi5MainWChannelAgent',
    this.timeoutCycles,
    this.dropDelayCycles,
  }) : super(name, parent) {
    sequencer =
        Sequencer<Axi5WChannelPacket>('axi5MainWChannelAgentSequencer', this);

    driver = Axi5WChannelDriver(
      parent: this,
      sys: sys,
      w: w,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
    );
  }
}

/// Agent component for B channel.
class Axi5MainBChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// B interface.
  late final Axi5BChannelInterface b;

  /// Capture the type of flow control on the interface.
  late final bool useCredit;

  /// Driver for ready-valid.
  late final Axi5ReadyDriver? readyDriver;

  // TODO: credit intf driver??

  /// Monitor.
  late final Axi5BChannelMonitor monitor;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Constructs a new [Axi5MainBChannelAgent].
  Axi5MainBChannelAgent({
    required this.sys,
    required this.b,
    required Component parent,
    String name = 'axi5MainBChannelAgent',
    this.useCredit = false,
    this.readyFrequency = 1.0,
  }) : super(name, parent) {
    monitor = Axi5BChannelMonitor(sys: sys, b: b, parent: parent);

    if (useCredit) {
    } else {
      readyDriver = Axi5ReadyDriver(
          parent: parent, sys: sys, trans: b, readyFrequency: readyFrequency);
    }
  }
}

/// Agent component for AC channel.
class Axi5MainAcChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// AC interface.
  late final Axi5AcChannelInterface ac;

  /// Capture the type of flow control on the interface.
  late final bool useCredit;

  /// Driver for ready-valid.
  late final Axi5ReadyDriver? readyDriver;

  // TODO: credit intf driver??

  /// Monitor.
  late final Axi5AcChannelMonitor monitor;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Constructs a new [Axi5MainAcChannelAgent].
  Axi5MainAcChannelAgent({
    required this.sys,
    required this.ac,
    required Component parent,
    String name = 'axi5MainAcChannelAgent',
    this.useCredit = false,
    this.readyFrequency = 1.0,
  }) : super(name, parent) {
    monitor = Axi5AcChannelMonitor(sys: sys, ac: ac, parent: parent);

    if (useCredit) {
    } else {
      readyDriver = Axi5ReadyDriver(
          parent: parent, sys: sys, trans: ac, readyFrequency: readyFrequency);
    }
  }
}

/// Agent component for CR channel.
class Axi5MainCrChannelAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// CR interface.
  late final Axi5CrChannelInterface cr;

  /// Driver.
  late final Axi5CrChannelDriver driver;

  /// Sequencer.
  late final Sequencer<Axi5CrChannelPacket> sequencer;

  /// The number of cycles before timing out if no transactions can be sent.
  final int? timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int? dropDelayCycles;

  /// Constructs a new [Axi5MainCrChannelAgent].
  Axi5MainCrChannelAgent({
    required this.sys,
    required this.cr,
    required Component parent,
    String name = 'axi5MainCrChannelAgent',
    this.timeoutCycles,
    this.dropDelayCycles,
  }) : super(name, parent) {
    sequencer =
        Sequencer<Axi5CrChannelPacket>('axi5MainCrChannelAgentSequencer', this);

    driver = Axi5CrChannelDriver(
      parent: this,
      sys: sys,
      cr: cr,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
    );
  }
}

/// Wrapper agent around the AXI read channels (AR, R).
class Axi5MainReadClusterAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// AR interface.
  late final Axi5ArChannelInterface ar;

  /// R interface.
  late final Axi5RChannelInterface r;

  /// AR channel agent.
  late final Axi5MainArChannelAgent reqAgent;

  /// R channel agent.
  late final Axi5MainRChannelAgent dataAgent;

  /// The number of cycles before timing out if no transactions can be sent.
  final int? timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int? dropDelayCycles;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Capture the type of flow control on the interface.
  late final bool useCredit;

  /// Constructs a new [Axi4MainReadClusterAgent].
  Axi5MainReadClusterAgent({
    required this.sys,
    required this.ar,
    required this.r,
    required Component parent,
    String name = 'axi5MainReadClusterAgent',
    this.timeoutCycles,
    this.dropDelayCycles,
    this.readyFrequency = 1.0,
    this.useCredit = false,
  }) : super(name, parent) {
    reqAgent = Axi5MainArChannelAgent(
        sys: sys,
        ar: ar,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles);
    dataAgent = Axi5MainRChannelAgent(
        sys: sys,
        r: r,
        parent: parent,
        readyFrequency: readyFrequency,
        useCredit: useCredit);
  }
}

/// Wrapper agent around the AXI write channels (AW, W, B).
class Axi5MainWriteClusterAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// AW interface.
  late final Axi5AwChannelInterface aw;

  /// W interface.
  late final Axi5WChannelInterface w;

  /// B interface.
  late final Axi5BChannelInterface b;

  /// AW channel agent.
  late final Axi5MainAwChannelAgent reqAgent;

  /// W channel agent.
  late final Axi5MainWChannelAgent dataAgent;

  /// B channel agent.
  late final Axi5MainBChannelAgent respAgent;

  /// The number of cycles before timing out if no transactions can be sent.
  final int? timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int? dropDelayCycles;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Capture the type of flow control on the interface.
  late final bool useCredit;

  /// Constructs a new [Axi5MainWriteClusterAgent].
  Axi5MainWriteClusterAgent({
    required this.sys,
    required this.aw,
    required this.w,
    required this.b,
    required Component parent,
    String name = 'axi5MainWriteClusterAgent',
    this.timeoutCycles,
    this.dropDelayCycles,
    this.readyFrequency = 1.0,
    this.useCredit = false,
  }) : super(name, parent) {
    reqAgent = Axi5MainAwChannelAgent(
        sys: sys,
        aw: aw,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles);
    dataAgent = Axi5MainWChannelAgent(
        sys: sys,
        w: w,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles);
    respAgent = Axi5MainBChannelAgent(
        sys: sys,
        b: b,
        parent: parent,
        readyFrequency: readyFrequency,
        useCredit: useCredit);
  }
}

/// Wrapper agent around the AXI snoop channels (AC, CR).
class Axi5MainSnoopClusterAgent extends Agent {
  /// system interface (for clocking).
  late final Axi5SystemInterface sys;

  /// AC interface.
  late final Axi5AcChannelInterface ac;

  /// CR interface.
  late final Axi5CrChannelInterface cr;

  /// AC channel agent.
  late final Axi5MainAcChannelAgent reqAgent;

  /// CR channel agent.
  late final Axi5MainCrChannelAgent respAgent;

  /// The number of cycles before timing out if no transactions can be sent.
  final int? timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int? dropDelayCycles;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Capture the type of flow control on the interface.
  late final bool useCredit;

  /// Constructs a new [Axi5MainSnoopClusterAgent].
  Axi5MainSnoopClusterAgent({
    required this.sys,
    required this.ac,
    required this.cr,
    required Component parent,
    String name = 'axi5MainSnoopClusterAgent',
    this.timeoutCycles,
    this.dropDelayCycles,
    this.readyFrequency = 1.0,
    this.useCredit = false,
  }) : super(name, parent) {
    reqAgent = Axi5MainAcChannelAgent(
        sys: sys,
        ac: ac,
        parent: parent,
        readyFrequency: readyFrequency,
        useCredit: useCredit);
    respAgent = Axi5MainCrChannelAgent(
        sys: sys,
        cr: cr,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles);
  }
}

/// Axi agent for the full set of channels.
class Axi5MainClusterAgent extends Agent {
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
  late final Axi5MainReadClusterAgent read;

  /// Write agent.
  late final Axi5MainWriteClusterAgent write;

  /// Snoop agent.
  late final Axi5MainSnoopClusterAgent? snoop;

  /// The number of cycles before timing out if no transactions can be sent.
  final int? timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int? dropDelayCycles;

  /// the frequency with which the ready signal should be driven.
  final num readyFrequency;

  /// Capture the type of flow control on the interface.
  late final bool useCredit;

  /// Constructs a new [Axi5MainClusterAgent].
  Axi5MainClusterAgent({
    required this.sys,
    required this.ar,
    required this.aw,
    required this.r,
    required this.w,
    required this.b,
    required Component parent,
    this.ac,
    this.cr,
    String name = 'axi5MainClusterAgent',
    this.timeoutCycles,
    this.dropDelayCycles,
    this.readyFrequency = 1.0,
    this.useCredit = false,
    bool useSnoop = false,
  }) : super(name, parent) {
    read = Axi5MainReadClusterAgent(
        sys: sys,
        ar: ar,
        r: r,
        parent: parent,
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles,
        readyFrequency: readyFrequency,
        useCredit: useCredit);

    write = Axi5MainWriteClusterAgent(
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
      snoop = Axi5MainSnoopClusterAgent(
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
