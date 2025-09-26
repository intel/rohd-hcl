// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi5_mixins.dart
// Definitions for AXI-5 interface functional subsets.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

// TODO: parity check signals...

/// Mixin for request signaling on AXI-5.
mixin Axi5RequestSignals on Axi5BaseInterface {
  /// Width of the address bus.
  int get addrWidth;

  /// Width of LEN signal.
  int get lenWidth;

  /// Width of the SIZE signal.
  int get sizeWidth;

  /// Width of the BURST signal.
  int get burstWidth;

  /// Width of the QOS signal.
  int get qosWidth;

  /// The address of the first transfer in a transaction.
  ///
  /// Width is equal to [addrWidth].
  Logic get addr => port('${prefix}ADDR');

  /// Length, the exact number of data transfers in a transaction.
  ///
  /// Width is equal to [lenWidth].
  Logic? get len => tryPort('${prefix}LEN');

  /// Size, the number of bytes in each data transfer in a transaction.
  ///
  /// Width is equal to [sizeWidth].
  Logic? get size => tryPort('${prefix}SIZE');

  /// Burst type, indicates how address changes between
  /// each transfer in a transaction.
  ///
  /// Width is equal to [burstWidth].
  Logic? get burst => tryPort('${prefix}BURST');

  /// Quality of service identifier for a transaction.
  ///
  /// Width is equal to [qosWidth].
  Logic? get qos => tryPort('${prefix}QOS');

  /// Helper to instantiate ACE specific request ports.
  @protected
  void makeRequestPorts() {
    setPorts([
      Logic.port('${prefix}ADDR', addrWidth),
      if (lenWidth > 0) Logic.port('${prefix}LEN', lenWidth),
      if (sizeWidth > 0) Logic.port('${prefix}SIZE', sizeWidth),
      if (burstWidth > 0) Logic.port('${prefix}BURST', burstWidth),
      if (qosWidth > 0) Logic.port('${prefix}QOS', qosWidth),
    ], [
      PairDirection.fromProvider,
    ]);
  }
}

/// Mixin for data signaling on AXI-5.
mixin Axi5DataSignals on Axi5BaseInterface {
  /// Width of the transaction data bus.
  int get dataWidth;

  /// Controls the presence of last which is an optional port
  /// for multi burst transactions.
  bool get useLast;

  /// Width of the strobe bus for data.
  int get strbWidth;

  /// Controls the presence of POISON signal.
  bool get usePoison;

  /// Transaction data.
  ///
  /// Width is equal to [dataWidth].
  Logic get data => port('${prefix}DATA');

  /// Indicates whether this is the last data transfer in a transaction.
  ///
  /// Width is always 1.
  Logic? get last => tryPort('${prefix}LAST');

  /// Write strobes, indicate which byte lanes hold valid data.
  ///
  /// Width is equal to [strbWidth].
  Logic? get strb => tryPort('${prefix}STRB');

  /// Indicator of data corruption on a given chunk.
  ///
  /// Width is equal to [ceil(dataWidth/64)].
  Logic? get poison => tryPort('${prefix}POISON');

  /// Helper to instantiate ACE specific request ports.
  @protected
  void makeDataPorts() {
    setPorts([
      Logic.port('${prefix}DATA', dataWidth),
      if (useLast) Logic.port('${prefix}LAST'),
      if (strbWidth > 0) Logic.port('${prefix}STRB', strbWidth),
      if (usePoison) Logic.port('${prefix}POISON', (dataWidth / 64).ceil())
    ], [
      if (main) PairDirection.fromProvider,
      if (!main) PairDirection.fromConsumer,
    ]);
  }
}

/// Mixin for response signaling on AXI-5.
mixin Axi5ResponseSignals on Axi5BaseInterface {
  /// Width of the RESP signal.
  int get respWidth;

  /// Include the BUSY signal.
  bool get useBusy;

  /// Read response, indicates the status of a read transfer.
  ///
  /// Width is equal to [respWidth].
  Logic? get resp => tryPort('${prefix}RESP');

  /// Busy indicator.
  ///
  /// Width is always 2 if present.
  Logic? get busy => tryPort('${prefix}BUSY');

  /// Helper to instantiate ACE specific request ports.
  @protected
  void makeResponsePorts() {
    setPorts([
      if (respWidth > 0) Logic.port('${prefix}RESP', respWidth),
      if (useBusy) Logic.port('${prefix}BUSY', 2),
    ], [
      PairDirection.fromConsumer,
    ]);
  }
}

/// Mixin for memory attribute signaling on AXI-5.
mixin Axi5MemoryAttributeSignals on Axi5BaseInterface {
  /// Width of the CACHE signal.
  int get cacheWidth;

  /// Width of the REGION signal.
  int get regionWidth;

  /// Width of MECID field.
  int get mecIdWidth;

  /// Indicates how a transaction is required to progress through a system.
  ///
  /// Width is equal to [cacheWidth].
  Logic? get cache => tryPort('${prefix}CACHE');

  /// Region indicator for a transaction.
  ///
  /// Width is equal to [regionWidth].
  Logic? get region => tryPort('${prefix}REGION');

  /// Memory encryption ID of transaction.
  ///
  /// Width is equal to [mecIdWidth].
  Logic? get mecId => tryPort('${prefix}MECID');

  /// Helper to instantiate ACE specific request ports.
  @protected
  void makeMemoryAttributePorts() {
    setPorts([
      if (cacheWidth > 0) Logic.port('${prefix}CACHE', cacheWidth),
      if (regionWidth > 0) Logic.port('${prefix}REGION', regionWidth),
      if (mecIdWidth > 0) Logic.port('${prefix}MECID', mecIdWidth),
    ], [
      PairDirection.fromProvider,
    ]);
  }
}

/// Mixin for ID related signaling on AXI-5.
mixin Axi5IdSignals on Axi5BaseInterface {
  /// Width of the ID signal.
  int get idWidth;

  /// Should the IDUNQ field be present.
  bool get useIdUnq;

  /// Identification tag for transaction.
  ///
  /// Width is equal to [idWidth].
  Logic? get id => tryPort('${prefix}ID');

  /// Coherency barrier.
  ///
  /// Width is always 1.
  Logic? get idUnq => tryPort('${prefix}IDUNQ');

  /// Helper to instantiate ACE specific request ports.
  @protected
  void makeIdPorts() {
    setPorts([
      if (idWidth > 0) Logic.port('${prefix}ID', idWidth),
      if (idWidth > 0 && useIdUnq) Logic.port('${prefix}IDUNQ'),
    ], [
      if (main) PairDirection.fromProvider,
      if (!main) PairDirection.fromConsumer,
    ]);
  }
}

/// Mixin for Protection related signaling on AXI-5.
mixin Axi5ProtSignals on Axi5BaseInterface {
  /// Width of the prot field is fixed for Axi5.
  int get protWidth;

  /// Realm Management Extension support.
  bool get rmeSupport;

  /// Inst/priv support.
  bool get instPrivPresent;

  /// Width of PAS field.
  int get pasWidth;

  /// Protection attributes of a transaction.
  ///
  /// Width is equal to [protWidth].
  Logic? get prot => tryPort('${prefix}PROT');

  /// Non-Secure Extension.
  ///
  /// Width is always 1.
  Logic? get nse => tryPort('${prefix}NSE');

  /// Privileged versus unprivileged access.
  ///
  /// Width is always 1.
  Logic? get priv => tryPort('${prefix}PRIV');

  /// Instruction versus data access.
  ///
  /// Width is always 1.
  Logic? get inst => tryPort('${prefix}INST');

  /// Physical address space of transaction.
  ///
  /// Width is equal to [pasWidth].
  Logic? get pas => tryPort('${prefix}PAS');

  /// Helper to instantiate ACE specific request ports.
  @protected
  void makeProtPorts() {
    setPorts([
      if (protWidth > 0) Logic.port('${prefix}PROT', protWidth),
      if (protWidth > 0 && rmeSupport) Logic.port('${prefix}NSE'),
      if (instPrivPresent) Logic.port('${prefix}PRIV'),
      if (instPrivPresent) Logic.port('${prefix}INST'),
      if (pasWidth > 0) Logic.port('${prefix}PAS', pasWidth),
    ], [
      PairDirection.fromProvider,
    ]);
  }
}

/// Mixin for Stash related signaling on AXI-5.
mixin Axi5StashSignals on Axi5BaseInterface {
  /// Width of the DOMAIN signal.
  int get domainWidth;

  /// Stash NID present.
  bool get stashNidPresent;

  /// Stash Logical PID present.
  bool get stashLPidPresent;

  /// Width of the CMO signal.
  int get cmoWidth;

  /// Domain for requests.
  ///
  /// Width is equal to [domainWidth].
  Logic? get domain => tryPort('${prefix}DOMAIN');

  /// Stash Node ID.
  ///
  /// Width is fixed to be 11 if present.
  Logic? get stashNid => tryPort('${prefix}STASHNID');

  /// Stash Node ID enable.
  ///
  /// Width is always 1.
  Logic? get stashNidEn => tryPort('${prefix}STASHNIDEN');

  /// Stash Logical Processor ID.
  ///
  /// Width is fixed to be 5 if present.
  Logic? get stashLPid => tryPort('${prefix}STASHLPID');

  /// Stash Logical Processor ID enable.
  ///
  /// Width is always 1.
  Logic? get stashLPidEn => tryPort('${prefix}STASHLPIDEN');

  /// Cache maintenance operation.
  ///
  /// Width is equal to [cmoWidth].
  Logic? get cmo => tryPort('${prefix}CMO');

  /// Helper to instantiate ACE specific request ports.
  @protected
  void makeStashPorts() {
    setPorts([
      if (domainWidth > 0) Logic.port('${prefix}DOMAIN', domainWidth),
      if (stashNidPresent) Logic.port('${prefix}STASHNID', 11),
      if (stashNidPresent) Logic.port('${prefix}STASHNIDEN'),
      if (stashLPidPresent) Logic.port('${prefix}STASHLPID', 5),
      if (stashLPidPresent) Logic.port('${prefix}STASHLPIDEN'),
      if (cmoWidth > 0) Logic.port('${prefix}CMO', cmoWidth),
    ], [
      PairDirection.fromProvider,
    ]);
  }
}

/// Mixin for Memory partition and tagging related signaling on AXI-5.
mixin Axi5MemPartTagSignals on Axi5BaseInterface {
  /// Width of MPAM signal.
  int get mpamWidth;

  /// Support tagging feature.
  bool get useTagging;

  /// Memory system resource partioning and monitoring.
  ///
  /// Width is equal to [mpamWidth].
  Logic? get mpam => tryPort('${prefix}MPAM');

  /// Tag operation.
  ///
  /// Width is always 2 if present.
  Logic? get tagOp => tryPort('${prefix}TAGOP');

  /// Helper to instantiate ACE specific request ports.
  @protected
  void makeMemPartTagPorts() {
    setPorts([
      if (mpamWidth > 0) Logic.port('${prefix}MPAM', mpamWidth),
      if (useTagging) Logic.port('${prefix}TAGOP', 2),
    ], [
      PairDirection.fromProvider,
    ]);
  }
}

/// Mixin for Memory partition and tagging related signaling on AXI-5.
mixin Axi5MemRespDataTagSignals on Axi5BaseInterface {
  /// Use TAG signal.
  bool get useTag;

  /// Width of data bus.
  int get tagDataWidth;

  /// Use TAGUPDATE signal.
  bool get useTagUpdate;

  /// Use TAGMATCH signal.
  bool get useTagMatch;

  /// Tag.
  ///
  /// Width is equal to ceil(dataWidth/128)*4.
  Logic? get tag => tryPort('${prefix}TAG');

  /// Tags to update.
  ///
  /// Width is equal to ceil(dataWidth/128).
  Logic? get tagUpdate => tryPort('${prefix}TAGUPDATE');

  /// Results of tag comparisons.
  ///
  /// Width is equal to 2 if present.
  Logic? get tagMatch => tryPort('${prefix}TAGMATCH');

  /// Completion response.
  ///
  /// Width is always 1.
  Logic? get comp => tryPort('${prefix}COMP');

  /// Persist response.
  ///
  /// Width is always 1.
  Logic? get persist => tryPort('${prefix}PERSIST');

  /// Helper to instantiate ACE specific request ports.
  @protected
  void makeRespDataTagPorts() {
    setPorts([
      Logic.port('${prefix}TAG', (tagDataWidth / 128).ceil() * 4),
    ], [
      PairDirection.fromConsumer,
    ]);
    if (main) {
      setPorts([
        if (useTag) Logic.port('${prefix}TAG', (tagDataWidth / 128).ceil() * 4),
        if (useTagUpdate)
          Logic.port('${prefix}TAGUPDATE', (tagDataWidth / 128).ceil()),
      ], [
        PairDirection.fromProvider,
      ]);
    } else {
      setPorts([
        if (useTag) Logic.port('${prefix}TAG', (tagDataWidth / 128).ceil() * 4),
        if (useTagMatch) Logic.port('${prefix}TAGMATCH', 2),
        if (useTagMatch) Logic.port('${prefix}COMP'),
        if (useTagMatch) Logic.port('${prefix}PERSIST'),
      ], [
        PairDirection.fromConsumer,
      ]);
    }
  }
}

/// Mixin for Debug related signaling on AXI-5.
mixin Axi5DebugSignals on Axi5BaseInterface {
  /// Trace present.
  bool get tracePresent;

  /// Loopback signal width.
  int get loopWidth;

  /// Trace signal.
  ///
  /// Width is always 1.
  Logic? get trace => tryPort('${prefix}TRACE');

  /// Loopback signal.
  ///
  /// Width is equal to [loopWidth].
  Logic? get loop => tryPort('${prefix}LOOP');

  /// Helper to instantiate ACE specific request ports.
  @protected
  void makeDebugPorts() {
    setPorts([
      if (tracePresent) Logic.port('${prefix}TRACE'),
      if (loopWidth > 0) Logic.port('${prefix}LOOP', loopWidth),
    ], [
      if (main) PairDirection.fromProvider,
      if (!main) PairDirection.fromConsumer,
    ]);
  }
}

/// Mixin for MMU related signaling on AXI-5.
mixin Axi5MmuSignals on Axi5BaseInterface {
  /// Version of the untranslated transactions spec (1-4).
  int get untranslatedTransVersion;

  /// Secure stream ID width.
  int get secSidWidth;

  /// Stream ID width.
  int get sidWidth;

  /// Substream ID width.
  int get ssidWidth;

  /// Flow support.
  bool get useFlow;

  /// GDI support.
  bool get supportGdi;

  /// RME and PAS support.
  bool get supportRmeAndPasMmu;

  /// MMU signal qualifier.
  ///
  /// Width is always 1.
  Logic? get mmuValid => tryPort('${prefix}MMUVALID');

  /// Secure stream ID.
  ///
  /// Width is equal to [secSidWidth].
  Logic? get mmuSecSid => tryPort('${prefix}MMUSECSID');

  /// Stream ID.
  ///
  /// Width is equal to [sidWidth].
  Logic? get mmuSid => tryPort('${prefix}MMUSID');

  /// Substream ID valid.
  ///
  /// Width is always 1.
  Logic? get mmuSsidV => tryPort('${prefix}MMUSSIDV');

  /// Substream ID.
  ///
  /// Width is equal to [ssidWidth].
  Logic? get mmuSsid => tryPort('${prefix}MMUSSID');

  /// Address translated indicator.
  ///
  /// Width is always 1.
  Logic? get mmuAtSt => tryPort('${prefix}MMUATST');

  /// SMMU flow type.
  ///
  /// Width is always 2.
  Logic? get mmuFlow => tryPort('${prefix}MMUFLOW');

  /// Physical address space unknown.
  ///
  /// Width is always 1.
  Logic? get mmuPasUnknown => tryPort('${prefix}MMUPASUNKNOWN');

  /// Protected mode indicator.
  ///
  /// Width is always 1.
  Logic? get mmuPm => tryPort('${prefix}MMUPM');

  /// Helper to instantiate ACE specific request ports.
  @protected
  void makeMmuPorts() {
    setPorts([
      if (untranslatedTransVersion >= 3) Logic.port('${prefix}MMUVALID'),
      if (secSidWidth > 0) Logic.port('${prefix}MMUSECSID', secSidWidth),
      if (sidWidth > 0) Logic.port('${prefix}MMUSID'),
      if (ssidWidth > 0) Logic.port('${prefix}MMUSSIDV'),
      if (ssidWidth > 0) Logic.port('${prefix}MMUSSID'),
      if (untranslatedTransVersion == 1 && useFlow)
        Logic.port('${prefix}MMUATST'),
      if (untranslatedTransVersion > 1 && useFlow)
        Logic.port('${prefix}MMUFLOW', 2),
      if (untranslatedTransVersion == 4 && supportRmeAndPasMmu)
        Logic.port('${prefix}MMUPASUNKNOWN'),
      if (untranslatedTransVersion == 4 && supportGdi)
        Logic.port('${prefix}MMUPM'),
    ], [
      PairDirection.fromProvider,
    ]);
  }
}

/// Mixin for additional qualifier signaling on AXI-5.
mixin Axi5QualifierSignals on Axi5BaseInterface {
  /// Control for using NSAID.
  bool get useNsaId;

  /// Control for using PBHA.
  bool get usePbha;

  /// Subsystem ID width.
  int get subSysIdWidth;

  /// ACT width.
  int get actWidth;

  /// Non-secure access ID.
  ///
  /// Width is always 4 if present.
  Logic? get nsaId => tryPort('${prefix}NSAID');

  /// Page based HW attributes.
  ///
  /// Width is always 4 if present.
  Logic? get pbha => tryPort('${prefix}PBHA');

  /// Subsystem ID.
  ///
  /// Width is equal to [subSysIdWidth].
  Logic? get subSysId => tryPort('${prefix}SUBSYSID');

  /// Arm Compression Technology valid.
  ///
  /// Width is always 1.
  Logic? get actV => tryPort('${prefix}ACTV');

  /// Arm Compression Technology.
  ///
  /// Width is equal to [actWidth].
  Logic? get act => tryPort('${prefix}ACT');

  /// Helper to instantiate ACE specific request ports.
  @protected
  void makeQualifierPorts() {
    setPorts([
      if (useNsaId) Logic.port('${prefix}NSAID', 4),
      if (usePbha) Logic.port('${prefix}PBHA', 4),
      if (subSysIdWidth > 0) Logic.port('${prefix}SUBSYSID'),
      if (actWidth > 0) Logic.port('${prefix}ACTV'),
      if (actWidth > 0) Logic.port('${prefix}ACT', actWidth),
    ], [
      PairDirection.fromProvider,
    ]);
  }
}

/// Mixin for chunk signaling on AXI-5.
mixin Axi5ChunkSignals on Axi5BaseInterface {
  /// Width of CHUNKNUM signal.
  int get chunkNumWidth;

  /// Width of CHUNKSTRB.
  int get chunkStrbWidth;

  /// Chunking enabled for this transaction.
  ///
  /// Width is always 1.
  Logic? get chunkEn => tryPort('${prefix}CHUNKEN');

  /// Indicates that a given data chunk is valid.
  ///
  /// Width is always 1.
  Logic? get chunkV => tryPort('${prefix}CHUNKV');

  /// Indicates the chunk number being transferred.
  ///
  /// Width is equal to [chunkNumWidth].
  Logic? get chunkNum => tryPort('${prefix}CHUNKNUM');

  /// Indicates the chunks that are valid for this transfer.
  ///
  /// Width is equal to [chunkStrbWidth].
  Logic? get chunkStrb => tryPort('${prefix}CHUNKSTRB');

  /// Helper to instantiate ACE specific request ports.
  @protected
  void makeChunkPorts() {
    if (main) {
      setPorts([
        Logic.port('${prefix}CHUNKEN'),
      ], [
        PairDirection.fromProvider,
      ]);
    } else {
      setPorts([
        Logic.port('${prefix}CHUNKV'),
        if (chunkNumWidth > 0) Logic.port('${prefix}CHUNKNUM', chunkNumWidth),
        if (chunkStrbWidth > 0) Logic.port('${prefix}CHUNKSTRB', chunkStrbWidth)
      ], [
        PairDirection.fromConsumer,
      ]);
    }
  }
}

/// Mixin for atomic signaling on AXI-5.
mixin Axi5AtomicSignals on Axi5BaseInterface {
  /// Controls the presence of LOCK signal.
  bool get useLock;

  /// Width of the ATOP signal.
  int get atOpWidth;

  /// Provides information about atomic characteristics of a transaction.
  ///
  /// Width is always 1.
  Logic? get lock => tryPort('${prefix}LOCK');

  /// Atomic operation type for a transaction.
  ///
  /// Width is equal to [atOpWidth].
  Logic? get atOp => tryPort('${prefix}ATOP');

  /// Helper to instantiate ACE specific request ports.
  @protected
  void makeAtomicPorts() {
    setPorts([
      if (useLock) Logic.port('${prefix}LOCK'),
      if (atOpWidth > 0) Logic.port('${prefix}ATOP', atOpWidth),
    ], [
      PairDirection.fromProvider,
    ]);
  }
}

/// Mixin for opcode signaling on AXI-5.
mixin Axi5OpcodeSignals on Axi5BaseInterface {
  /// Width of the SNOOP signal.
  int get snpWidth;

  /// Opcode for snoop requests.
  ///
  /// Width is equal to [snpWidth].
  Logic? get snoop => tryPort('${prefix}SNOOP');

  /// Helper to instantiate ACE specific request ports.
  @protected
  void makeOpcodePorts() {
    setPorts([
      if (snpWidth > 0) Logic.port('${prefix}SNOOP', snpWidth),
    ], [
      PairDirection.fromProvider,
    ]);
  }
}

/// Mixin for user signaling on AXI-5.
mixin Axi5UserSignals on Axi5BaseInterface {
  /// Width of the USER signal.
  int get userWidth;

  /// User extension.
  ///
  /// Width is equal to [userWidth].
  Logic? get user => tryPort('${prefix}USER');

  /// Helper to instantiate ACE specific request ports.
  @protected
  void makeUserPorts() {
    setPorts([
      if (userWidth > 0) Logic.port('${prefix}USER', userWidth),
    ], [
      if (main) PairDirection.fromProvider,
      if (!main) PairDirection.fromConsumer,
    ]);
  }
}
