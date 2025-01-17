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
import 'package:rohd_hcl/src/models/axi4_bfm/axi4_bfm.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A request packet on an AXI4 interface.
abstract class Axi4RequestPacket extends SequenceItem implements Trackable {
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
  Axi4RequestPacket(
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
    if (_returnedResponse != null || _returnedUserData != null) {
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
      case Axi4Tracker.idField:
        return Simulator.time.toString();
      case Axi4Tracker.addrField:
        return addr.toString();
      case Axi4Tracker.lenField:
        return len.toString();
      case Axi4Tracker.sizeField:
        return size.toString();
      case Axi4Tracker.burstField:
        return burst.toString();
      case Axi4Tracker.lockField:
        return lock.toString();
      case Axi4Tracker.cacheField:
        return cache.toString();
      case Axi4Tracker.protField:
        return prot.toString();
      case Axi4Tracker.qosField:
        return qos.toString();
      case Axi4Tracker.regionField:
        return region.toString();
      case Axi4Tracker.userField:
        return user.toString();
      case Axi4Tracker.respField:
        return returnedResponse.toString();
      case Axi4Tracker.rUserField:
        return returnedUserData.toString();
    }

    return null;
  }
}

/// A read packet on an [Axi4ReadInterface].
class Axi4ReadRequestPacket extends Axi4RequestPacket {
  /// Data returned by the read.
  List<LogicValue> get returnedData => _returnedData;

  List<LogicValue> _returnedData = [];

  /// Creates a read packet.
  Axi4ReadRequestPacket({
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
    List<LogicValue> data = const [],
    LogicValue? resp,
    LogicValue? user,
  }) {
    if (_returnedData.isNotEmpty) {
      throw RohdHclException('Packet is already completed.');
    }
    _returnedData = data;
    super.complete(resp: resp, user: user);
  }

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case Axi4Tracker.typeField:
        return 'R';
      case Axi4Tracker.dataField:
        return returnedData
            .map((d) => d.toRadixString(radix: 16))
            .toList()
            .reversed
            .join();
    }

    return super.trackerString(field);
  }
}

/// A write packet on an [Axi4WriteInterface].
class Axi4WriteRequestPacket extends Axi4RequestPacket {
  /// The data for this packet.
  final List<LogicValue> data;

  /// The strobe associated with this write.
  final List<LogicValue?> strobe;

  /// The user metadata associated with this write.
  final List<LogicValue?> wUser;

  /// Creates a write packet.
  ///
  /// If no [strobe] is provided, it will default to all high.
  Axi4WriteRequestPacket(
      {required super.addr,
      required super.prot,
      required this.data,
      super.id,
      super.len,
      super.size,
      super.burst,
      super.lock,
      super.cache,
      super.qos,
      super.region,
      super.user,
      this.strobe = const [],
      this.wUser = const []});

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case Axi4Tracker.typeField:
        return 'W';
      case Axi4Tracker.dataField:
        return data
            .map((d) => d.toRadixString(radix: 16))
            .toList()
            .reversed
            .join();
      case Axi4Tracker.strbField:
        return strobe
            .where(
              (element) => element != null,
            )
            .map((d) => d!.toRadixString(radix: 16))
            .toList()
            .reversed
            .join();
    }

    return super.trackerString(field);
  }
}
