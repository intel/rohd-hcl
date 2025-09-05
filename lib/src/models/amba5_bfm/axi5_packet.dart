// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi5_packet.dart
// Packet for AXI5 interface.
//
// 2025 September
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';

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

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
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

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
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

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
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

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
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

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
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
  final int mvidExt;

  /// Constructor
  Axi5AcChannelPacket({
    required this.addr,
    required this.mvidExt,
    this.debug,
  });

  /// A [Future] that completes once the the read has been completed.
  Future<void> get completed => _completer.future;
  final Completer<void> _completer = Completer<void>();

  /// Called by a completer when a transfer is completed.
  void complete() {
    _completer.complete();
  }

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
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

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      default:
        return '';
    }
  }
}
