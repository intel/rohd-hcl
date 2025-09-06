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

/// A request packet on an AXI4 interface.
class Axi4RequestPacket extends SequenceItem implements Trackable {
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

  /// Domain (optional).
  final LogicValue? domain;

  /// Bar (optional).
  final LogicValue? bar;

  /// Creates a new packet.
  // TODO: how to capture the type (AR vs. AW)??
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
      this.user,
      this.domain,
      this.bar});

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
      case Axi4RequestTracker.timeField:
        return Simulator.time.toString();
      case Axi4RequestTracker.idField:
        return id.toString();
      case Axi4RequestTracker.addrField:
        return addr.toString();
      case Axi4RequestTracker.lenField:
        return len.toString();
      case Axi4RequestTracker.sizeField:
        return size.toString();
      case Axi4RequestTracker.burstField:
        return burst.toString();
      case Axi4RequestTracker.lockField:
        return lock.toString();
      case Axi4RequestTracker.cacheField:
        return cache.toString();
      case Axi4RequestTracker.protField:
        return prot.toString();
      case Axi4RequestTracker.qosField:
        return qos.toString();
      case Axi4RequestTracker.regionField:
        return region.toString();
      case Axi4RequestTracker.userField:
        return user.toString();
      case Axi4RequestTracker.domainField:
        return domain.toString();
      case Axi4RequestTracker.barField:
        return bar.toString();
    }

    return null;
  }
}

/// A data packet on an AXI4 interface.
class Axi4DataPacket extends SequenceItem implements Trackable {
  /// Data.
  final LogicValue data;

  /// Strobe (optional).
  final LogicValue? strb;

  /// User (optional).
  final LogicValue? user;

  /// ID (optional).
  final LogicValue? id;

  /// Response (optional).
  final LogicValue? resp;

  /// Creates a new packet.
  Axi4DataPacket({
    required this.data,
    this.strb,
    this.user,
    this.id,
    this.resp,
  });

  /// A [Future] that completes once the the read has been completed.
  Future<void> get completed => _completer.future;
  final Completer<void> _completer = Completer<void>();

  /// Called by a completer when a transfer is completed.
  void complete() => _completer.complete();

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case Axi4DataTracker.timeField:
        return Simulator.time.toString();
      case Axi4DataTracker.typeField:
        return strb != null ? 'W' : 'R';
      case Axi4DataTracker.dataField:
        return data.toString();
      case Axi4DataTracker.strbField:
        return strb.toString();
      case Axi4DataTracker.userField:
        return user.toString();
      case Axi4DataTracker.idField:
        return id.toString();
      case Axi4DataTracker.respField:
        return resp.toString();
    }

    return null;
  }
}

/// A response packet on an AXI4 interface.
class Axi4ResponsePacket extends SequenceItem implements Trackable {
  /// Response.
  final LogicValue? resp;

  /// User (optional).
  final LogicValue? user;

  /// ID (optional).
  final LogicValue? id;

  /// Creates a new packet.
  Axi4ResponsePacket({
    this.resp,
    this.user,
    this.id,
  });

  /// A [Future] that completes once the the read has been completed.
  Future<void> get completed => _completer.future;
  final Completer<void> _completer = Completer<void>();

  /// Called by a completer when a transfer is completed.
  void complete() => _completer.complete();

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case Axi4ResponseTracker.timeField:
        return Simulator.time.toString();
      case Axi4ResponseTracker.respField:
        return resp.toString();
      case Axi4ResponseTracker.userField:
        return user.toString();
      case Axi4ResponseTracker.idField:
        return id.toString();
    }

    return null;
  }
}
