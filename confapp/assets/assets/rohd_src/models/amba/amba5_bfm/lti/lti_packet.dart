// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// lti_packet.dart
// Packet for LTI interface.
//
// 2025 September
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
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

  /// virtual channel.
  final int vc;

  /// The Completer for tracking completion.
  final Completer<void> _completer = Completer<void>();

  /// Constructor.
  LtiLaChannelPacket({
    required this.addr,
    this.trans = 0,
    this.attr = 0,
    this.ogV = false,
    this.vc = 0,
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
      case LtiLaChannelTracker.timeField:
        return Simulator.time.toString();
      case LtiLaChannelTracker.addrField:
        return addr.toRadixString(16);
      case LtiLaChannelTracker.transField:
        return trans.toRadixString(16);
      case LtiLaChannelTracker.attrField:
        return attr.toRadixString(16);
      case LtiLaChannelTracker.ogVField:
        return ogV.toString();
      case LtiLaChannelTracker.userField:
        return user?.user?.toRadixString(16) ?? '';
      case LtiLaChannelTracker.idField:
        return id?.id?.toRadixString(16) ?? '';
      case LtiLaChannelTracker.nseField:
        return prot?.nse?.toString() ?? '';
      case LtiLaChannelTracker.privField:
        return prot?.priv?.toString() ?? '';
      case LtiLaChannelTracker.instField:
        return prot?.inst?.toString() ?? '';
      case LtiLaChannelTracker.pasField:
        return prot?.pas?.toRadixString(16) ?? '';
      case LtiLaChannelTracker.mmuValidField:
        return mmu?.mmuValid?.toString() ?? '';
      case LtiLaChannelTracker.mmuSecSidField:
        return mmu?.mmuSecSid?.toRadixString(16) ?? '';
      case LtiLaChannelTracker.mmuSidField:
        return mmu?.mmuSid?.toRadixString(16) ?? '';
      case LtiLaChannelTracker.mmuSsidVField:
        return mmu?.mmuSsidV?.toString() ?? '';
      case LtiLaChannelTracker.mmuSsidField:
        return mmu?.mmuSsid?.toRadixString(16) ?? '';
      case LtiLaChannelTracker.mmuAtStField:
        return mmu?.mmuAtSt?.toString() ?? '';
      case LtiLaChannelTracker.mmuFlowField:
        return mmu?.mmuFlow?.toRadixString(16) ?? '';
      case LtiLaChannelTracker.mmuPasUnknownField:
        return mmu?.mmuPasUnknown?.toString() ?? '';
      case LtiLaChannelTracker.mmuPmField:
        return mmu?.mmuPm?.toString() ?? '';
      case LtiLaChannelTracker.loopField:
        return debug?.loop?.toString() ?? '';
      case LtiLaChannelTracker.ogField:
        return og?.toRadixString(16) ?? '';
      case LtiLaChannelTracker.tlBlockField:
        return tlBlock?.toRadixString(16) ?? '';
      case LtiLaChannelTracker.identField:
        return ident?.toRadixString(16) ?? '';
      case LtiLaChannelTracker.vcField:
        return vc.toRadixString(16);
      default:
        return '';
    }
  }

  /// Creates a copy of this packet.
  LtiLaChannelPacket clone() => LtiLaChannelPacket(
        addr: addr,
        trans: trans,
        attr: attr,
        ogV: ogV,
        user: user?.clone(),
        id: id?.clone(),
        prot: prot?.clone(),
        mmu: mmu?.clone(),
        debug: debug?.clone(),
        og: og,
        tlBlock: tlBlock,
        ident: ident,
        vc: vc,
      );
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

  /// virtual channel.
  final int vc;

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
    this.vc = 0,
  });

  /// Returns a [Future] that completes when this packet is completed.
  Future<void> get completed => _completer.future;

  /// Marks this packet as completed.
  void complete() => _completer.complete();

  /// Returns a string for tracking.
  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case LtiLrChannelTracker.timeField:
        return Simulator.time.toString();
      case LtiLrChannelTracker.addrField:
        return addr.toRadixString(16);
      case LtiLrChannelTracker.hwAttrField:
        return hwattr.toRadixString(16);
      case LtiLrChannelTracker.attrField:
        return attr.toRadixString(16);
      case LtiLrChannelTracker.userField:
        return user?.user?.toRadixString(16) ?? '';
      case LtiLrChannelTracker.idField:
        return id?.id?.toRadixString(16) ?? '';
      case LtiLrChannelTracker.nseField:
        return prot?.nse?.toString() ?? '';
      case LtiLrChannelTracker.privField:
        return prot?.priv?.toString() ?? '';
      case LtiLrChannelTracker.instField:
        return prot?.inst?.toString() ?? '';
      case LtiLrChannelTracker.pasField:
        return prot?.pas?.toRadixString(16) ?? '';
      case LtiLrChannelTracker.loopField:
        return debug?.loop?.toString() ?? '';
      case LtiLrChannelTracker.respField:
        return response?.resp?.toRadixString(16) ?? '';
      case LtiLrChannelTracker.mecIdField:
        return mecId?.toRadixString(16) ?? '';
      case LtiLrChannelTracker.mpamField:
        return mpam?.toRadixString(16) ?? '';
      case LtiLrChannelTracker.ctagField:
        return ctag?.toRadixString(16) ?? '';
      case LtiLrChannelTracker.sizeField:
        return size.toRadixString(16);
      case LtiLrChannelTracker.vcField:
        return vc.toRadixString(16);
      default:
        return '';
    }
  }

  /// Creates a copy of this packet.
  LtiLrChannelPacket clone() => LtiLrChannelPacket(
        addr: addr,
        hwattr: hwattr,
        attr: attr,
        user: user?.clone(),
        id: id?.clone(),
        prot: prot?.clone(),
        debug: debug?.clone(),
        response: response?.clone(),
        mecId: mecId,
        mpam: mpam,
        ctag: ctag,
        size: size,
        vc: vc,
      );
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
      case LtiLcChannelTracker.timeField:
        return Simulator.time.toString();
      case LtiLcChannelTracker.userField:
        return user?.user?.toRadixString(16) ?? '';
      case LtiLcChannelTracker.tagField:
        return tag.toRadixString(16);
      default:
        return '';
    }
  }

  /// Creates a copy of this packet.
  LtiLcChannelPacket clone() => LtiLcChannelPacket(
        tag: tag,
        user: user?.clone(),
      );
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
      case LtiLtChannelTracker.timeField:
        return Simulator.time.toString();
      case LtiLtChannelTracker.userField:
        return user?.user?.toRadixString(16) ?? '';
      case LtiLtChannelTracker.tagField:
        return tag.toRadixString(16);
      default:
        return '';
    }
  }

  /// Creates a copy of this packet.
  LtiLtChannelPacket clone() => LtiLtChannelPacket(
        tag: tag,
        user: user?.clone(),
      );
}

/// Mechanism for BFM credit returns.
class LtiCreditPacket extends SequenceItem {
  /// Credit return value.
  final int credit;

  /// Constructor.
  LtiCreditPacket({
    required this.credit,
  });

  /// Creates a copy of this packet.
  LtiCreditPacket clone() => LtiCreditPacket(
        credit: credit,
      );
}
