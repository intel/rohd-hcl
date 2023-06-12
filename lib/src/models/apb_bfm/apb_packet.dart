// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// apb_packet.dart
// Packet for APB interface.
//
// 2023 June 12
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/interfaces.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A packet on an [ApbInterface].
abstract class ApbPacket extends SequenceItem {
  /// The address for this packet.
  final LogicValue addr;

  /// The index of the select this packet should be driven on.
  final int selectIndex;

  /// Creates a new packet.
  ApbPacket({required this.addr, this.selectIndex = 0});
}

/// A write packet on an [ApbInterface].
class ApbWritePacket extends ApbPacket {
  /// The data for this packet.
  final LogicValue data;

  /// Creates a write packet.
  ApbWritePacket({required super.addr, required this.data, super.selectIndex});
}

/// A read packet on an [ApbInterface].
class ApbReadPacket extends ApbPacket {
  /// Data returned by the read.
  LogicValue? returnedData;

  /// Creates a read packet.
  ApbReadPacket({required super.addr, super.selectIndex});
}
