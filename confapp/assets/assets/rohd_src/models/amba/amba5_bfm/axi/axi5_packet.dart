// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi5_packet.dart
// Packet for AXI5 interface.
//
// 2025 September
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A request packet on an AXI5 AW channel interface.
class Axi5AwChannelPacket extends SequenceItem implements Trackable {
  /// User signals
  final Axi5UserSignalsStruct? user;

  /// ID signals
  final Axi5IdSignalsStruct? id;

  /// Request signals
  final Axi5RequestSignalsStruct request;

  /// Protection signals
  final Axi5ProtSignalsStruct prot;

  /// Stash signals
  final Axi5StashSignalsStruct? stash;

  /// Opcode signals
  final Axi5OpcodeSignalsStruct? opcode;

  /// Memory attribute signals
  final Axi5MemoryAttributeSignalsStruct memAttr;

  /// Debug signals
  final Axi5DebugSignalsStruct? debug;

  /// MMU signals
  final Axi5MmuSignalsStruct? mmu;

  /// Qualifier signals
  final Axi5QualifierSignalsStruct? qual;

  /// Atomic signals
  final Axi5AtomicSignalsStruct? atomic;

  /// Tag signals
  final Axi5MemPartTagSignalsStruct? tag;

  /// Constructor
  Axi5AwChannelPacket({
    required this.request,
    required this.prot,
    required this.memAttr,
    this.user,
    this.id,
    this.stash,
    this.debug,
    this.mmu,
    this.qual,
    this.atomic,
    this.tag,
    this.opcode,
  });

  /// A [Future] that completes once the the read has been completed.
  Future<void> get completed => _completer.future;
  final Completer<void> _completer = Completer<void>();

  /// Called by a completer when a transfer is completed.
  void complete() {
    _completer.complete();
  }

  /// Creates a copy of this packet.
  Axi5AwChannelPacket clone() => Axi5AwChannelPacket(
        request: request.clone(),
        prot: prot.clone(),
        memAttr: memAttr.clone(),
        user: user?.clone(),
        id: id?.clone(),
        stash: stash?.clone(),
        debug: debug?.clone(),
        mmu: mmu?.clone(),
        qual: qual?.clone(),
        atomic: atomic?.clone(),
        tag: tag?.clone(),
        opcode: opcode?.clone(),
      );

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case Axi5AwChannelTracker.timeField:
        return Simulator.time.toString();
      case Axi5AwChannelTracker.idField:
        return id?.id?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.idUnqField:
        return id?.idUnq?.toString() ?? '';
      case Axi5AwChannelTracker.addrField:
        return request.addr.toRadixString(16);
      case Axi5AwChannelTracker.lenField:
        return request.len?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.sizeField:
        return request.size?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.burstField:
        return request.burst?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.qosField:
        return request.qos?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.protField:
        return prot.prot?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.nseField:
        return prot.nse?.toString() ?? '';
      case Axi5AwChannelTracker.privField:
        return prot.priv?.toString() ?? '';
      case Axi5AwChannelTracker.instField:
        return prot.inst?.toString() ?? '';
      case Axi5AwChannelTracker.pasField:
        return prot.pas?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.cacheField:
        return memAttr.cache?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.regionField:
        return memAttr.region?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.userField:
        return user?.user?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.domainField:
        return stash?.domain?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.stashNidField:
        return stash?.stashNid?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.stashNidEnField:
        return stash?.stashNidEn?.toString() ?? '';
      case Axi5AwChannelTracker.stashLPidField:
        return stash?.stashLPid?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.stashLPidEnField:
        return stash?.stashLPidEn?.toString() ?? '';
      case Axi5AwChannelTracker.cmoField:
        return stash?.cmo?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.opcodeField:
        return opcode?.snoop?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.atomicField:
        return atomic?.toString() ?? '';
      case Axi5AwChannelTracker.traceField:
        return debug?.trace?.toString() ?? '';
      case Axi5AwChannelTracker.loopField:
        return debug?.loop?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.mmuValidField:
        return mmu?.mmuValid?.toString() ?? '';
      case Axi5AwChannelTracker.mmuSecSidField:
        return mmu?.mmuSecSid?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.mmuSidField:
        return mmu?.mmuSid?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.mmuSsidVField:
        return mmu?.mmuSsidV?.toString() ?? '';
      case Axi5AwChannelTracker.mmuSsidField:
        return mmu?.mmuSsid?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.mmuAtStField:
        return mmu?.mmuAtSt?.toString() ?? '';
      case Axi5AwChannelTracker.mmuFlowField:
        return mmu?.mmuFlow?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.mmuPasUnknownField:
        return mmu?.mmuPasUnknown?.toString() ?? '';
      case Axi5AwChannelTracker.mmuPmField:
        return mmu?.mmuPm?.toString() ?? '';
      case Axi5AwChannelTracker.nsaIdField:
        return qual?.nsaId?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.pbhaField:
        return qual?.pbha?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.subSysIdField:
        return qual?.subSysId?.toRadixString(16) ?? '';
      case Axi5AwChannelTracker.actVField:
        return qual?.actV?.toString() ?? '';
      case Axi5AwChannelTracker.actField:
        return qual?.act?.toRadixString(16) ?? '';
      default:
        return '';
    }
  }
}

/// A request packet on an AXI5 AR channel interface.
class Axi5ArChannelPacket extends SequenceItem implements Trackable {
  /// User signals
  final Axi5UserSignalsStruct? user;

  /// ID signals
  final Axi5IdSignalsStruct? id;

  /// Request signals
  final Axi5RequestSignalsStruct request;

  /// Protection signals
  final Axi5ProtSignalsStruct prot;

  /// Memory attribute signals
  final Axi5MemoryAttributeSignalsStruct memAttr;

  /// Debug signals
  final Axi5DebugSignalsStruct? debug;

  /// MMU signals
  final Axi5MmuSignalsStruct? mmu;

  /// Qualifier signals
  final Axi5QualifierSignalsStruct? qual;

  /// Atomic signals
  final Axi5AtomicSignalsStruct? atomic;

  /// Tag signals
  final Axi5MemPartTagSignalsStruct? tag;

  /// Chunk signals
  final Axi5ChunkSignalsStruct? chunk;

  /// Opcode signals
  final Axi5OpcodeSignalsStruct? opcode;

  /// Constructor
  Axi5ArChannelPacket({
    required this.request,
    required this.prot,
    required this.memAttr,
    this.user,
    this.id,
    this.debug,
    this.mmu,
    this.qual,
    this.atomic,
    this.tag,
    this.chunk,
    this.opcode,
  });

  /// A [Future] that completes once the the read has been completed.
  Future<void> get completed => _completer.future;
  final Completer<void> _completer = Completer<void>();

  /// Called by a completer when a transfer is completed.
  void complete() {
    _completer.complete();
  }

  /// Creates a copy of this packet.
  Axi5ArChannelPacket clone() => Axi5ArChannelPacket(
        request: request.clone(),
        prot: prot.clone(),
        memAttr: memAttr.clone(),
        user: user?.clone(),
        id: id?.clone(),
        debug: debug?.clone(),
        mmu: mmu?.clone(),
        qual: qual?.clone(),
        atomic: atomic?.clone(),
        tag: tag?.clone(),
        chunk: chunk?.clone(),
        opcode: opcode?.clone(),
      );

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case Axi5ArChannelTracker.timeField:
        return Simulator.time.toString();
      case Axi5ArChannelTracker.idField:
        return id?.id?.toRadixString(16) ?? '';
      case Axi5ArChannelTracker.idUnqField:
        return id?.idUnq?.toString() ?? '';
      case Axi5ArChannelTracker.addrField:
        return request.addr.toRadixString(16);
      case Axi5ArChannelTracker.lenField:
        return request.len?.toRadixString(16) ?? '';
      case Axi5ArChannelTracker.sizeField:
        return request.size?.toRadixString(16) ?? '';
      case Axi5ArChannelTracker.burstField:
        return request.burst?.toRadixString(16) ?? '';
      case Axi5ArChannelTracker.protField:
        return prot.prot?.toRadixString(16) ?? '';
      case Axi5ArChannelTracker.nseField:
        return prot.nse?.toString() ?? '';
      case Axi5ArChannelTracker.privField:
        return prot.priv?.toString() ?? '';
      case Axi5ArChannelTracker.instField:
        return prot.inst?.toString() ?? '';
      case Axi5ArChannelTracker.pasField:
        return prot.pas?.toRadixString(16) ?? '';
      case Axi5ArChannelTracker.cacheField:
        return memAttr.cache?.toRadixString(16) ?? '';
      case Axi5ArChannelTracker.regionField:
        return memAttr.region?.toRadixString(16) ?? '';
      case Axi5ArChannelTracker.mecIdField:
        return memAttr.mecId?.toRadixString(16) ?? '';
      case Axi5ArChannelTracker.qosField:
        return request.qos?.toRadixString(16) ?? '';
      case Axi5ArChannelTracker.userField:
        return user?.user?.toRadixString(16) ?? '';
      case Axi5ArChannelTracker.opcodeField:
        return opcode?.snoop?.toRadixString(16) ?? '';
      case Axi5ArChannelTracker.atomicField:
        return atomic?.toString() ?? '';
      case Axi5ArChannelTracker.traceField:
        return debug?.trace?.toString() ?? '';
      case Axi5ArChannelTracker.loopField:
        return debug?.loop?.toRadixString(16) ?? '';
      default:
        return '';
    }
  }
}

/// A data packet on an AXI5 W channel interface.
class Axi5WChannelPacket extends SequenceItem implements Trackable {
  /// Data beats.
  final List<Axi5DataSignalsStruct> data;

  /// Tag signals
  final Axi5MemRespDataTagSignalsStruct? tag;

  /// Debug signals
  final Axi5DebugSignalsStruct? debug;

  /// User signals
  final Axi5UserSignalsStruct? user;

  /// Constructor
  Axi5WChannelPacket({
    required this.data,
    this.tag,
    this.debug,
    this.user,
  });

  /// A [Future] that completes once the the read has been completed.
  Future<void> get completed => _completer.future;
  final Completer<void> _completer = Completer<void>();

  /// Called by a completer when a transfer is completed.
  void complete() {
    _completer.complete();
  }

  /// Creates a copy of this packet.
  Axi5WChannelPacket clone() => Axi5WChannelPacket(
        data: data.map((e) => e.clone()).toList(),
        tag: tag?.clone(),
        debug: debug?.clone(),
        user: user?.clone(),
      );

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case Axi5WChannelTracker.timeField:
        return Simulator.time.toString();
      case Axi5WChannelTracker.dataField:
        return data.isNotEmpty
            ? data.map((e) => e.data.toRadixString(16)).join(',')
            : '';
      case Axi5WChannelTracker.lastField:
        return data.isNotEmpty
            ? data.map((e) => e.last?.toString() ?? '1').join(',')
            : '';
      case Axi5WChannelTracker.strbField:
        return data.isNotEmpty
            ? data.map((e) => e.strb?.toRadixString(16) ?? 'N/A').join(',')
            : '';
      case Axi5WChannelTracker.poisonField:
        return data.isNotEmpty
            ? data.map((e) => e.poison?.toRadixString(16) ?? 'N/A').join(',')
            : '';
      case Axi5WChannelTracker.tagField:
        return tag?.tag?.toRadixString(16) ?? '';
      case Axi5WChannelTracker.tagUpdateField:
        return tag?.tagUpdate?.toRadixString(16) ?? '';
      case Axi5WChannelTracker.tagMatchField:
        return tag?.tagMatch?.toRadixString(16) ?? '';
      case Axi5WChannelTracker.compField:
        return tag?.comp?.toString() ?? '';
      case Axi5WChannelTracker.persistField:
        return tag?.persist?.toString() ?? '';
      case Axi5WChannelTracker.traceField:
        return debug?.trace?.toString() ?? '';
      case Axi5WChannelTracker.loopField:
        return debug?.loop?.toRadixString(16) ?? '';
      case Axi5WChannelTracker.userField:
        return user?.user?.toRadixString(16) ?? '';
      default:
        return '';
    }
  }
}

/// A response packet on an AXI5 R channel interface.
class Axi5RChannelPacket extends SequenceItem implements Trackable {
  /// User signals
  final Axi5UserSignalsStruct? user;

  /// Data signals
  final List<Axi5DataSignalsStruct> data;

  /// ID signals
  final Axi5IdSignalsStruct? id;

  /// Tag signals
  final Axi5MemRespDataTagSignalsStruct? tag;

  /// Debug signals
  final Axi5DebugSignalsStruct? debug;

  /// Chunk signals
  final Axi5ChunkSignalsStruct? chunk;

  /// Response signals
  final Axi5ResponseSignalsStruct? response;

  /// Constructor
  Axi5RChannelPacket({
    required this.data,
    this.user,
    this.id,
    this.tag,
    this.debug,
    this.chunk,
    this.response,
  });

  /// A [Future] that completes once the the read has been completed.
  Future<void> get completed => _completer.future;
  final Completer<void> _completer = Completer<void>();

  /// Called by a completer when a transfer is completed.
  void complete() {
    _completer.complete();
  }

  /// Creates a copy of this packet.
  Axi5RChannelPacket clone() => Axi5RChannelPacket(
        data: data.map((e) => e.clone()).toList(),
        user: user?.clone(),
        id: id?.clone(),
        tag: tag?.clone(),
        debug: debug?.clone(),
        chunk: chunk?.clone(),
        response: response?.clone(),
      );

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case Axi5RChannelTracker.timeField:
        return Simulator.time.toString();
      case Axi5RChannelTracker.userField:
        return user?.user?.toRadixString(16) ?? '';
      case Axi5RChannelTracker.dataField:
        return data.isNotEmpty
            ? data.map((e) => e.data.toRadixString(16)).join(',')
            : '';
      case Axi5RChannelTracker.lastField:
        return data.isNotEmpty
            ? data.map((e) => e.last?.toString() ?? '1').join(',')
            : '';
      case Axi5RChannelTracker.strbField:
        return data.isNotEmpty
            ? data.map((e) => e.strb?.toRadixString(16) ?? 'N/A').join(',')
            : '';
      case Axi5RChannelTracker.poisonField:
        return data.isNotEmpty
            ? data.map((e) => e.poison?.toRadixString(16) ?? 'N/A').join(',')
            : '';
      case Axi5RChannelTracker.idField:
        return id?.id?.toRadixString(16) ?? '';
      case Axi5RChannelTracker.idUnqField:
        return id?.idUnq?.toString() ?? '';
      case Axi5RChannelTracker.tagField:
        return tag?.tag?.toRadixString(16) ?? '';
      case Axi5RChannelTracker.tagUpdateField:
        return tag?.tagUpdate?.toRadixString(16) ?? '';
      case Axi5RChannelTracker.tagMatchField:
        return tag?.tagMatch?.toRadixString(16) ?? '';
      case Axi5RChannelTracker.compField:
        return tag?.comp?.toString() ?? '';
      case Axi5RChannelTracker.persistField:
        return tag?.persist?.toString() ?? '';
      case Axi5RChannelTracker.traceField:
        return debug?.trace?.toString() ?? '';
      case Axi5RChannelTracker.loopField:
        return debug?.loop?.toRadixString(16) ?? '';
      case Axi5RChannelTracker.respField:
        return response?.resp?.toRadixString(16) ?? '';
      case Axi5RChannelTracker.busyField:
        return response?.busy?.toString() ?? '';
      default:
        return '';
    }
  }
}

/// A response packet on an AXI5 B channel interface.
class Axi5BChannelPacket extends SequenceItem implements Trackable {
  /// User signals
  final Axi5UserSignalsStruct? user;

  /// ID signals
  final Axi5IdSignalsStruct? id;

  /// Tag signals
  final Axi5MemRespDataTagSignalsStruct? tag;

  /// Debug signals
  final Axi5DebugSignalsStruct? debug;

  /// Response signals
  final Axi5ResponseSignalsStruct response;

  /// Constructor
  Axi5BChannelPacket({
    required this.response,
    this.user,
    this.id,
    this.tag,
    this.debug,
  });

  /// A [Future] that completes once the the read has been completed.
  Future<void> get completed => _completer.future;
  final Completer<void> _completer = Completer<void>();

  /// Called by a completer when a transfer is completed.
  void complete() {
    _completer.complete();
  }

  /// Creates a copy of this packet.
  Axi5BChannelPacket clone() => Axi5BChannelPacket(
        response: response.clone(),
        user: user?.clone(),
        id: id?.clone(),
        tag: tag?.clone(),
        debug: debug?.clone(),
      );

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case Axi5BChannelTracker.timeField:
        return Simulator.time.toString();
      case Axi5BChannelTracker.userField:
        return user?.user?.toRadixString(16) ?? '';
      case Axi5BChannelTracker.idField:
        return id?.id?.toRadixString(16) ?? '';
      case Axi5BChannelTracker.idUnqField:
        return id?.idUnq?.toString() ?? '';
      case Axi5BChannelTracker.tagField:
        return tag?.tag?.toRadixString(16) ?? '';
      case Axi5BChannelTracker.tagUpdateField:
        return tag?.tagUpdate?.toRadixString(16) ?? '';
      case Axi5BChannelTracker.tagMatchField:
        return tag?.tagMatch?.toRadixString(16) ?? '';
      case Axi5BChannelTracker.compField:
        return tag?.comp?.toString() ?? '';
      case Axi5BChannelTracker.persistField:
        return tag?.persist?.toString() ?? '';
      case Axi5BChannelTracker.traceField:
        return debug?.trace?.toString() ?? '';
      case Axi5BChannelTracker.loopField:
        return debug?.loop?.toRadixString(16) ?? '';
      case Axi5BChannelTracker.respField:
        return response.resp?.toRadixString(16) ?? '';
      case Axi5BChannelTracker.busyField:
        return response.busy?.toString() ?? '';
      default:
        return '';
    }
  }
}

/// A packet on an AXI5 AC channel interface.
class Axi5AcChannelPacket extends SequenceItem implements Trackable {
  /// Debug signals
  final Axi5DebugSignalsStruct? debug;

  /// Address.
  final int addr;

  /// MVID extension
  final int vmidExt;

  /// Constructor
  Axi5AcChannelPacket({
    required this.addr,
    required this.vmidExt,
    this.debug,
  });

  /// A [Future] that completes once the the read has been completed.
  Future<void> get completed => _completer.future;
  final Completer<void> _completer = Completer<void>();

  /// Called by a completer when a transfer is completed.
  void complete() {
    _completer.complete();
  }

  /// Creates a copy of this packet.
  Axi5AcChannelPacket clone() => Axi5AcChannelPacket(
        addr: addr,
        vmidExt: vmidExt,
        debug: debug?.clone(),
      );

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case Axi5AcChannelTracker.timeField:
        return Simulator.time.toString();
      case Axi5AcChannelTracker.traceField:
        // debug.trace
        return debug?.trace?.toString() ?? '';
      case Axi5AcChannelTracker.loopField:
        // debug.loop
        return debug?.loop?.toRadixString(16) ?? '';
      default:
        return '';
    }
  }
}

/// A packet on an AXI5 CR channel interface.
class Axi5CrChannelPacket extends SequenceItem implements Trackable {
  /// Debug signals
  final Axi5DebugSignalsStruct? debug;

  /// Constructor
  Axi5CrChannelPacket({
    this.debug,
  });

  /// A [Future] that completes once the the read has been completed.
  Future<void> get completed => _completer.future;
  final Completer<void> _completer = Completer<void>();

  /// Called by a completer when a transfer is completed.
  void complete() {
    _completer.complete();
  }

  /// Creates a copy of this packet.
  Axi5CrChannelPacket clone() => Axi5CrChannelPacket(
        debug: debug?.clone(),
      );

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case Axi5CrChannelTracker.timeField:
        return Simulator.time.toString();
      case Axi5CrChannelTracker.traceField:
        // debug.trace
        return debug?.trace?.toString() ?? '';
      case Axi5CrChannelTracker.loopField:
        // debug.loop
        return debug?.loop?.toRadixString(16) ?? '';
      default:
        return '';
    }
  }
}
