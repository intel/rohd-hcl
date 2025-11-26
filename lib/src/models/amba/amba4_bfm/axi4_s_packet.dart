// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_s_packet.dart
// Packet for AXI-S interface.
//
// 2025 January
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A data packet on an AXI-S interface.
class Axi4StreamPacket extends SequenceItem implements Trackable {
  /// Data.
  final LogicValue data;

  /// Strobe (optional).
  final LogicValue? strb;

  /// Keep (optional).
  final LogicValue? keep;

  /// User (optional).
  final LogicValue? user;

  /// ID (optional).
  final LogicValue? id;

  /// Dest (optional).
  final LogicValue? dest;

  /// Creates a new packet.
  Axi4StreamPacket({
    required this.data,
    this.strb,
    this.keep,
    this.user,
    this.id,
    this.dest,
  });

  /// A [Future] that completes once the the read has been completed.
  Future<void> get completed => _completer.future;
  final Completer<void> _completer = Completer<void>();

  /// Called by a completer when a transfer is completed.
  void complete() => _completer.complete();

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case Axi4StreamTracker.timeField:
        return Simulator.time.toString();
      case Axi4StreamTracker.dataField:
        return data.toString();
      case Axi4StreamTracker.strbField:
        return strb.toString();
      case Axi4StreamTracker.keepField:
        return keep.toString();
      case Axi4StreamTracker.userField:
        return user.toString();
      case Axi4StreamTracker.idField:
        return id.toString();
      case Axi4StreamTracker.destField:
        return dest.toString();
    }

    return null;
  }
}
