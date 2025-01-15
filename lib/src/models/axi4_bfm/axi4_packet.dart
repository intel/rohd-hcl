// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_packet.dart
// Packet for AXI4 interface.
//
// 2025 January
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A packet on an AXI4 interface.
abstract class Axi4Packet extends SequenceItem implements Trackable {
  /// Address.
  final LogicValue addr;

  /// Protection
  final LogicValue prot;

  /// ID (optional).
  final LogicValue? id;

  /// Length (optional).
  final LogicValue? len;

  /// Size (optional).
  final LogicValue? size;

  /// Burst (optional).
  final LogicValue? burst;

  /// Lock (optional).
  final LogicValue? lock;

  /// Cache (optional).
  final LogicValue? cache;

  /// QoS (optional).
  final LogicValue? qos;

  /// Region (optional).
  final LogicValue? region;

  /// User (optional).
  final LogicValue? user;

  /// Creates a new packet.
  Axi4Packet(
      {required this.addr,
      required this.prot,
      this.id,
      this.len,
      this.size,
      this.burst,
      this.lock,
      this.cache,
      this.qos,
      this.region,
      this.user});

  /// A [Future] that completes once the the read has been completed.
  Future<void> get completed => _completer.future;
  final Completer<void> _completer = Completer<void>();

  /// Response returned by the request.
  LogicValue? get returnedResponse => _returnedResponse;

  /// User data returned by the request.
  LogicValue? get returnedUserData => _returnedUserData;

  LogicValue? _returnedResponse;
  LogicValue? _returnedUserData;

  /// Called by a completer when a transfer is completed.
  void complete({LogicValue? resp, LogicValue? user}) {
    if (_returnedResponse != null) {
      throw RohdHclException('Packet is already completed.');
    }

    _returnedResponse = resp;
    _returnedUserData = user;
    _completer.complete();
  }

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case Axi4Tracker.timeField:
        return Simulator.time.toString();
      case Axi4Tracker.addrField:
        return addr.toString();
      case Axi4Tracker.selectField:
        return selectIndex.toString();
    }

    return null;
  }
}

/// A read packet on an [Axi4ReadInterface].
class Axi4ReadPacket extends Axi4Packet {
  /// Data returned by the read.
  LogicValue? get returnedData => _returnedData;

  LogicValue? _returnedData;

  /// Creates a read packet.
  Axi4ReadPacket({
    required super.addr,
    required super.prot,
    super.id,
    super.len,
    super.size,
    super.burst,
    super.lock,
    super.cache,
    super.qos,
    super.region,
    super.user,
  });

  /// Called by a completer when a transfer is completed.
  @override
  void complete({
    LogicValue? data,
    LogicValue? resp,
    LogicValue? user,
  }) {
    if (_returnedData != null) {
      throw RohdHclException('Packet is already completed.');
    }
    _returnedData = data;
    super.complete(resp: resp, user: user);
  }

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
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

/// A write packet on an [Axi4WriteInterface].
class Axi4WritePacket extends Axi4Packet {
  /// The data for this packet.
  final LogicValue data;

  /// The strobe associated with this write.
  final LogicValue? strobe;

  /// The user metadata associated with this write.
  final LogicValue? wUser;

  /// Creates a write packet.
  ///
  /// If no [strobe] is provided, it will default to all high.
  Axi4WritePacket(
      {required super.addr,
      required super.prot,
      super.id,
      super.len,
      super.size,
      super.burst,
      super.lock,
      super.cache,
      super.qos,
      super.region,
      super.user,
      LogicValue? strobe,
      required this.data,
      this.wUser})
      : strobe = strobe ?? LogicValue.filled(data.width ~/ 8, LogicValue.one);

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
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
