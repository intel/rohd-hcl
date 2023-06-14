// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// apb_packet.dart
// Packet for APB interface.
//
// 2023 June 12
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A packet on an [ApbInterface].
abstract class ApbPacket extends SequenceItem implements Trackable {
  /// The address for this packet.
  final LogicValue addr;

  /// The index of the select this packet should be driven on.
  final int selectIndex;

  /// Creates a new packet.
  ApbPacket({required this.addr, this.selectIndex = 0});

  /// A [Future] that completes once the the read has been completed.
  Future<void> get completed => _completer.future;
  final Completer<void> _completer = Completer<void>();

  /// Error indication returned by the read.
  LogicValue? get returnedSlvErr => _returnedSlvErr;
  LogicValue? _returnedSlvErr;

  /// Called by a completer when a transfer is completed.
  void complete({LogicValue? slvErr}) {
    if (_returnedSlvErr != null) {
      throw RohdHclException('Packet is already completed.');
    }

    _returnedSlvErr = slvErr;
    _completer.complete();
  }

  @override
  String? trackerString(TrackerField field) {
    switch (field) {
      case ApbTracker.timeField:
        return Simulator.time.toString();
      case ApbTracker.addrField:
        return addr.toString();
      case ApbTracker.selectField:
        return selectIndex.toString();
    }

    return null;
  }
}

/// A write packet on an [ApbInterface].
class ApbWritePacket extends ApbPacket {
  /// The data for this packet.
  final LogicValue data;

  /// The strobe associated with this write.
  final LogicValue strobe;

  /// Creates a write packet.
  ///
  /// If no [strobe] is provided, it will default to all high.
  ApbWritePacket(
      {required super.addr,
      required this.data,
      LogicValue? strobe,
      super.selectIndex})
      : strobe = strobe ?? LogicValue.filled(data.width ~/ 8, LogicValue.one);

  @override
  String? trackerString(TrackerField field) {
    switch (field) {
      case ApbTracker.typeField:
        return 'W';
      case ApbTracker.dataField:
        return data.toString();
      case ApbTracker.strobeField:
        return strobe.toString(includeWidth: false);
    }

    return super.trackerString(field);
  }
}

/// A read packet on an [ApbInterface].
class ApbReadPacket extends ApbPacket {
  /// Data returned by the read.
  LogicValue? get returnedData => _returnedData;
  LogicValue? _returnedData;

  /// Creates a read packet.
  ApbReadPacket({required super.addr, super.selectIndex});

  /// Called by a completer when a transfer is completed.
  @override
  void complete({LogicValue? slvErr, LogicValue? data}) {
    if (_returnedData != null) {
      throw RohdHclException('Packet is already completed.');
    }

    _returnedData = data;

    super.complete(slvErr: slvErr);
  }

  @override
  String? trackerString(TrackerField field) {
    switch (field) {
      case ApbTracker.typeField:
        return 'R';
      case ApbTracker.dataField:
        return returnedData?.toString();
      case ApbTracker.slverrField:
        return returnedSlvErr?.toString(includeWidth: false);
    }

    return super.trackerString(field);
  }
}
