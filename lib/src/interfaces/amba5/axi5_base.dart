// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi5_base.dart
// Base classes for AXI-5 interfaces and associated variants.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A top-level Interface from which all of AXI-5 can derive.
abstract class Axi5BaseInterface extends PairInterface {
  /// Prefix string for port declarations
  final String prefix;

  /// Helper to control which direction the signals should be coming from.
  final bool main;

  /// The transaction is valid.
  ///
  /// Width is always 1.
  Logic get valid => port('${prefix}VALID');

  /// Constructor.
  Axi5BaseInterface({
    required this.prefix,
    required this.main,
  }) {
    setPorts([
      Logic.port('${prefix}VALID'),
    ], [
      if (main) PairDirection.fromProvider,
      if (!main) PairDirection.fromConsumer,
    ]);
  }
}

/// Next level in the hierarchy to handle the flow control schemes.
abstract class Axi5TransportInterface extends Axi5BaseInterface {
  /// Should we use crediting.
  final bool useCrediting;

  /// Include shared crediting.
  final bool sharedCredits;

  /// Number of resource planes.
  final int numRp;

  /// Transfer is ready.
  ///
  /// Width is always 1.
  Logic? get ready => tryPort('${prefix}READY');

  /// Transfer might occur in the following cycle.
  ///
  /// Width is always 1.
  Logic? get pending => tryPort('${prefix}PENDING');

  /// Indicator of resource plane.
  ///
  /// Width is equal to log2(numRp).
  Logic? get rp => tryPort('${prefix}RP');

  /// Transfer using a shared credit.
  ///
  /// Width is always 1.
  Logic? get sharedCrd => tryPort('${prefix}SHAREDCRD');

  /// Give one credit on the given resource plane.
  ///
  /// Width is always 1.
  Logic? get crdt => tryPort('${prefix}CRDT');

  /// Give one shared credit.
  ///
  /// Width is always 1.
  Logic? get crdtSh => tryPort('${prefix}CRDTSH');

  /// Constructor.
  Axi5TransportInterface({
    required super.prefix,
    required super.main,
    this.useCrediting = false,
    this.sharedCredits = false,
    this.numRp = 0,
  }) {
    setPorts([
      if (!useCrediting) Logic.port('${prefix}READY'),
      if (useCrediting) Logic.port('${prefix}CRDT'),
      if (useCrediting && sharedCredits) Logic.port('${prefix}CRDTSH')
    ], [
      if (main) PairDirection.fromConsumer,
      if (!main) PairDirection.fromProvider,
    ]);

    setPorts([
      if (useCrediting) Logic.port('${prefix}PENDING'),
      if (useCrediting && numRp > 0) Logic.port('${prefix}RP', log2Ceil(numRp)),
      if (useCrediting && sharedCredits) Logic.port('${prefix}SHAREDCRD')
    ], [
      if (main) PairDirection.fromProvider,
      if (!main) PairDirection.fromConsumer,
    ]);
  }
}

/// A config object for constructing an AXI5 AW channel.
abstract class Axi5BaseAwChannelConfig {
  /// The width of the user-defined signal in bits.
  final int userWidth;

  /// The width of the ID signal in bits.
  final int idWidth;

  /// Indicates whether the unique ID feature is used.
  final bool useIdUnq;

  /// The width of the address bus in bits.
  final int addrWidth;

  /// The width of the LEN signal in bits.
  final int lenWidth;

  /// Controls the presence of lock which is an optional port.
  final bool useLock;

  /// The width of the SIZE signal in bits.
  final int sizeWidth;

  /// The width of the BURST signal in bits.
  final int burstWidth;

  /// The width of the CACHE signal in bits.
  final int cacheWidth;

  /// The width of the PROT signal in bits.
  final int protWidth;

  /// The width of the QOS signal in bits.
  final int qosWidth;

  /// The width of the REGION signal in bits.
  final int regionWidth;

  /// Realm Management Extension support.
  final bool rmeSupport;

  /// Inst/priv support.
  final bool instPrivPresent;

  /// The width of PAS signal in bits.
  final int pasWidth;

  /// The width of MECID signal in bits.
  final int mecIdWidth;

  /// The width of the ATOP signal in bits.
  final int atOpWidth;

  /// The width of the SNOOP signal in bits.
  final int snpWidth;

  /// Trace present.
  final bool tracePresent;

  /// Loopback signal width.
  final int loopWidth;

  /// Width of MPAM signal.
  final int mpamWidth;

  /// Support tagging feature.
  final bool useTagging;

  /// Untranslated transactions version.
  final int untranslatedTransVersion;

  /// Secure stream ID width.
  final int secSidWidth;

  /// Stream ID width.
  final int sidWidth;

  /// Substream ID width.
  final int ssidWidth;

  /// Control for using NSAID.
  final bool useNsaId;

  /// Control for using PBHA.
  final bool usePbha;

  /// Subsystem ID width.
  final int subSysIdWidth;

  /// ACT width.
  final int actWidth;

  /// Width of the DOMAIN signal.
  final int domainWidth;

  /// Stash NID present.
  final bool stashNidPresent;

  /// Stash Logical PID present.
  final bool stashLPidPresent;

  /// Width of the CMO signal.
  final int cmoWidth;

  /// Flow support.
  final bool useFlow;

  /// GDI support.
  final bool supportGdi;

  /// RME and PAS support.
  final bool supportRmeAndPasMmu;

  /// Constructor.
  Axi5BaseAwChannelConfig({
    this.userWidth = 0,
    this.idWidth = 0,
    this.useIdUnq = false,
    this.addrWidth = 0,
    this.lenWidth = 0,
    this.useLock = false,
    this.sizeWidth = 0,
    this.burstWidth = 0,
    this.cacheWidth = 0,
    this.protWidth = 0,
    this.qosWidth = 0,
    this.regionWidth = 0,
    this.rmeSupport = false,
    this.instPrivPresent = false,
    this.pasWidth = 0,
    this.mecIdWidth = 0,
    this.atOpWidth = 0,
    this.snpWidth = 0,
    this.tracePresent = false,
    this.loopWidth = 0,
    this.mpamWidth = 0,
    this.useTagging = false,
    this.secSidWidth = 0,
    this.sidWidth = 0,
    this.ssidWidth = 0,
    this.useNsaId = false,
    this.usePbha = false,
    this.actWidth = 0,
    this.subSysIdWidth = 0,
    this.domainWidth = 0,
    this.stashNidPresent = false,
    this.stashLPidPresent = false,
    this.cmoWidth = 0,
    this.useFlow = false,
    this.supportRmeAndPasMmu = false,
    this.supportGdi = false,
    this.untranslatedTransVersion = 4,
  });
}

/// Basis for all possible AW channels.
class Axi5AwChannelInterface extends Axi5TransportInterface
    with
        Axi5UserSignals,
        Axi5IdSignals,
        Axi5RequestSignals,
        Axi5ProtSignals,
        Axi5StashSignals,
        Axi5OpcodeSignals,
        Axi5MemoryAttributeSignals,
        Axi5DebugSignals,
        Axi5MmuSignals,
        Axi5QualifierSignals,
        Axi5AtomicSignals,
        Axi5MemPartTagSignals {
  /// Enable ID signal mixin
  final bool idMixInEnable;

  /// Enable Stash signal mixin
  final bool stashMixInEnable;

  /// Enable MMU signal mixin
  final bool mmuMixInEnable;

  /// Enable Qualifier signal mixin
  final bool qualMixInEnable;

  /// Enable Atomic signal mixin
  final bool atomicMixInEnable;

  /// Enable Tag signal mixin
  final bool tagMixInEnable;

  /// Enable Debug signal mixin
  final bool debugMixInEnable;

  /// Enable User signal mixin
  final bool userMixInEnable;

  /// Enable Opcode signal mixin
  final bool opcodeMixInEnable;

  @override
  final int userWidth;
  @override
  final int idWidth;
  @override
  final bool useIdUnq;
  @override
  final int addrWidth;
  @override
  final int lenWidth;
  @override
  final bool useLock;
  @override
  final int sizeWidth;
  @override
  final int burstWidth;
  @override
  final int cacheWidth;
  @override
  final int protWidth;
  @override
  final int qosWidth;
  @override
  final int regionWidth;
  @override
  final bool rmeSupport;
  @override
  final bool instPrivPresent;
  @override
  final int pasWidth;
  @override
  final int mecIdWidth;
  @override
  final int atOpWidth;
  @override
  final int snpWidth;
  @override
  final bool tracePresent;
  @override
  final int loopWidth;
  @override
  final int mpamWidth;
  @override
  final bool useTagging;
  @override
  final int untranslatedTransVersion;
  @override
  final int secSidWidth;
  @override
  final int sidWidth;
  @override
  final int ssidWidth;
  @override
  final bool useNsaId;
  @override
  final bool usePbha;
  @override
  final int subSysIdWidth;
  @override
  final int actWidth;
  @override
  final int domainWidth;
  @override
  final bool stashNidPresent;
  @override
  final bool stashLPidPresent;
  @override
  final int cmoWidth;
  @override
  final bool useFlow;
  @override
  final bool supportGdi;
  @override
  final bool supportRmeAndPasMmu;

  /// Constructor.
  Axi5AwChannelInterface({
    required Axi5BaseAwChannelConfig config,
    super.useCrediting = false,
    super.sharedCredits = false,
    super.numRp = 0,
    this.atomicMixInEnable = false,
    this.debugMixInEnable = false,
    this.idMixInEnable = false,
    this.userMixInEnable = false,
    this.mmuMixInEnable = false,
    this.qualMixInEnable = false,
    this.stashMixInEnable = false,
    this.tagMixInEnable = false,
    this.opcodeMixInEnable = false,
  })  : userWidth = config.userWidth,
        idWidth = config.idWidth,
        useIdUnq = config.useIdUnq,
        addrWidth = config.addrWidth,
        lenWidth = config.lenWidth,
        useLock = config.useLock,
        sizeWidth = config.sizeWidth,
        burstWidth = config.burstWidth,
        cacheWidth = config.cacheWidth,
        protWidth = config.protWidth,
        qosWidth = config.qosWidth,
        regionWidth = config.regionWidth,
        rmeSupport = config.rmeSupport,
        instPrivPresent = config.instPrivPresent,
        pasWidth = config.pasWidth,
        mecIdWidth = config.mecIdWidth,
        atOpWidth = config.atOpWidth,
        snpWidth = config.snpWidth,
        loopWidth = config.loopWidth,
        tracePresent = config.tracePresent,
        mpamWidth = config.mpamWidth,
        useTagging = config.useTagging,
        secSidWidth = config.secSidWidth,
        sidWidth = config.sidWidth,
        ssidWidth = config.ssidWidth,
        useNsaId = config.useNsaId,
        usePbha = config.usePbha,
        subSysIdWidth = config.subSysIdWidth,
        actWidth = config.actWidth,
        domainWidth = config.domainWidth,
        stashNidPresent = config.stashNidPresent,
        stashLPidPresent = config.stashLPidPresent,
        cmoWidth = config.cmoWidth,
        supportGdi = config.supportGdi,
        useFlow = config.useFlow,
        supportRmeAndPasMmu = config.supportRmeAndPasMmu,
        untranslatedTransVersion = config.untranslatedTransVersion,
        super(prefix: 'AW', main: true) {
    makeRequestPorts();
    makeProtPorts();
    makeMemoryAttributePorts();
    if (userMixInEnable) {
      makeUserPorts();
    }
    if (idMixInEnable) {
      makeIdPorts();
    }
    if (stashMixInEnable) {
      makeStashPorts();
    }
    if (debugMixInEnable) {
      makeDebugPorts();
    }
    if (mmuMixInEnable) {
      makeMmuPorts();
    }
    if (qualMixInEnable) {
      makeQualifierPorts();
    }
    if (atomicMixInEnable) {
      makeAtomicPorts();
    }
    if (tagMixInEnable) {
      makeMemPartTagPorts();
    }
    if (opcodeMixInEnable) {
      makeOpcodePorts();
    }
  }

  /// Copy Constructor.
  @override
  Axi5AwChannelInterface clone() => Axi5AwChannelInterface(
        config: Axi5AwChannelConfig(
          userWidth: userWidth,
          idWidth: idWidth,
          useIdUnq: useIdUnq,
          tracePresent: tracePresent,
          loopWidth: loopWidth,
          addrWidth: addrWidth,
          lenWidth: lenWidth,
          useLock: useLock,
          snpWidth: snpWidth,
          rmeSupport: rmeSupport,
          instPrivPresent: instPrivPresent,
          pasWidth: pasWidth,
          mecIdWidth: mecIdWidth,
          mpamWidth: mpamWidth,
          useTagging: useTagging,
          secSidWidth: secSidWidth,
          sidWidth: sidWidth,
          ssidWidth: ssidWidth,
          useNsaId: useNsaId,
          usePbha: usePbha,
          actWidth: actWidth,
          subSysIdWidth: subSysIdWidth,
          useFlow: useFlow,
          supportGdi: supportGdi,
          supportRmeAndPasMmu: supportRmeAndPasMmu,
          domainWidth: domainWidth,
          stashNidPresent: stashNidPresent,
          stashLPidPresent: stashLPidPresent,
          cmoWidth: cmoWidth,
          untranslatedTransVersion: untranslatedTransVersion,
        ),
        useCrediting: useCrediting,
        sharedCredits: sharedCredits,
        numRp: numRp,
        userMixInEnable: userMixInEnable,
        idMixInEnable: idMixInEnable,
        tagMixInEnable: tagMixInEnable,
        debugMixInEnable: debugMixInEnable,
        atomicMixInEnable: atomicMixInEnable,
        mmuMixInEnable: mmuMixInEnable,
        qualMixInEnable: qualMixInEnable,
        opcodeMixInEnable: opcodeMixInEnable,
        stashMixInEnable: stashMixInEnable,
      );
}

/// A config object for constructing an AXI5 AR channel.
abstract class Axi5BaseArChannelConfig {
  /// The width of the user-defined signal in bits.
  final int userWidth;

  /// The width of the ID signal in bits.
  final int idWidth;

  /// Indicates whether the unique ID feature is used.
  final bool useIdUnq;

  /// The width of the address bus in bits.
  final int addrWidth;

  /// The width of the LEN signal in bits.
  final int lenWidth;

  /// Controls the presence of lock which is an optional port.
  final bool useLock;

  /// The width of the SIZE signal in bits.
  final int sizeWidth;

  /// The width of the BURST signal in bits.
  final int burstWidth;

  /// The width of the CACHE signal in bits.
  final int cacheWidth;

  /// The width of the PROT signal in bits.
  final int protWidth;

  /// The width of the QOS signal in bits.
  final int qosWidth;

  /// The width of the REGION signal in bits.
  final int regionWidth;

  /// The width of the BAR signal in bits.
  final int barWidth;

  /// Should a poison bit be included.
  final bool usePoison;

  /// Realm Management Extension support.
  final bool rmeSupport;

  /// Inst/priv support.
  final bool instPrivPresent;

  /// The width of PAS signal in bits.
  final int pasWidth;

  /// The width of MECID signal in bits.
  final int mecIdWidth;

  /// Data chunking enabled.
  final bool useChunk;

  /// The width of the ATOP signal in bits.
  final int atopWidth;

  /// The width of the CHUNKNUM signal in bits.
  final int chunkNumWidth;

  /// The width of the CHUNKSTRB signal in bits.
  final int chunkStrbWidth;

  /// Trace present.
  final bool tracePresent;

  /// Loopback signal width.
  final int loopWidth;

  /// Width of MPAM signal.
  final int mpamWidth;

  /// Support tagging feature.
  final bool useTagging;

  /// Untranslated transactions version.
  final int untranslatedTransVersion;

  /// Secure stream ID width.
  final int secSidWidth;

  /// Stream ID width.
  final int sidWidth;

  /// Substream ID width.
  final int ssidWidth;

  /// Snoop width.
  final int snpWidth;

  /// Control for using NSAID.
  final bool useNsaId;

  /// Control for using PBHA.
  final bool usePbha;

  /// Subsystem ID width.
  final int subSysIdWidth;

  /// ACT width.
  final int actWidth;

  /// Flow support.
  final bool useFlow;

  /// GDI support.
  final bool supportGdi;

  /// RME and PAS support.
  final bool supportRmeAndPasMmu;

  /// Constructor.
  Axi5BaseArChannelConfig({
    this.userWidth = 0,
    this.idWidth = 0,
    this.useIdUnq = false,
    this.addrWidth = 0,
    this.lenWidth = 0,
    this.useLock = false,
    this.sizeWidth = 0,
    this.burstWidth = 0,
    this.cacheWidth = 0,
    this.protWidth = 0,
    this.qosWidth = 0,
    this.regionWidth = 0,
    this.barWidth = 0,
    this.usePoison = false,
    this.rmeSupport = false,
    this.instPrivPresent = false,
    this.pasWidth = 0,
    this.mecIdWidth = 0,
    this.useChunk = false,
    this.atopWidth = 0,
    this.chunkNumWidth = 0,
    this.chunkStrbWidth = 0,
    this.tracePresent = false,
    this.loopWidth = 0,
    this.mpamWidth = 0,
    this.useTagging = false,
    this.secSidWidth = 0,
    this.sidWidth = 0,
    this.ssidWidth = 0,
    this.snpWidth = 0,
    this.useNsaId = false,
    this.usePbha = false,
    this.actWidth = 0,
    this.subSysIdWidth = 0,
    this.useFlow = false,
    this.supportGdi = false,
    this.supportRmeAndPasMmu = false,
    this.untranslatedTransVersion = 4,
  });
}

/// Basis for all possible AR channels.
class Axi5ArChannelInterface extends Axi5TransportInterface
    with
        Axi5UserSignals,
        Axi5IdSignals,
        Axi5RequestSignals,
        Axi5ProtSignals,
        Axi5MemoryAttributeSignals,
        Axi5DebugSignals,
        Axi5MmuSignals,
        Axi5QualifierSignals,
        Axi5AtomicSignals,
        Axi5MemPartTagSignals,
        Axi5ChunkSignals,
        Axi5OpcodeSignals {
  /// Enable ID signal mixin
  final bool idMixInEnable;

  /// Enable MMU signal mixin
  final bool mmuMixInEnable;

  /// Enable Qualifier signal mixin
  final bool qualMixInEnable;

  /// Enable Atomic signal mixin
  final bool atomicMixInEnable;

  /// Enable Tag signal mixin
  final bool tagMixInEnable;

  /// Enable Debug signal mixin
  final bool debugMixInEnable;

  /// Enable User signal mixin
  final bool userMixInEnable;

  /// Enable Chunk signal mixin
  final bool chunkMixInEnable;

  /// Enable Opcode signal mixin
  final bool opcodeMixInEnable;

  @override
  final int userWidth;
  @override
  final int idWidth;
  @override
  final bool useIdUnq;
  @override
  final int addrWidth;
  @override
  final int lenWidth;
  @override
  final bool useLock;
  @override
  final int sizeWidth;
  @override
  final int burstWidth;
  @override
  final int cacheWidth;
  @override
  final int protWidth;
  @override
  final int qosWidth;
  @override
  final int regionWidth;
  @override
  final bool rmeSupport;
  @override
  final bool instPrivPresent;
  @override
  final int pasWidth;
  @override
  final int mecIdWidth;
  @override
  final int atOpWidth;
  @override
  final int chunkNumWidth;
  @override
  final int chunkStrbWidth;
  @override
  final bool tracePresent;
  @override
  final int loopWidth;
  @override
  final int mpamWidth;
  @override
  final bool useTagging;
  @override
  final int untranslatedTransVersion;
  @override
  final int secSidWidth;
  @override
  final int sidWidth;
  @override
  final int ssidWidth;
  @override
  final int snpWidth;
  @override
  final bool useNsaId;
  @override
  final bool usePbha;
  @override
  final int subSysIdWidth;
  @override
  final int actWidth;
  @override
  final bool useFlow;
  @override
  final bool supportGdi;
  @override
  final bool supportRmeAndPasMmu;

  /// Constructor.
  Axi5ArChannelInterface({
    required Axi5BaseArChannelConfig config,
    super.useCrediting = false,
    super.sharedCredits = false,
    super.numRp = 0,
    this.atomicMixInEnable = false,
    this.debugMixInEnable = false,
    this.idMixInEnable = false,
    this.userMixInEnable = false,
    this.mmuMixInEnable = false,
    this.qualMixInEnable = false,
    this.tagMixInEnable = false,
    this.chunkMixInEnable = false,
    this.opcodeMixInEnable = false,
  })  : userWidth = config.userWidth,
        idWidth = config.idWidth,
        useIdUnq = config.useIdUnq,
        addrWidth = config.addrWidth,
        lenWidth = config.lenWidth,
        useLock = config.useLock,
        sizeWidth = config.sizeWidth,
        burstWidth = config.burstWidth,
        cacheWidth = config.cacheWidth,
        protWidth = config.protWidth,
        qosWidth = config.qosWidth,
        regionWidth = config.regionWidth,
        rmeSupport = config.rmeSupport,
        instPrivPresent = config.instPrivPresent,
        pasWidth = config.pasWidth,
        mecIdWidth = config.mecIdWidth,
        loopWidth = config.loopWidth,
        tracePresent = config.tracePresent,
        chunkNumWidth = config.chunkNumWidth,
        chunkStrbWidth = config.chunkStrbWidth,
        atOpWidth = config.atopWidth,
        mpamWidth = config.mpamWidth,
        useTagging = config.useTagging,
        secSidWidth = config.secSidWidth,
        sidWidth = config.sidWidth,
        ssidWidth = config.ssidWidth,
        snpWidth = config.snpWidth,
        useNsaId = config.useNsaId,
        usePbha = config.usePbha,
        subSysIdWidth = config.subSysIdWidth,
        actWidth = config.actWidth,
        useFlow = config.useFlow,
        supportGdi = config.supportGdi,
        supportRmeAndPasMmu = config.supportRmeAndPasMmu,
        untranslatedTransVersion = config.untranslatedTransVersion,
        super(prefix: 'AR', main: true) {
    makeRequestPorts();
    makeProtPorts();
    makeMemoryAttributePorts();
    if (userMixInEnable) {
      makeUserPorts();
    }
    if (idMixInEnable) {
      makeIdPorts();
    }
    if (debugMixInEnable) {
      makeDebugPorts();
    }
    if (mmuMixInEnable) {
      makeMmuPorts();
    }
    if (qualMixInEnable) {
      makeQualifierPorts();
    }
    if (atomicMixInEnable) {
      makeAtomicPorts();
    }
    if (tagMixInEnable) {
      makeMemPartTagPorts();
    }
    if (chunkMixInEnable) {
      makeChunkPorts();
    }
    if (opcodeMixInEnable) {
      makeOpcodePorts();
    }
  }

  /// Copy Constructor.
  @override
  Axi5ArChannelInterface clone() => Axi5ArChannelInterface(
        config: Axi5ArChannelConfig(
          userWidth: userWidth,
          idWidth: idWidth,
          useIdUnq: useIdUnq,
          tracePresent: tracePresent,
          loopWidth: loopWidth,
          chunkNumWidth: chunkNumWidth,
          chunkStrbWidth: chunkStrbWidth,
          addrWidth: addrWidth,
          lenWidth: lenWidth,
          useLock: useLock,
          snpWidth: snpWidth,
          rmeSupport: rmeSupport,
          instPrivPresent: instPrivPresent,
          pasWidth: pasWidth,
          mecIdWidth: mecIdWidth,
          atopWidth: atOpWidth,
          mpamWidth: mpamWidth,
          useTagging: useTagging,
          secSidWidth: secSidWidth,
          sidWidth: sidWidth,
          ssidWidth: ssidWidth,
          useNsaId: useNsaId,
          usePbha: usePbha,
          actWidth: actWidth,
          subSysIdWidth: subSysIdWidth,
          useFlow: useFlow,
          supportGdi: supportGdi,
          supportRmeAndPasMmu: supportRmeAndPasMmu,
          untranslatedTransVersion: untranslatedTransVersion,
        ),
        useCrediting: useCrediting,
        sharedCredits: sharedCredits,
        numRp: numRp,
        userMixInEnable: userMixInEnable,
        idMixInEnable: idMixInEnable,
        tagMixInEnable: tagMixInEnable,
        debugMixInEnable: debugMixInEnable,
        chunkMixInEnable: chunkMixInEnable,
        atomicMixInEnable: atomicMixInEnable,
        mmuMixInEnable: mmuMixInEnable,
        qualMixInEnable: qualMixInEnable,
        opcodeMixInEnable: opcodeMixInEnable,
      );
}

/// A config object for constructing an AXI5 W channel.
abstract class Axi5BaseWChannelConfig {
  /// The width of the user-defined signal in bits.
  final int userWidth;

  /// The width of the transaction data bus in bits.
  final int dataWidth;

  /// Controls the presence of last which is an optional port for multi burst transactions.
  final bool useLast;

  /// The width of the tag data signal in bits.
  final int tagDataWidth;

  /// Indicates whether the tag feature is used.
  final bool useTag;

  /// Indicates whether the tag update feature is used.
  final bool useTagUpdate;

  /// Indicates whether the tag match feature is used.
  final bool useTagMatch;

  /// Indicates whether trace functionality is present.
  final bool tracePresent;

  /// The width of the loop signal in bits.
  final int loopWidth;

  /// The width of the write strobe signal in bits.
  final int strbWidth;

  /// Indicates whether a poison bit is used.
  final bool usePoison;

  /// Constructor.
  Axi5BaseWChannelConfig({
    this.userWidth = 0,
    this.dataWidth = 0,
    this.useLast = false,
    this.tagDataWidth = 0,
    this.useTag = false,
    this.useTagUpdate = false,
    this.useTagMatch = false,
    this.tracePresent = false,
    this.loopWidth = 0,
    this.strbWidth = 0,
    this.usePoison = false,
  });
}

/// Basis for all possible W channels.
class Axi5WChannelInterface extends Axi5TransportInterface
    with
        Axi5DataSignals,
        Axi5MemRespDataTagSignals,
        Axi5DebugSignals,
        Axi5UserSignals {
  /// Enable Data signal mixin
  final bool dataMixInEnable;

  /// Enable Tag signal mixin
  final bool tagMixInEnable;

  /// Enable Debug signal mixin
  final bool debugMixInEnable;

  /// Enable User signal mixin
  final bool userMixInEnable;

  @override
  final int dataWidth;

  @override
  final bool useLast;

  @override
  final int tagDataWidth;

  @override
  final bool useTag;

  @override
  final bool useTagUpdate;

  @override
  final bool useTagMatch;

  @override
  final bool tracePresent;

  @override
  final int loopWidth;

  @override
  final int strbWidth;

  @override
  final int userWidth;

  @override
  final bool usePoison;

  /// Constructor.
  Axi5WChannelInterface({
    required Axi5BaseWChannelConfig config,
    super.useCrediting = false,
    super.sharedCredits = false,
    super.numRp = 0,
    this.dataMixInEnable = false,
    this.tagMixInEnable = false,
    this.debugMixInEnable = false,
    this.userMixInEnable = false,
  })  : dataWidth = config.dataWidth,
        useLast = config.useLast,
        tagDataWidth = config.tagDataWidth,
        useTag = config.useTag,
        useTagUpdate = config.useTagUpdate,
        useTagMatch = config.useTagMatch,
        tracePresent = config.tracePresent,
        loopWidth = config.loopWidth,
        strbWidth = config.strbWidth,
        userWidth = config.userWidth,
        usePoison = config.usePoison,
        super(prefix: 'W', main: true) {
    makeDataPorts();
    if (tagMixInEnable) {
      makeRespDataTagPorts();
    }
    if (debugMixInEnable) {
      makeDebugPorts();
    }
    if (userMixInEnable) {
      makeUserPorts();
    }
  }

  /// Copy Constructor.
  Axi5WChannelInterface clone() => Axi5WChannelInterface(
        config: Axi5WChannelConfig(
            userWidth: userWidth,
            useTag: useTag,
            tagDataWidth: tagDataWidth,
            useTagUpdate: useTagUpdate,
            useTagMatch: useTagMatch,
            tracePresent: tracePresent,
            loopWidth: loopWidth,
            dataWidth: dataWidth,
            useLast: useLast,
            usePoison: usePoison,
            strbWidth: strbWidth),
        useCrediting: useCrediting,
        sharedCredits: sharedCredits,
        numRp: numRp,
        userMixInEnable: userMixInEnable,
        tagMixInEnable: tagMixInEnable,
        debugMixInEnable: debugMixInEnable,
        dataMixInEnable: dataMixInEnable,
      );
}

/// A config object for constructing an AXI5 R channel.
abstract class Axi5BaseRChannelConfig {
  /// The width of the user-defined signal in bits.
  final int userWidth;

  /// The width of the transaction data bus in bits.
  final int dataWidth;

  /// The width of the ID signal in bits.
  final int idWidth;

  /// Indicates whether the unique ID feature is used.
  final bool useIdUnq;

  /// Indicates whether the tag feature is used.
  final bool useTag;

  /// The width of the tag data signal in bits.
  final int tagDataWidth;

  /// Indicates whether the tag update feature is used.
  final bool useTagUpdate;

  /// Indicates whether the tag match feature is used.
  final bool useTagMatch;

  /// Indicates whether trace functionality is present.
  final bool tracePresent;

  /// The width of the loop signal in bits.
  final int loopWidth;

  /// The width of the response signal in bits.
  final int respWidth;

  /// Indicates whether the busy signal is used.
  final bool useBusy;

  /// The width of the chunk number signal in bits.
  final int chunkNumWidth;

  /// The width of the chunk strobe signal in bits.
  final int chunkStrbWidth;

  /// Controls the presence of last which is an optional port for multi burst transactions.
  final bool useLast;

  /// The width of the write strobe signal in bits.
  final int strbWidth;

  /// Indicates whether a poison bit is used.
  final bool usePoison;

  /// Constructor.
  Axi5BaseRChannelConfig({
    this.userWidth = 0,
    this.dataWidth = 0,
    this.idWidth = 0,
    this.useIdUnq = false,
    this.useTag = false,
    this.tagDataWidth = 0,
    this.useTagUpdate = false,
    this.useTagMatch = false,
    this.tracePresent = false,
    this.loopWidth = 0,
    this.respWidth = 0,
    this.useBusy = false,
    this.chunkNumWidth = 0,
    this.chunkStrbWidth = 0,
    this.useLast = false,
    this.strbWidth = 0,
    this.usePoison = false,
  });
}

/// Basis for all possible R channels.
class Axi5RChannelInterface extends Axi5TransportInterface
    with
        Axi5UserSignals,
        Axi5DataSignals,
        Axi5IdSignals,
        Axi5MemRespDataTagSignals,
        Axi5DebugSignals,
        Axi5ChunkSignals,
        Axi5ResponseSignals {
  /// Enable User signal mixin
  final bool userMixInEnable;

  /// Enable Data signal mixin
  final bool dataMixInEnable;

  /// Enable ID signal mixin
  final bool idMixInEnable;

  /// Enable Tag signal mixin
  final bool tagMixInEnable;

  /// Enable Debug signal mixin
  final bool debugMixInEnable;

  /// Enable Chunk signal mixin
  final bool chunkMixInEnable;

  /// Enable Response signal mixin
  final bool responseMixInEnable;

  @override
  final int userWidth;

  @override
  final int dataWidth;

  @override
  final bool useLast;

  @override
  final int idWidth;

  @override
  final bool useIdUnq;

  @override
  final bool useTag;

  @override
  final int tagDataWidth;

  @override
  final bool useTagUpdate;

  @override
  final bool useTagMatch;

  @override
  final bool tracePresent;

  @override
  final int loopWidth;

  @override
  final int respWidth;

  @override
  final bool useBusy;

  @override
  final int chunkNumWidth;

  @override
  final int chunkStrbWidth;

  @override
  final int strbWidth;

  @override
  final bool usePoison;

  /// Constructor.
  Axi5RChannelInterface({
    required Axi5BaseRChannelConfig config,
    super.useCrediting = false,
    super.sharedCredits = false,
    super.numRp = 0,
    this.userMixInEnable = false,
    this.dataMixInEnable = false,
    this.idMixInEnable = false,
    this.tagMixInEnable = false,
    this.debugMixInEnable = false,
    this.chunkMixInEnable = false,
    this.responseMixInEnable = false,
  })  : userWidth = config.userWidth,
        dataWidth = config.dataWidth,
        useLast = config.useLast,
        idWidth = config.idWidth,
        useIdUnq = config.useIdUnq,
        useTag = config.useTag,
        tagDataWidth = config.tagDataWidth,
        useTagUpdate = config.useTagUpdate,
        useTagMatch = config.useTagMatch,
        tracePresent = config.tracePresent,
        loopWidth = config.loopWidth,
        respWidth = config.respWidth,
        useBusy = config.useBusy,
        chunkNumWidth = config.chunkNumWidth,
        chunkStrbWidth = config.chunkStrbWidth,
        strbWidth = 0,
        usePoison = config.usePoison,
        super(prefix: 'R', main: false) {
    makeDataPorts();
    makeResponsePorts();

    if (userMixInEnable) {
      makeUserPorts();
    }
    if (idMixInEnable) {
      makeIdPorts();
    }
    if (tagMixInEnable) {
      makeRespDataTagPorts();
    }
    if (debugMixInEnable) {
      makeDebugPorts();
    }
    if (chunkMixInEnable) {
      makeChunkPorts();
    }
  }

  /// Copy Constructor.
  Axi5RChannelInterface clone() => Axi5RChannelInterface(
      config: Axi5RChannelConfig(
          userWidth: userWidth,
          idWidth: idWidth,
          useIdUnq: useIdUnq,
          useTag: useTag,
          tagDataWidth: tagDataWidth,
          useTagUpdate: useTagUpdate,
          useTagMatch: useTagMatch,
          tracePresent: tracePresent,
          loopWidth: loopWidth,
          useBusy: useBusy,
          respWidth: respWidth,
          dataWidth: dataWidth,
          useLast: useLast,
          chunkNumWidth: chunkNumWidth,
          chunkStrbWidth: chunkStrbWidth,
          usePoison: usePoison),
      useCrediting: useCrediting,
      sharedCredits: sharedCredits,
      numRp: numRp,
      userMixInEnable: userMixInEnable,
      idMixInEnable: idMixInEnable,
      tagMixInEnable: tagMixInEnable,
      debugMixInEnable: debugMixInEnable,
      dataMixInEnable: dataMixInEnable,
      chunkMixInEnable: chunkMixInEnable,
      responseMixInEnable: responseMixInEnable);
}

/// A config object for constructor an AXI5 B channel.
abstract class Axi5BaseBChannelConfig {
  /// The width of the user-defined signal in bits.
  final int userWidth;

  /// The width of the ID signal in bits.
  final int idWidth;

  /// Indicates whether the unique ID feature is used.
  final bool useIdUnq;

  /// Indicates whether the tag feature is used.
  final bool useTag;

  /// The width of the tag data signal in bits.
  final int tagDataWidth;

  /// Indicates whether the tag update feature is used.
  final bool useTagUpdate;

  /// Indicates whether the tag match feature is used.
  final bool useTagMatch;

  /// Indicates whether trace functionality is present.
  final bool tracePresent;

  /// The width of the loop signal in bits.
  final int loopWidth;

  /// The width of the response signal in bits.
  final int respWidth;

  /// Indicates whether the busy signal is used.
  final bool useBusy;

  /// Constructor.
  Axi5BaseBChannelConfig({
    this.userWidth = 0,
    this.idWidth = 0,
    this.useIdUnq = false,
    this.useTag = false,
    this.tagDataWidth = 0,
    this.useTagUpdate = false,
    this.useTagMatch = false,
    this.tracePresent = false,
    this.loopWidth = 0,
    this.respWidth = 0,
    this.useBusy = false,
  });
}

/// Basis for all possible B channels.
class Axi5BChannelInterface extends Axi5TransportInterface
    with
        Axi5UserSignals,
        Axi5IdSignals,
        Axi5MemRespDataTagSignals,
        Axi5DebugSignals,
        Axi5ResponseSignals {
  /// Enable User signal mixin
  final bool userMixInEnable;

  /// Enable ID signal mixin
  final bool idMixInEnable;

  /// Enable Tag signal mixin
  final bool tagMixInEnable;

  /// Enable Debug signal mixin
  final bool debugMixInEnable;

  @override
  final int userWidth;

  @override
  final int idWidth;

  @override
  final bool useIdUnq;

  @override
  final bool useTag;

  @override
  final int tagDataWidth;

  @override
  final bool useTagUpdate;

  @override
  final bool useTagMatch;

  @override
  final bool tracePresent;

  @override
  final int loopWidth;

  @override
  final int respWidth;

  @override
  final bool useBusy;

  /// Constructor.
  Axi5BChannelInterface({
    required Axi5BaseBChannelConfig config,
    super.useCrediting = false,
    super.sharedCredits = false,
    super.numRp = 0,
    this.userMixInEnable = false,
    this.idMixInEnable = false,
    this.tagMixInEnable = false,
    this.debugMixInEnable = false,
  })  : idWidth = config.idWidth,
        userWidth = config.userWidth,
        useIdUnq = config.useIdUnq,
        useTag = config.useTag,
        tagDataWidth = config.tagDataWidth,
        useTagUpdate = config.useTagUpdate,
        useTagMatch = config.useTagMatch,
        tracePresent = config.tracePresent,
        loopWidth = config.loopWidth,
        respWidth = config.respWidth,
        useBusy = config.useBusy,
        super(prefix: 'B', main: false) {
    makeResponsePorts();
    if (userMixInEnable) {
      makeUserPorts();
    }
    if (idMixInEnable) {
      makeIdPorts();
    }
    if (tagMixInEnable) {
      makeRespDataTagPorts();
    }
    if (debugMixInEnable) {
      makeDebugPorts();
    }
  }

  /// Copy Constructor.
  Axi5BChannelInterface clone() => Axi5BChannelInterface(
      config: Axi5BChannelConfig(
          userWidth: userWidth,
          idWidth: idWidth,
          useIdUnq: useIdUnq,
          useTag: useTag,
          tagDataWidth: tagDataWidth,
          useTagUpdate: useTagUpdate,
          useTagMatch: useTagMatch,
          tracePresent: tracePresent,
          loopWidth: loopWidth,
          useBusy: useBusy,
          respWidth: respWidth),
      useCrediting: useCrediting,
      sharedCredits: sharedCredits,
      numRp: numRp,
      userMixInEnable: userMixInEnable,
      idMixInEnable: idMixInEnable,
      tagMixInEnable: tagMixInEnable,
      debugMixInEnable: debugMixInEnable);
}

/// Basis for all possible AC channels.
class Axi5AcChannelInterface extends Axi5TransportInterface
    with Axi5DebugSignals {
  /// Enable Debug signal mixin
  final bool debugMixInEnable;

  @override
  final bool tracePresent;

  @override
  final int loopWidth;

  /// Width of snoop address.
  final int addrWidth;

  /// Snoop address.
  ///
  /// Width is equal to [addrWidth].
  Logic? get addr => tryPort('${prefix}ADDR');

  /// VMID extension for DVM messages.
  ///
  /// Width is equal to 4.
  Logic? get vmidExt => tryPort('${prefix}VMIDEXT');

  /// Constructor.
  Axi5AcChannelInterface({
    this.debugMixInEnable = false,
    this.tracePresent = false,
    this.addrWidth = 32,
  })  : loopWidth = 0,
        super(
          prefix: 'AC',
          main: false,
          useCrediting: false,
          sharedCredits: false,
          numRp: 0,
        ) {
    if (debugMixInEnable) {
      makeDebugPorts();
    }

    setPorts([
      Logic.port('${prefix}ADDR', addrWidth),
      Logic.port('${prefix}VMIDEXT', 4),
    ], [
      PairDirection.fromConsumer,
    ]);
  }

  /// Copy Constructor.
  Axi5AcChannelInterface clone() => Axi5AcChannelInterface(
      debugMixInEnable: debugMixInEnable,
      tracePresent: tracePresent,
      addrWidth: addrWidth);
}

/// Basis for all possible CR channels.
class Axi5CrChannelInterface extends Axi5TransportInterface
    with Axi5DebugSignals {
  /// Enable Debug signal mixin
  final bool debugMixInEnable;

  @override
  final bool tracePresent;

  @override
  final int loopWidth;

  /// Constructor.
  Axi5CrChannelInterface({
    this.debugMixInEnable = false,
    this.tracePresent = false,
  })  : loopWidth = 0,
        super(
          prefix: 'CR',
          main: true,
          useCrediting: false,
          sharedCredits: false,
          numRp: 0,
        ) {
    if (debugMixInEnable) {
      makeDebugPorts();
    }
  }

  /// Copy Constructor.
  Axi5CrChannelInterface clone() => Axi5CrChannelInterface(
      debugMixInEnable: debugMixInEnable, tracePresent: tracePresent);
}
