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

/// An agent for sending requests on
/// [Axi4ReadInterface]s and [Axi4WriteInterface]s.
///
/// Driven read packets will update the returned data into the same packet.
class Axi4MainAgent extends Agent {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// AXI4 Read Interface.
  List<Axi4ReadInterface> rIntfs = [];

  /// AXI4 Write Interface.
  List<Axi4WriteInterface> wIntfs = [];

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

  /// Constructs a new [Axi4MainAgent].
  Axi4MainAgent({
    required this.sIntf,
    required this.rIntfs,
    required this.wIntfs,
    required Component parent,
    String name = 'axiMainAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    for (var i = 0; i < rIntfs.length; i++) {
      rdSequencers
          .add(Sequencer<Axi4ReadRequestPacket>('axiRdSequencer$i', this));
      rdDrivers.add(Axi4ReadMainDriver(
        parent: this,
        sIntf: sIntf,
        rIntf: rIntfs[i],
        sequencer: rdSequencers[i],
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles,
        name: 'axiRdDriver$i',
      ));
      rdMonitors.add(Axi4ReadMonitor(
          sIntf: sIntf,
          rIntf: rIntfs[i],
          parent: parent,
          name: 'axiRdMonitor$i'));
    }

    for (var i = 0; i < wIntfs.length; i++) {
      wrSequencers
          .add(Sequencer<Axi4WriteRequestPacket>('axiWrSequencer$i', this));
      wrDrivers.add(Axi4WriteMainDriver(
        parent: this,
        sIntf: sIntf,
        wIntf: wIntfs[i],
        sequencer: wrSequencers[i],
        timeoutCycles: timeoutCycles,
        dropDelayCycles: dropDelayCycles,
        name: 'axiWrDriver$i',
      ));
      wrMonitors.add(Axi4WriteMonitor(
          sIntf: sIntf,
          wIntf: wIntfs[i],
          parent: parent,
          name: 'axiWrMonitor$i'));
    }
  }
}
