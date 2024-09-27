// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_main.dart
// An agent for the main side of the SPI interface.
//
// 2024 September 23
// Author: Roberto Torres <roberto.torres@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// An agent for the main side of the [SpiInterface].
///
///
class SpiMainAgent extends Agent {
  /// The interface to drive.
  final SpiInterface intf;

  /// The sequencer
  late final Sequencer<SpiPacket> sequencer;

  /// The driver that sends packets.
  late final SpiMainDriver driver;

  /// The number of cycles before dropping an objection.
  final int dropDelayCycles;

  /// Creates a new [SpiMainAgent].
  SpiMainAgent({
    required this.intf,
    required Component parent,
    required Logic clk,
    String name = 'spiMain',
    this.dropDelayCycles = 30,
  }) : super(name, parent) {
    sequencer = Sequencer<SpiPacket>('sequencer', this);

    driver = SpiMainDriver(
      parent: this,
      intf: intf,
      clk: clk,
      sequencer: sequencer,
      dropDelayCycles: dropDelayCycles,
    );
  }
}
