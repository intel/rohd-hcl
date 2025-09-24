// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// Axi5.dart
// Definitions for the AXI interface.
//
// 2025 January
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A config object for constructing an ACE5-Lite5 AW channel.
class Ace5LiteAwChannelConfig extends Axi5BaseAwChannelConfig {
  /// Constructor.
  Ace5LiteAwChannelConfig({
    super.userWidth = 32,
    super.idWidth = 4,
    super.useIdUnq = false,
    super.addrWidth = 32,
    super.lenWidth = 8,
    super.useLock = true,
    super.rmeSupport = false,
    super.mecIdWidth = 0,
    super.atOpWidth = 0,
    super.snpWidth = 0,
    super.tracePresent = false,
    super.loopWidth = 0,
    super.mpamWidth = 0,
    super.useTagging = false,
    super.secSidWidth = 0,
    super.sidWidth = 0,
    super.ssidWidth = 0,
    super.useNsaId = false,
    super.usePbha = false,
    super.subSysIdWidth = 0,
    super.domainWidth = 0,
    super.stashNidPresent = false,
    super.stashLPidPresent = false,
    super.cmoWidth = 0,
    super.useFlow = false,
    super.untranslatedTransVersion = 4,
  }) : super(
          sizeWidth: 3,
          burstWidth: 2,
          cacheWidth: 4,
          protWidth: 3,
          qosWidth: 4,
          regionWidth: 4,
          pasWidth: 0,
          instPrivPresent: false,
          actWidth: 0,
          supportGdi: false,
          supportRmeAndPasMmu: false,
        );
}

/// ACE-5 Lite AW channel.
class Ace5LiteAwChannelInterface extends Axi5AwChannelInterface {
  /// Constructor.
  Ace5LiteAwChannelInterface(
      {required super.config,
      super.userMixInEnable,
      super.idMixInEnable,
      super.debugMixInEnable,
      super.atomicMixInEnable,
      super.mmuMixInEnable,
      super.stashMixInEnable,
      super.qualMixInEnable,
      super.tagMixInEnable,
      super.opcodeMixInEnable})
      : super(
          useCrediting: false,
          sharedCredits: false,
          numRp: 0,
        );

  /// Copy Constructor.
  @override
  Ace5LiteAwChannelInterface clone() => Ace5LiteAwChannelInterface(
        config: Ace5LiteAwChannelConfig(
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
          mecIdWidth: mecIdWidth,
          mpamWidth: mpamWidth,
          useTagging: useTagging,
          secSidWidth: secSidWidth,
          sidWidth: sidWidth,
          ssidWidth: ssidWidth,
          useNsaId: useNsaId,
          usePbha: usePbha,
          subSysIdWidth: subSysIdWidth,
          useFlow: useFlow,
          domainWidth: domainWidth,
          stashNidPresent: stashNidPresent,
          stashLPidPresent: stashLPidPresent,
          cmoWidth: cmoWidth,
          untranslatedTransVersion: untranslatedTransVersion,
        ),
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

/// A config object for constructing an ACE5-Lite AR channel.
class Ace5LiteArChannelConfig extends Axi5BaseArChannelConfig {
  /// Constructor.
  Ace5LiteArChannelConfig({
    super.userWidth = 32,
    super.idWidth = 4,
    super.useIdUnq = false,
    super.addrWidth = 32,
    super.lenWidth = 8,
    super.useLock = true,
    super.snpWidth = 0,
    super.barWidth = 0,
    super.usePoison = false,
    super.rmeSupport = false,
    super.mecIdWidth = 0,
    super.useChunk = false,
    super.atopWidth = 0,
    super.chunkNumWidth = 0,
    super.chunkStrbWidth = 0,
    super.tracePresent = false,
    super.loopWidth = 0,
    super.mpamWidth = 0,
    super.useTagging = false,
    super.secSidWidth = 0,
    super.sidWidth = 0,
    super.ssidWidth = 0,
    super.useNsaId = false,
    super.usePbha = false,
    super.subSysIdWidth = 0,
    super.useFlow = false,
    super.untranslatedTransVersion = 4,
  }) : super(
          sizeWidth: 3,
          burstWidth: 2,
          cacheWidth: 4,
          protWidth: 3,
          qosWidth: 4,
          regionWidth: 4,
          instPrivPresent: false,
          pasWidth: 0,
          supportGdi: false,
          supportRmeAndPasMmu: false,
          actWidth: 0,
        );
}

/// ACE-5 Lite AR channel.
class Ace5LiteArChannelInterface extends Axi5ArChannelInterface {
  /// Constructor.
  Ace5LiteArChannelInterface(
      {required super.config,
      super.userMixInEnable,
      super.idMixInEnable,
      super.debugMixInEnable,
      super.atomicMixInEnable,
      super.mmuMixInEnable,
      super.chunkMixInEnable,
      super.qualMixInEnable,
      super.tagMixInEnable,
      super.opcodeMixInEnable})
      : super(
          useCrediting: false,
          sharedCredits: false,
          numRp: 0,
        );

  /// Copy Constructor.
  @override
  Ace5LiteArChannelInterface clone() => Ace5LiteArChannelInterface(
        config: Ace5LiteArChannelConfig(
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
          mecIdWidth: mecIdWidth,
          atopWidth: atOpWidth,
          mpamWidth: mpamWidth,
          useTagging: useTagging,
          secSidWidth: secSidWidth,
          sidWidth: sidWidth,
          ssidWidth: ssidWidth,
          useNsaId: useNsaId,
          usePbha: usePbha,
          subSysIdWidth: subSysIdWidth,
          useFlow: useFlow,
          untranslatedTransVersion: untranslatedTransVersion,
        ),
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

/// A config object for constructing an ACE-5 W channel.
class Ace5LiteWChannelConfig extends Axi5BaseWChannelConfig {
  /// Constructor.
  Ace5LiteWChannelConfig({
    super.userWidth = 32,
    super.dataWidth = 64,
    super.useLast = true,
    super.tagDataWidth = 0,
    super.useTag = false,
    super.useTagUpdate = false,
    super.useTagMatch = false,
    super.tracePresent = false,
    super.loopWidth = 0,
    super.strbWidth = 0,
    super.usePoison = false,
  });
}

/// ACE-5 Lite W channel.
class Ace5LiteWChannelInterface extends Axi5WChannelInterface {
  /// Constructor.
  Ace5LiteWChannelInterface(
      {required super.config,
      super.userMixInEnable,
      super.debugMixInEnable,
      super.tagMixInEnable})
      : super(
          useCrediting: false,
          sharedCredits: false,
          numRp: 0,
        );

  /// Copy Constructor.
  @override
  Ace5LiteWChannelInterface clone() => Ace5LiteWChannelInterface(
        config: Ace5LiteWChannelConfig(
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
        userMixInEnable: userMixInEnable,
        tagMixInEnable: tagMixInEnable,
        debugMixInEnable: debugMixInEnable,
      );
}

/// A config object for constructing an ACE5-Lite R channel.
class Ace5LiteRChannelConfig extends Axi5BaseRChannelConfig {
  /// Constructor.
  Ace5LiteRChannelConfig({
    super.userWidth = 32,
    super.dataWidth = 64,
    super.idWidth = 4,
    super.useIdUnq = false,
    super.useTag = false,
    super.tagDataWidth = 0,
    super.useTagUpdate = false,
    super.useTagMatch = false,
    super.tracePresent = false,
    super.loopWidth = 0,
    super.useBusy = false,
    super.chunkNumWidth = 0,
    super.chunkStrbWidth = 0,
    super.useLast = true,
    super.usePoison = false,
    super.respWidth = 4,
  }) : super(strbWidth: 0);
}

/// ACE-5 Lite R channel.
class Ace5LiteRChannelInterface extends Axi5RChannelInterface {
  /// Constructor.
  Ace5LiteRChannelInterface({
    required super.config,
    super.userMixInEnable,
    super.debugMixInEnable,
    super.responseMixInEnable,
    super.tagMixInEnable,
    super.chunkMixInEnable,
    super.idMixInEnable,
  }) : super(
          useCrediting: false,
          sharedCredits: false,
          numRp: 0,
        );

  /// Copy Constructor.
  @override
  Ace5LiteRChannelInterface clone() => Ace5LiteRChannelInterface(
      config: Ace5LiteRChannelConfig(
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
      userMixInEnable: userMixInEnable,
      tagMixInEnable: tagMixInEnable,
      debugMixInEnable: debugMixInEnable,
      chunkMixInEnable: chunkMixInEnable,
      responseMixInEnable: responseMixInEnable,
      idMixInEnable: idMixInEnable);
}

/// A config object for constructor an AXI5 B channel.
class Ace5LiteBChannelConfig extends Axi5BaseBChannelConfig {
  /// Constructor.
  Ace5LiteBChannelConfig({
    super.userWidth = 16,
    super.idWidth = 4,
    super.useIdUnq = false,
    super.useTag = false,
    super.tagDataWidth = 0,
    super.useTagUpdate = false,
    super.useTagMatch = false,
    super.tracePresent = false,
    super.loopWidth = 0,
    super.useBusy = false,
    super.respWidth = 4,
  });
}

/// ACE-5 Lite B channel.
class Ace5LiteBChannelInterface extends Axi5BChannelInterface {
  /// Constructor.
  Ace5LiteBChannelInterface({
    required super.config,
    super.userMixInEnable,
    super.debugMixInEnable,
    super.tagMixInEnable,
    super.idMixInEnable,
  }) : super(
          useCrediting: false,
          sharedCredits: false,
          numRp: 0,
        );

  /// Copy Constructor.
  @override
  Ace5LiteBChannelInterface clone() => Ace5LiteBChannelInterface(
      config: Ace5LiteBChannelConfig(
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
      userMixInEnable: userMixInEnable,
      tagMixInEnable: tagMixInEnable,
      debugMixInEnable: debugMixInEnable,
      idMixInEnable: idMixInEnable);
}

/// Grouping of read channels.
class Ace5LiteReadCluster extends PairInterface {
  /// AR channel.
  late final Ace5LiteArChannelInterface ar;

  /// R channel.
  late final Ace5LiteRChannelInterface r;

  /// Constructor.
  Ace5LiteReadCluster({required this.ar, required this.r}) {
    addSubInterface('AR', ar);
    addSubInterface('R', r);
  }

  /// Copy constructor.
  Ace5LiteReadCluster clone() => Ace5LiteReadCluster(
        ar: ar.clone(),
        r: r.clone(),
      );
}

/// Grouping of write channels.
class Ace5LiteWriteCluster extends PairInterface {
  /// AW channel.
  late final Ace5LiteAwChannelInterface aw;

  /// W channel.
  late final Ace5LiteWChannelInterface w;

  /// B channel.
  late final Ace5LiteBChannelInterface b;

  /// Constructor.
  Ace5LiteWriteCluster({required this.aw, required this.w, required this.b}) {
    addSubInterface('AW', aw);
    addSubInterface('W', w);
    addSubInterface('B', b);
  }

  /// Copy constructor.
  Ace5LiteWriteCluster clone() => Ace5LiteWriteCluster(
        aw: aw.clone(),
        w: w.clone(),
        b: b.clone(),
      );
}

/// Grouping of all channels.
class Ace5LiteCluster extends PairInterface {
  /// Read channels.
  late final Ace5LiteReadCluster read;

  /// Write channels.
  late final Ace5LiteWriteCluster write;

  /// Constructor.
  Ace5LiteCluster({required this.read, required this.write}) {
    addSubInterface('READ', read);
    addSubInterface('WRITE', write);
  }

  /// Copy constructor.
  Ace5LiteCluster clone() => Ace5LiteCluster(
        write: write.clone(),
        read: read.clone(),
      );
}
