// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_sub_agent.dart
// An agent for the sub side of the SPI interface.
//
// 2024 September 23
// Author: Roberto Torres <roberto.torres@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A model for the sub side of the SPI interface.
class SpiSubAgent extends Agent {
  /// The interface to drive.
  final SpiInterface intf;

  /// The sequencer
  late final Sequencer<SpiPacket> sequencer;

  /// The driver that sends packets.
  late final SpiSubDriver driver;

  /// The monitor that watches the interface.
  late final SpiMonitor monitor;

  /// Creates a new [SpiSubAgent].
  SpiSubAgent({
    required this.intf,
    required Component parent,
    String name = 'spiSub',
  }) : super(name, parent) {
    sequencer = Sequencer<SpiPacket>('sequencer', this);

    driver = SpiSubDriver(
      parent: this,
      intf: intf,
      sequencer: sequencer,
    );

    ///
    monitor = SpiMonitor(
      parent: this,
      direction: SpiDirection.main,
      intf: intf,
    );
  }
}
