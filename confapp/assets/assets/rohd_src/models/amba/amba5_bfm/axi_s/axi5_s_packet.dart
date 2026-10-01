// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi5_s_packet.dart
// Packet for AXI-S interface.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A data packet on an AXI-S interface.
class Axi5StreamPacket extends SequenceItem implements Trackable {
  /// Data.
  final BigInt data;

  /// Strobe (optional).
  final int? strb;

  /// Last (optional).
  final bool? last;

  /// Keep (optional).
  final int? keep;

  /// User (optional).
  final int? user;

  /// ID (optional).
  final int? id;

  /// Dest (optional).
  final int? dest;

  /// Wakeup (optional).
  final bool? wakeup;

  /// Creates a new packet.
  Axi5StreamPacket({
    required this.data,
    this.strb,
    this.last,
    this.keep,
    this.user,
    this.id,
    this.dest,
    this.wakeup,
  });

  /// A [Future] that completes once the the read has been completed.
  Future<void> get completed => _completer.future;
  final Completer<void> _completer = Completer<void>();

  /// Called by a completer when a transfer is completed.
  void complete() => _completer.complete();

  /// Copy constructor.
  Axi5StreamPacket clone() => Axi5StreamPacket(
        data: data,
        strb: strb,
        last: last,
        keep: keep,
        user: user,
        id: id,
        dest: dest,
        wakeup: wakeup,
      );

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case Axi5StreamTracker.timeField:
        return Simulator.time.toString();
      case Axi5StreamTracker.dataField:
        return data.toRadixString(16);
      case Axi5StreamTracker.strbField:
        return strb?.toRadixString(16);
      case Axi5StreamTracker.keepField:
        return keep?.toString();
      case Axi5StreamTracker.userField:
        return user?.toRadixString(16);
      case Axi5StreamTracker.idField:
        return id?.toRadixString(16);
      case Axi5StreamTracker.destField:
        return dest?.toRadixString(16);
      case Axi5StreamTracker.lastField:
        return last?.toString();
      case Axi5StreamTracker.wakeupField:
        return wakeup?.toString();
    }

    return null;
  }
}
