// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_main.dart
// An agent sending for AXI4 requests.
//
// 2025 January
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/models/axi4_bfm/axi4_bfm.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// An agent for sending requests on [Axi4ReadInterface]s and [Axi4WriteInterface]s.
///
/// Driven read packets will update the returned data into the same packet.
class Axi4MainAgent extends Agent {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// AXI4 Read Interface.
  final Axi4ReadInterface rIntf;

  /// AXI4 Write Interface.
  final Axi4WriteInterface wIntf;

  /// The sequencer where requests should be sent.
  late final Sequencer<Axi4RequestPacket> sequencer;

  /// The driver that sends the requests over the interface.
  late final Axi4MainDriver driver;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// Constructs a new [Axi4MainAgent].
  Axi4MainAgent({
    required this.sIntf,
    required this.rIntf,
    required this.wIntf,
    required Component parent,
    String name = 'axiMainAgent',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    sequencer = Sequencer<Axi4RequestPacket>('sequencer', this);

    driver = Axi4MainDriver(
      parent: this,
      sIntf: sIntf,
      rIntf: rIntf,
      wIntf: wIntf,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
    );
  }
}
