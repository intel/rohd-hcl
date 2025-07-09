// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_main.dart
// An agent sending for AXI4 requests.
//
// 2025 January
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// An AXI4 channel that may or may not support reads and/or writes.
class Axi4Channel {
  /// A unique identifier for the given channel.
  ///
  /// This is a pure SW construct and is not used in the RTL.
  final int channelId;

  /// Does this channel support read transactions.
  ///
  /// If `false`, the [rIntf] field should be null.
  final bool hasRead;

  /// Does this channel support write transactions.
  ///
  /// If `false`, the [wIntf] field should be null.
  final bool hasWrite;

  /// Read interface.
  final Axi4ReadInterface? rIntf;

  /// Write interface.
  final Axi4WriteInterface? wIntf;

  /// Constructor.
  Axi4Channel({
    this.channelId = 0,
    this.rIntf,
    this.wIntf,
  })  : hasRead = rIntf != null,
        hasWrite = wIntf != null {
    if (rIntf == null && wIntf == null) {
      throw RohdHclException('A channel must support either'
          ' reads or writes (or both)');
    }
  }
}

/// An agent for sending and monitoring read requests
///
/// Driven read packets will update the returned data into the same packet.
class Axi4ReadAgent extends Agent {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// Channel that the agent can send requests on.
  final Axi4Channel channel;

  /// The sequencer where read requests should be sent.
  late final Sequencer<Axi4ReadRequestPacket> sequencer;

  /// The driver that sends read requests over the interface.
  late final Axi4ReadMainDriver driver;

  /// Monitoring of read requests over the interface.
  late final Axi4ReadMonitor monitor;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// Constructs a new [Axi4ReadAgent].
  Axi4ReadAgent({
    required this.sIntf,
    required this.channel,
    required Component parent,
    String name = 'axiReadAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    if (!channel.hasRead) {
      throw RohdHclException('A read agent must be associated with a channel '
          'that can send read requests.');
    }

    sequencer =
        Sequencer<Axi4ReadRequestPacket>('${name}_axiRdSequencer', this);
    driver = Axi4ReadMainDriver(
      parent: this,
      sIntf: sIntf,
      rIntf: channel.rIntf!,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
      name: '${name}_axiRdDriver',
    );
    monitor = Axi4ReadMonitor(
        sIntf: sIntf,
        rIntf: channel.rIntf!,
        parent: parent,
        name: '${name}_axiRdMonitor');
  }
}

/// An agent for sending and monitoring write requests.
class Axi4WriteAgent extends Agent {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// Channel that the agent can send requests on.
  final Axi4Channel channel;

  /// The sequencer where write requests should be sent.
  late final Sequencer<Axi4WriteRequestPacket> sequencer;

  /// The driver that sends write requests over the interface.
  late final Axi4WriteMainDriver driver;

  /// Monitoring of write requests over the interface.
  late final Axi4WriteMonitor monitor;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// Constructs a new [Axi4WriteAgent].
  Axi4WriteAgent({
    required this.sIntf,
    required this.channel,
    required Component parent,
    String name = 'axiWriteAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    if (!channel.hasWrite) {
      throw RohdHclException('A write agent must be associated with a channel '
          'that can send write requests.');
    }

    sequencer =
        Sequencer<Axi4WriteRequestPacket>('${name}_axiRdSequencer', this);
    driver = Axi4WriteMainDriver(
      parent: this,
      sIntf: sIntf,
      wIntf: channel.wIntf!,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
      name: '${name}_axiWrDriver',
    );
    monitor = Axi4WriteMonitor(
        sIntf: sIntf,
        wIntf: channel.wIntf!,
        parent: parent,
        name: '${name}_axiWrMonitor');
  }
}

/// An agent for sending requests on
/// [Axi4ReadInterface]s and [Axi4WriteInterface]s.
///
/// Driven read packets will update the returned data into the same packet.
class Axi4MainAgent extends Agent {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// Channels that the agent can send requests on.
  final List<Axi4Channel> channels;

  /// Agents to manage individual read channels.
  final List<Axi4ReadAgent> rdAgents = [];

  /// Agents to manage individual write channels.
  final List<Axi4WriteAgent> wrAgents = [];

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  // capture mapping of channel ID to TB object index
  final Map<int, int> _readAddrToChannel = {};
  final Map<int, int> _writeAddrToChannel = {};

  /// Get the ith channel's read sequencer.
  Sequencer<Axi4ReadRequestPacket>? getRdSequencer(int channelId) =>
      _readAddrToChannel.containsKey(channelId)
          ? rdAgents[_readAddrToChannel[channelId]!].sequencer
          : null;

  /// Get the ith channel's write sequencer.
  Sequencer<Axi4WriteRequestPacket>? getWrSequencer(int channelId) =>
      _writeAddrToChannel.containsKey(channelId)
          ? wrAgents[_writeAddrToChannel[channelId]!].sequencer
          : null;

  /// Get the ith channel's read driver.
  Axi4ReadMainDriver? getRdDriver(int channelId) =>
      _readAddrToChannel.containsKey(channelId)
          ? rdAgents[_readAddrToChannel[channelId]!].driver
          : null;

  /// Get the ith channel's write driver.
  Axi4WriteMainDriver? getWrDriver(int channelId) =>
      _writeAddrToChannel.containsKey(channelId)
          ? wrAgents[_writeAddrToChannel[channelId]!].driver
          : null;

  /// Get the ith channel's read monitor.
  Axi4ReadMonitor? getRdMonitor(int channelId) =>
      _readAddrToChannel.containsKey(channelId)
          ? rdAgents[_readAddrToChannel[channelId]!].monitor
          : null;

  /// Get the ith channel's write monitor.
  Axi4WriteMonitor? getWrMonitor(int channelId) =>
      _writeAddrToChannel.containsKey(channelId)
          ? wrAgents[_writeAddrToChannel[channelId]!].monitor
          : null;

  /// Constructs a new [Axi4MainAgent].
  Axi4MainAgent({
    required this.sIntf,
    required this.channels,
    required Component parent,
    String name = 'axiMainAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    final idMap = <int, bool>{};
    for (var i = 0; i < channels.length; i++) {
      if (idMap.containsKey(channels[i].channelId)) {
        throw RohdHclException('Channel ID ${channels[i].channelId} is not '
            'unique across all channels.');
      }
      idMap[channels[i].channelId] = true;

      if (channels[i].hasRead) {
        rdAgents.add(Axi4ReadAgent(
            sIntf: sIntf,
            channel: channels[i],
            parent: parent,
            name: 'axi4RdAgent_$i'));
        _readAddrToChannel[i] = rdAgents.length - 1;
      }
      if (channels[i].hasWrite) {
        wrAgents.add(Axi4WriteAgent(
            sIntf: sIntf,
            channel: channels[i],
            parent: parent,
            name: 'axi4WrAgent_$i'));
        _writeAddrToChannel[i] = wrAgents.length - 1;
      }
    }
  }
}
