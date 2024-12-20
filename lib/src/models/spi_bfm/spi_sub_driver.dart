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

/// A driver for the sub side of the [SpiInterface].
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

    intf.miso.inject(0);
    SpiPacket? packet;

    int? dataIndex;

    // Function handles the packet.
    void packetHandler({required bool loadOnly}) {
      if (packet == null && pendingSeqItems.isNotEmpty) {
        packet = pendingSeqItems.removeFirst();
        if (loadOnly) {
          dataIndex = 0;
        } else {
          dataIndex = -1;
        }
      }
      if (packet != null) {
        if (loadOnly) {
          intf.miso.inject(packet!.data[dataIndex!]);
          logger.info('injected sub packet, index: $dataIndex');
        } else {
          dataIndex = dataIndex! + 1;
          logger.info('incremented index to: $dataIndex');
          if (dataIndex! < packet!.data.width) {
            logger.info('injecting sub packet, index: $dataIndex');
            intf.miso.inject(packet!.data[dataIndex!]);
          }
        }

        if (dataIndex! >= packet!.data.width) {
          packet = null;
          dataIndex = null;
          packetHandler(loadOnly: loadOnly);
        }
      } else {
        intf.miso.inject(0);
      }
    }

    intf.csb.negedge.listen((_) {
      logger.info('cs negedge');
      packetHandler(loadOnly: true);
    });

    intf.sclk.negedge.listen((_) {
      logger.info('sclk negedge');
      packetHandler(loadOnly: false);
    });
  }
}
