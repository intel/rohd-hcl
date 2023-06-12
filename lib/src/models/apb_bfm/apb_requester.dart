// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// apb_requester.dart
// An agent sending for APB requests.
//
// 2023 June 12
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// An agent for sending requests on an [ApbInterface].
///
/// Driven read packets will update the returned data into the same packet.
class ApbRequester extends Agent {
  /// The interface to drive.
  final ApbInterface intf;

  /// The sequencer where requests should be sent.
  late final Sequencer<ApbPacket> sequencer;

  /// The driver that sends the requests over the interface.
  late final ApbRequesterDriver driver;

  /// The number of cycles before timing out if no transactions can be sent.
  final int timeoutCycles;

  /// The number of cycles before an objection will be dropped when there are
  /// no pending packets to send.
  final int dropDelayCycles;

  /// Constructs a new [ApbRequester].
  ApbRequester({
    required this.intf,
    required Component parent,
    String name = 'apbRequester',
    this.timeoutCycles = 500,
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    sequencer = Sequencer<ApbPacket>('sequencer', this);

    driver = ApbRequesterDriver(
      parent: this,
      intf: intf,
      sequencer: sequencer,
      timeoutCycles: timeoutCycles,
      dropDelayCycles: dropDelayCycles,
    );
  }
}
