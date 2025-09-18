// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// lti_packet.dart
// Packet for LTI interface.
//
// 2025 September
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A packet for the LTI LA channel interface.
class LtiLaChannelPacket extends SequenceItem implements Trackable {
  /// User signals.
  final Axi5UserSignalsStruct? user;

  /// ID signals.
  final Axi5IdSignalsStruct? id;

  /// Prot signals.
  final Axi5ProtSignalsStruct? prot;

  /// MMU signals.
  final Axi5MmuSignalsStruct? mmu;

  /// Debug signals.
  final Axi5DebugSignalsStruct? debug;

  /// Address signals.
  final int addr;

  /// Trans signals.
  final int trans;

  /// Attr signals.
  final int attr;

  /// OGV
  final bool ogV;

  /// OG.
  final int? og;

  /// tlBlock signals.
  final int? tlBlock;

  /// ident signals.
  final int? ident;

  /// The Completer for tracking completion.
  final Completer<void> _completer = Completer<void>();

  /// Constructor.
  LtiLaChannelPacket({
    required this.addr,
    this.trans = 0,
    this.attr = 0,
    this.ogV = false,
    this.user,
    this.id,
    this.prot,
    this.mmu,
    this.debug,
    this.og,
    this.tlBlock,
    this.ident,
  });

  /// Returns a [Future] that completes when this packet is completed.
  Future<void> get completed => _completer.future;

  /// Marks this packet as completed.
  void complete() => _completer.complete();

  /// Returns a string for tracking.
  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case LtiLaChannelTracker.addrField:
        return addr.toString();
      case LtiLaChannelTracker.transField:
        return trans.toString();
      case LtiLaChannelTracker.attrField:
        return attr.toString();
      case LtiLaChannelTracker.ogVField:
        return ogV.toString();
      case LtiLaChannelTracker.userField:
        return user?.user?.toString() ?? '';
      case LtiLaChannelTracker.idField:
        return id?.id?.toString() ?? '';
      case LtiLaChannelTracker.nseField:
        return prot?.nse?.toString() ?? '';
      case LtiLaChannelTracker.privField:
        return prot?.priv?.toString() ?? '';
      case LtiLaChannelTracker.instField:
        return prot?.inst?.toString() ?? '';
      case LtiLaChannelTracker.pasField:
        return prot?.pas?.toString() ?? '';
      case LtiLaChannelTracker.mmuValidField:
        return mmu?.mmuValid?.toString() ?? '';
      case LtiLaChannelTracker.mmuSecSidField:
        return mmu?.mmuSecSid?.toString() ?? '';
      case LtiLaChannelTracker.mmuSidField:
        return mmu?.mmuSid?.toString() ?? '';
      case LtiLaChannelTracker.mmuSsidVField:
        return mmu?.mmuSsidV?.toString() ?? '';
      case LtiLaChannelTracker.mmuSsidField:
        return mmu?.mmuSsid?.toString() ?? '';
      case LtiLaChannelTracker.mmuAtStField:
        return mmu?.mmuAtSt?.toString() ?? '';
      case LtiLaChannelTracker.mmuFlowField:
        return mmu?.mmuFlow?.toString() ?? '';
      case LtiLaChannelTracker.mmuPasUnknownField:
        return mmu?.mmuPasUnknown?.toString() ?? '';
      case LtiLaChannelTracker.mmuPmField:
        return mmu?.mmuPm?.toString() ?? '';
      case LtiLaChannelTracker.loopField:
        return debug?.loop?.toString() ?? '';
      case LtiLaChannelTracker.ogField:
        return og?.toString() ?? '';
      case LtiLaChannelTracker.tlBlockField:
        return tlBlock?.toString() ?? '';
      case LtiLaChannelTracker.identField:
        return ident?.toString() ?? '';
      default:
        return '';
    }
  }
}

/// A packet for the LTI LR channel interface.
class LtiLrChannelPacket extends SequenceItem implements Trackable {
  /// User signals.
  final Axi5UserSignalsStruct? user;

  /// ID signals.
  final Axi5IdSignalsStruct? id;

  /// Prot signals.
  final Axi5ProtSignalsStruct? prot;

  /// Debug signals.
  final Axi5DebugSignalsStruct? debug;

  /// Response signals.
  final Axi5ResponseSignalsStruct? response;

  /// Address signals.
  final int addr;

  /// Hwattr signals.
  final int hwattr;

  /// Attr signals.
  final int attr;

  /// mecId signals.
  final int? mecId;

  /// mpam signals.
  final int? mpam;

  /// ctag signals.
  final int? ctag;

  /// size signals.
  final int size;

  /// The Completer for tracking completion.
  final Completer<void> _completer = Completer<void>();

  /// Constructor.
  LtiLrChannelPacket({
    required this.addr,
    this.hwattr = 0,
    this.attr = 0,
    this.user,
    this.id,
    this.prot,
    this.debug,
    this.response,
    this.mecId,
    this.mpam,
    this.ctag,
    this.size = 0,
  });

  /// Returns a [Future] that completes when this packet is completed.
  Future<void> get completed => _completer.future;

  /// Marks this packet as completed.
  void complete() => _completer.complete();

  /// Returns a string for tracking.
  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case LtiLrChannelTracker.addrField:
        return addr.toString();
      case LtiLrChannelTracker.hwAttrField:
        return hwattr.toString();
      case LtiLrChannelTracker.attrField:
        return attr.toString();
      case LtiLrChannelTracker.userField:
        return user?.user?.toString() ?? '';
      case LtiLrChannelTracker.idField:
        return id?.id?.toString() ?? '';
      case LtiLrChannelTracker.nseField:
        return prot?.nse?.toString() ?? '';
      case LtiLrChannelTracker.privField:
        return prot?.priv?.toString() ?? '';
      case LtiLrChannelTracker.instField:
        return prot?.inst?.toString() ?? '';
      case LtiLrChannelTracker.pasField:
        return prot?.pas?.toString() ?? '';
      case LtiLrChannelTracker.loopField:
        return debug?.loop?.toString() ?? '';
      case LtiLrChannelTracker.respField:
        return response?.resp?.toString() ?? '';
      case LtiLrChannelTracker.mecIdField:
        return mecId?.toString() ?? '';
      case LtiLrChannelTracker.mpamField:
        return mpam?.toString() ?? '';
      case LtiLrChannelTracker.ctagField:
        return ctag?.toString() ?? '';
      case LtiLrChannelTracker.sizeField:
        return size.toString();
      default:
        return '';
    }
  }
}

/// A packet for the LTI LC channel interface.
class LtiLcChannelPacket extends SequenceItem implements Trackable {
  /// User signals.
  final Axi5UserSignalsStruct? user;

  /// Tag signals.
  final int tag;

  /// The Completer for tracking completion.
  final Completer<void> _completer = Completer<void>();

  /// Constructor.
  LtiLcChannelPacket({
    required this.tag,
    this.user,
  });

  /// Returns a [Future] that completes when this packet is completed.
  Future<void> get completed => _completer.future;

  /// Marks this packet as completed.
  void complete() => _completer.complete();

  /// Returns a string for tracking.
  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case LtiLcChannelTracker.userField:
        return user?.user?.toString() ?? '';
      case LtiLcChannelTracker.tagField:
        return tag.toString();
      default:
        return '';
    }
  }
}

/// A packet for the LTI LT channel interface.
class LtiLtChannelPacket extends SequenceItem implements Trackable {
  /// User signals.
  final Axi5UserSignalsStruct? user;

  /// Tag signals.
  final int tag;

  /// The Completer for tracking completion.
  final Completer<void> _completer = Completer<void>();

  /// Constructor.
  LtiLtChannelPacket({
    required this.tag,
    this.user,
  });

  /// Returns a [Future] that completes when this packet is completed.
  Future<void> get completed => _completer.future;

  /// Marks this packet as completed.
  void complete() => _completer.complete();

  /// Returns a string for tracking.
  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case LtiLtChannelTracker.userField:
        return user?.user?.toString() ?? '';
      case LtiLtChannelTracker.tagField:
        return tag.toString();
      default:
        return '';
    }
  }
}
