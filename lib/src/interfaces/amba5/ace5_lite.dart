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
class Ace5AwChannelConfig extends Axi5BaseAwChannelConfig {
  /// Constructor.
  Ace5AwChannelConfig({
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
  }) : super(
          useCrediting: false,
          sharedCredits: false,
          numRp: 0,
        );
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
  }) : super(
          useCrediting: false,
          sharedCredits: false,
          numRp: 0,
        );
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
}
