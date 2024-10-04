// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_sub_driver.dart
// A driver for SPI Sub.
//
// 2024 September 23
// Author: Roberto Torres <roberto.torres@intel.com>

import 'dart:async';

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A driver for the main side of the [SpiInterface].
///
/// Driven packets will update the returned data into the same packet.
class SpiSubDriver extends PendingDriver<SpiPacket> {
  /// The interface to drive.
  final SpiInterface intf;

  /// Creates a new [SpiSubDriver].
  SpiSubDriver({
    required Component parent,
    required this.intf,
    required super.sequencer,
    String name = 'spiSubDriver',
  }) : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    intf.miso.inject(0); //high impedance?

    SpiPacket? packet;

    int? dataIndex;
    await intf.cs.nextNegedge;

    while (intf.cs.value.isZero) {
      if (packet == null && pendingSeqItems.isNotEmpty) {
        packet = pendingSeqItems.removeFirst();
        dataIndex = 0;
      }
      if (packet != null) {
        logger.info('driving sub packet, index: $dataIndex');
        intf.miso.inject(packet.data[dataIndex!]);
        dataIndex = dataIndex + 1;

        await intf.sclk.nextNegedge;

        if (dataIndex >= packet.data.width) {
          packet = null;
          dataIndex = null;
        }
      } else {
        intf.miso.inject(0); // high impedance?
        break;
      }
    }
  }
}
