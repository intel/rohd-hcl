// Copyright (C) 2024-2025 Intel Corporation
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

    intf.csb.negedge.listen((_) {
      _packetHandler(loadOnly: true);
    });

    intf.sclk.negedge.listen((_) {
      _packetHandler(loadOnly: false);
    });
  }

  /// The pending packet.
  SpiPacket? _packet;

  ///
  int? _dataIndex;

  // Function handles the packet.
  void _packetHandler({required bool loadOnly}) {
    if (pendingSeqItems.isNotEmpty) {
      _packet = pendingSeqItems.removeFirst();
      if (loadOnly) {
        _dataIndex = _packet!.data.width - 1;
      } else {
        _dataIndex = _packet!.data.width;
      }
    }
    if (_packet != null) {
      if (loadOnly) {
        intf.miso.inject(_packet!.data[_dataIndex!]);
      } else {
        _dataIndex = _dataIndex! - 1;
        if (_dataIndex! > -1) {
          intf.miso.inject(_packet!.data[_dataIndex!]);
        }
      }

      if (_dataIndex! <= -1) {
        _packet = null;
        _dataIndex = null;
        _packetHandler(loadOnly: loadOnly);
      }
    } else {
      intf.miso.inject(0);
    }
  }
}
