// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi5_mixin_structures.dart
// Packet substructures corresponding to all AXI-5 mixins.
//
// 2025 September
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

/// This corresponds to mixin Axi5RequestSignals from axi5_mixins.dart.
class Axi5RequestSignalsStruct {
  /// The address of the first transfer in a transaction.
  /// Width is equal to addrWidth.
  final int addr;

  /// Length, the exact number of data transfers in a transaction.
  /// Width is equal to lenWidth.
  final int? len;

  /// Size, the number of bytes in each data transfer in a transaction.
  /// Width is equal to sizeWidth.
  final int? size;

  /// Burst type, indicates how address changes between each transfer in a transaction.
  /// Width is equal to burstWidth.
  final int? burst;

  /// Quality of service identifier for a transaction.
  /// Width is equal to qosWidth.
  final int? qos;

  /// Constructor
  Axi5RequestSignalsStruct({
    required this.addr,
    this.len,
    this.size,
    this.burst,
    this.qos,
  });
}

/// This corresponds to mixin Axi5DataSignals from axi5_mixins.dart.
class Axi5DataSignalsStruct {
  /// Transaction data.
  /// Width is equal to dataWidth.
  final int data;

  /// Indicates whether this is the last data transfer in a transaction.
  /// Width is always 1.
  final bool? last;

  /// Write strobes, indicate which byte lanes hold valid data.
  /// Width is equal to strbWidth.
  final int? strb;

  /// Indicator of data corruption on a given chunk.
  /// Width is equal to ceil(dataWidth/64).
  final int? poison;

  /// Constructor
  Axi5DataSignalsStruct({
    required this.data,
    this.last,
    this.strb,
    this.poison,
  });
}

/// This corresponds to mixin Axi5ResponseSignals from axi5_mixins.dart.
class Axi5ResponseSignalsStruct {
  /// Read response, indicates the status of a read transfer.
  /// Width is equal to respWidth.
  final int? resp;

  /// Busy indicator.
  /// Width is always 2 if present.
  final bool? busy;

  /// Constructor
  Axi5ResponseSignalsStruct({
    this.resp,
    this.busy,
  });
}

/// This corresponds to mixin Axi5MemoryAttributeSignals from axi5_mixins.dart.
class Axi5MemoryAttributeSignalsStruct {
  /// Indicates how a transaction is required to progress through a system.
  /// Width is equal to cacheWidth.
  final int? cache;

  /// Region indicator for a transaction.
  /// Width is equal to regionWidth.
  final int? region;

  /// Memory encryption ID of transaction.
  /// Width is equal to mecIdWidth.
  final int? mecId;

  /// Constructor
  Axi5MemoryAttributeSignalsStruct({
    this.cache,
    this.region,
    this.mecId,
  });
}

/// This corresponds to mixin Axi5IdSignals from axi5_mixins.dart.
class Axi5IdSignalsStruct {
  /// Identification tag for transaction.
  /// Width is equal to idWidth.
  final int? id;

  /// Coherency barrier.
  /// Width is always 1.
  final bool? idUnq;

  /// Constructor
  Axi5IdSignalsStruct({
    this.id,
    this.idUnq,
  });
}

/// This corresponds to mixin Axi5ProtSignals from axi5_mixins.dart.
class Axi5ProtSignalsStruct {
  /// Protection attributes of a transaction.
  /// Width is equal to protWidth.
  final int? prot;

  /// Non-Secure Extension.
  /// Width is always 1.
  final bool? nse;

  /// Privileged versus unprivileged access.
  /// Width is always 1.
  final bool? priv;

  /// Instruction versus data access.
  /// Width is always 1.
  final bool? inst;

  /// Physical address space of transaction.
  /// Width is equal to pasWidth.
  final int? pas;

  /// Constructor
  Axi5ProtSignalsStruct({
    this.prot,
    this.nse,
    this.priv,
    this.inst,
    this.pas,
  });
}

/// This corresponds to mixin Axi5StashSignals from axi5_mixins.dart.
class Axi5StashSignalsStruct {
  /// Domain for requests.
  /// Width is equal to domainWidth.
  final int? domain;

  /// Stash Node ID.
  /// Width is fixed to be 11 if present.
  final int? stashNid;

  /// Stash Node ID enable.
  /// Width is always 1.
  final bool? stashNidEn;

  /// Stash Logical Processor ID.
  /// Width is fixed to be 5 if present.
  final int? stashLPid;

  /// Stash Logical Processor ID enable.
  /// Width is always 1.
  final bool? stashLPidEn;

  /// Cache maintenance operation.
  /// Width is equal to cmoWidth.
  final int? cmo;

  /// Constructor
  Axi5StashSignalsStruct({
    this.domain,
    this.stashNid,
    this.stashNidEn,
    this.stashLPid,
    this.stashLPidEn,
    this.cmo,
  });
}

/// This corresponds to mixin Axi5MemPartTagSignals from axi5_mixins.dart.
class Axi5MemPartTagSignalsStruct {
  /// Memory system resource partioning and monitoring.
  /// Width is equal to mpamWidth.
  final int? mpam;

  /// Tag operation.
  /// Width is always 2 if present.
  final int? tagOp;

  /// Constructor
  Axi5MemPartTagSignalsStruct({
    this.mpam,
    this.tagOp,
  });
}

/// This corresponds to mixin Axi5MemRespDataTagSignals from axi5_mixins.dart.
class Axi5MemRespDataTagSignalsStruct {
  /// Tag.
  /// Width is equal to ceil(dataWidth/128)*4.
  final int? tag;

  /// Tags to update.
  /// Width is equal to ceil(dataWidth/128).
  final int? tagUpdate;

  /// Results of tag comparisons.
  /// Width is equal to 2 if present.
  final int? tagMatch;

  /// Completion response.
  /// Width is always 1.
  final bool? comp;

  /// Persist response.
  /// Width is always 1.
  final bool? persist;

  /// Constructor
  Axi5MemRespDataTagSignalsStruct({
    this.tag,
    this.tagUpdate,
    this.tagMatch,
    this.comp,
    this.persist,
  });
}

/// This corresponds to mixin Axi5DebugSignals from axi5_mixins.dart.
class Axi5DebugSignalsStruct {
  /// Trace signal.
  /// Width is always 1.
  final bool? trace;

  /// Loopback signal.
  /// Width is equal to loopWidth.
  final int? loop;

  /// Constructor
  Axi5DebugSignalsStruct({
    this.trace,
    this.loop,
  });
}

/// This corresponds to mixin Axi5MmuSignals from axi5_mixins.dart.
class Axi5MmuSignalsStruct {
  /// MMU signal qualifier.
  /// Width is always 1.
  final bool? mmuValid;

  /// Secure stream ID.
  /// Width is equal to secSidWidth.
  final int? mmuSecSid;

  /// Stream ID.
  /// Width is equal to sidWidth.
  final int? mmuSid;

  /// Substream ID valid.
  /// Width is always 1.
  final bool? mmuSsidV;

  /// Substream ID.
  /// Width is equal to ssidWidth.
  final int? mmuSsid;

  /// Address translated indicator.
  /// Width is always 1.
  final bool? mmuAtSt;

  /// SMMU flow type.
  /// Width is always 2.
  final int? mmuFlow;

  /// Physical address space unknown.
  /// Width is always 1.
  final bool? mmuPasUnknown;

  /// Protected mode indicator.
  /// Width is always 1.
  final bool? mmuPm;

  /// Constructor
  Axi5MmuSignalsStruct({
    this.mmuValid,
    this.mmuSecSid,
    this.mmuSid,
    this.mmuSsidV,
    this.mmuSsid,
    this.mmuAtSt,
    this.mmuFlow,
    this.mmuPasUnknown,
    this.mmuPm,
  });
}

/// This corresponds to mixin Axi5QualifierSignals from axi5_mixins.dart.
class Axi5QualifierSignalsStruct {
  /// Non-secure access ID.
  /// Width is always 4 if present.
  final int? nsaId;

  /// Page based HW attributes.
  /// Width is always 4 if present.
  final int? pbha;

  /// Subsystem ID.
  /// Width is equal to subSysIdWidth.
  final int? subSysId;

  /// Arm Compression Technology valid.
  /// Width is always 1.
  final bool? actV;

  /// Arm Compression Technology.
  /// Width is equal to actWidth.
  final int? act;

  /// Constructor
  Axi5QualifierSignalsStruct({
    this.nsaId,
    this.pbha,
    this.subSysId,
    this.actV,
    this.act,
  });
}

/// This corresponds to mixin Axi5ChunkSignals from axi5_mixins.dart.
class Axi5ChunkSignalsStruct {
  /// Chunking enabled for this transaction.
  /// Width is always 1.
  final bool? chunkEn;

  /// Indicates that a given data chunk is valid.
  /// Width is always 1.
  final bool? chunkV;

  /// Indicates the chunk number being transferred.
  /// Width is equal to chunkNumWidth.
  final int? chunkNum;

  /// Indicates the chunks that are valid for this transfer.
  /// Width is equal to chunkStrbWidth.
  final int? chunkStrb;

  /// Constructor
  Axi5ChunkSignalsStruct({
    this.chunkEn,
    this.chunkV,
    this.chunkNum,
    this.chunkStrb,
  });
}

/// This corresponds to mixin Axi5AtomicSignals from axi5_mixins.dart.
class Axi5AtomicSignalsStruct {
  /// Provides information about atomic characteristics of a transaction.
  /// Width is always 1.
  final bool? lock;

  /// Atomic operation type for a transaction.
  /// Width is equal to atOpWidth.
  final int? atOp;

  /// Constructor
  Axi5AtomicSignalsStruct({
    this.lock,
    this.atOp,
  });
}

/// This corresponds to mixin Axi5OpcodeSignals from axi5_mixins.dart.
class Axi5OpcodeSignalsStruct {
  /// Opcode for snoop requests.
  /// Width is equal to snpWidth.
  final int? snoop;

  /// Constructor
  Axi5OpcodeSignalsStruct({
    this.snoop,
  });
}

/// This corresponds to mixin Axi5UserSignals from axi5_mixins.dart.
class Axi5UserSignalsStruct {
  /// User extension.
  /// Width is equal to userWidth.
  final int? user;

  /// Constructor
  Axi5UserSignalsStruct({
    this.user,
  });
}
