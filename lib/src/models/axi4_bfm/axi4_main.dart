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
  /// If false, the [rIntf] field should be null.
  final bool hasRead;

  /// Does this channel support write transactions.
  ///
  /// If false, the [wIntf] field should be null.
  final bool hasWrite;

  /// Read interface.
  final Axi4ReadInterface? rIntf;

  /// Write interface.
  final Axi4WriteInterface? wIntf;

  /// Constructor.
  Axi4Channel({
    this.channelId = 0,
    this.hasRead = true,
    this.hasWrite = true,
    this.rIntf,
    this.wIntf,
  })  : assert(
            hasRead || hasWrite,
            'A channel must support either'
            ' reads or writes (or both)'),
        assert(!hasRead || rIntf != null,
            'A channel that supports reads must have a read interface'),
        assert(!hasWrite || wIntf != null,
            'A channel that supports writes must have a write interface');
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

  /// The sequencers where read requests should be sent.
  final List<Sequencer<Axi4ReadRequestPacket>> rdSequencers = [];

  /// The sequencers where write requests should be sent.
  final List<Sequencer<Axi4WriteRequestPacket>> wrSequencers = [];

  /// The drivers that send read requests over the interface.
  final List<Axi4ReadMainDriver> rdDrivers = [];

  /// The drivers that send write requests over the interface.
  final List<Axi4WriteMainDriver> wrDrivers = [];

  /// Monitoring of read requests over the interface.
  final List<Axi4ReadMonitor> rdMonitors = [];

  /// Monitoring of write requests over the interface.
  final List<Axi4WriteMonitor> wrMonitors = [];

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
          ? rdSequencers[_readAddrToChannel[channelId]!]
          : null;

  /// Get the ith channel's write sequencer.
  Sequencer<Axi4WriteRequestPacket>? getWrSequencer(int channelId) =>
      _writeAddrToChannel.containsKey(channelId)
          ? wrSequencers[_writeAddrToChannel[channelId]!]
          : null;

  /// Get the ith channel's read driver.
  Axi4ReadMainDriver? getRdDriver(int channelId) =>
      _readAddrToChannel.containsKey(channelId)
          ? rdDrivers[_readAddrToChannel[channelId]!]
          : null;

  /// Get the ith channel's write driver.
  Axi4WriteMainDriver? getWrDriver(int channelId) =>
      _writeAddrToChannel.containsKey(channelId)
          ? wrDrivers[_writeAddrToChannel[channelId]!]
          : null;

  /// Get the ith channel's read monitor.
  Axi4ReadMonitor? getRdMonitor(int channelId) =>
      _readAddrToChannel.containsKey(channelId)
          ? rdMonitors[_readAddrToChannel[channelId]!]
          : null;

  /// Get the ith channel's write monitor.
  Axi4WriteMonitor? getWrMonitor(int channelId) =>
      _writeAddrToChannel.containsKey(channelId)
          ? wrMonitors[_writeAddrToChannel[channelId]!]
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
    for (var i = 0; i < channels.length; i++) {
      if (channels[i].hasRead) {
        rdSequencers.add(Sequencer<Axi4ReadRequestPacket>(
            'axiRdSequencer${channels[i].channelId}', this));
        _readAddrToChannel[i] = rdSequencers.length - 1;
        rdDrivers.add(Axi4ReadMainDriver(
          parent: this,
          sIntf: sIntf,
          rIntf: channels[i].rIntf!,
          sequencer: rdSequencers[_readAddrToChannel[i]!],
          timeoutCycles: timeoutCycles,
          dropDelayCycles: dropDelayCycles,
          name: 'axiRdDriver${channels[i].channelId}',
        ));
        rdMonitors.add(Axi4ReadMonitor(
            sIntf: sIntf,
            rIntf: channels[i].rIntf!,
            parent: parent,
            name: 'axiRdMonitor${channels[i].channelId}'));
      }
      if (channels[i].hasWrite) {
        wrSequencers.add(Sequencer<Axi4WriteRequestPacket>(
            'axiWrSequencer${channels[i].channelId}', this));
        _writeAddrToChannel[i] = wrSequencers.length - 1;
        wrDrivers.add(Axi4WriteMainDriver(
          parent: this,
          sIntf: sIntf,
          wIntf: channels[i].wIntf!,
          sequencer: wrSequencers[_writeAddrToChannel[i]!],
          timeoutCycles: timeoutCycles,
          dropDelayCycles: dropDelayCycles,
          name: 'axiWrDriver${channels[i].channelId}',
        ));
        wrMonitors.add(Axi4WriteMonitor(
            sIntf: sIntf,
            wIntf: channels[i].wIntf!,
            parent: parent,
            name: 'axiWrMonitor${channels[i].channelId}'));
      }
    }
  }
}
