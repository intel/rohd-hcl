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

/// A config object for constructing an AXI5 AW channel.
class Axi5LiteAwChannelConfig extends Axi5BaseAwChannelConfig {
  /// Constructor.
  Axi5LiteAwChannelConfig({
    super.userWidth = 32,
    super.idWidth = 4,
    super.useIdUnq = false,
    super.addrWidth = 32,
    super.tracePresent = false,
    super.subSysIdWidth = 0,
  }) : super(
          sizeWidth: 3,
          burstWidth: 0,
          cacheWidth: 0,
          protWidth: 3,
          qosWidth: 0,
          regionWidth: 0,
          lenWidth: 0,
          useLock: false,
          rmeSupport: false,
          instPrivPresent: false,
          pasWidth: 0,
          mecIdWidth: 0,
          atOpWidth: 0,
          snpWidth: 0,
          mpamWidth: 0,
          useTagging: false,
          secSidWidth: 0,
          sidWidth: 0,
          ssidWidth: 0,
          useNsaId: false,
          usePbha: false,
          actWidth: 0,
          domainWidth: 0,
          stashNidPresent: false,
          stashLPidPresent: false,
          cmoWidth: 0,
          loopWidth: 0,
          useFlow: false,
          supportGdi: false,
          supportRmeAndPasMmu: false,
          untranslatedTransVersion: 0,
        );
}

/// AXI-5 Lite AW channel.
class Axi5LiteAwChannelInterface extends Axi5AwChannelInterface {
  /// Constructor.
  Axi5LiteAwChannelInterface(
      {required super.config,
      super.userMixInEnable,
      super.idMixInEnable,
      super.debugMixInEnable})
      : super(
            useCrediting: false,
            sharedCredits: false,
            numRp: 0,
            atomicMixInEnable: false,
            mmuMixInEnable: false,
            stashMixInEnable: false,
            qualMixInEnable: false,
            tagMixInEnable: false,
            opcodeMixInEnable: false);

  /// Copy Constructor.
  @override
  Axi5LiteAwChannelInterface clone() => Axi5LiteAwChannelInterface(
        config: Axi5LiteAwChannelConfig(
          userWidth: userWidth,
          idWidth: idWidth,
          useIdUnq: useIdUnq,
          tracePresent: tracePresent,
          addrWidth: addrWidth,
          subSysIdWidth: subSysIdWidth,
        ),
        userMixInEnable: userMixInEnable,
        idMixInEnable: idMixInEnable,
        debugMixInEnable: debugMixInEnable,
      );
}

/// A config object for constructing an AXI5 AR channel.
class Axi5LiteArChannelConfig extends Axi5BaseArChannelConfig {
  /// Constructor.
  Axi5LiteArChannelConfig({
    super.userWidth = 32,
    super.idWidth = 4,
    super.useIdUnq = false,
    super.addrWidth = 32,
    super.tracePresent = false,
    super.subSysIdWidth = 0,
  }) : super(
          sizeWidth: 3,
          burstWidth: 0,
          cacheWidth: 0,
          protWidth: 3,
          qosWidth: 0,
          regionWidth: 0,
          lenWidth: 0,
          useLock: false,
          rmeSupport: false,
          instPrivPresent: false,
          pasWidth: 0,
          mecIdWidth: 0,
          atopWidth: 0,
          snpWidth: 0,
          mpamWidth: 0,
          useTagging: false,
          secSidWidth: 0,
          sidWidth: 0,
          ssidWidth: 0,
          useNsaId: false,
          usePbha: false,
          actWidth: 0,
          loopWidth: 0,
          useFlow: false,
          supportGdi: false,
          supportRmeAndPasMmu: false,
          untranslatedTransVersion: 0,
        );
}

/// AXI-5 Lite AR channel.
class Axi5LiteArChannelInterface extends Axi5ArChannelInterface {
  /// Constructor.
  Axi5LiteArChannelInterface(
      {required super.config,
      super.userMixInEnable,
      super.idMixInEnable,
      super.debugMixInEnable})
      : super(
            useCrediting: false,
            sharedCredits: false,
            numRp: 0,
            atomicMixInEnable: false,
            mmuMixInEnable: false,
            chunkMixInEnable: false,
            qualMixInEnable: false,
            tagMixInEnable: false,
            opcodeMixInEnable: false);

  /// Copy Constructor.
  @override
  Axi5LiteArChannelInterface clone() => Axi5LiteArChannelInterface(
        config: Axi5LiteArChannelConfig(
          userWidth: userWidth,
          idWidth: idWidth,
          useIdUnq: useIdUnq,
          tracePresent: tracePresent,
          addrWidth: addrWidth,
          subSysIdWidth: subSysIdWidth,
        ),
        userMixInEnable: userMixInEnable,
        idMixInEnable: idMixInEnable,
        debugMixInEnable: debugMixInEnable,
      );
}

/// A config object for constructing an AXI5 W channel.
class Axi5LiteWChannelConfig extends Axi5BaseWChannelConfig {
  /// Constructor.
  Axi5LiteWChannelConfig({
    super.userWidth = 32,
    super.dataWidth = 64,
    super.tracePresent = false,
    super.usePoison = false,
  }) : super(
          useLast: false,
          useTag: false,
          useTagUpdate: false,
          useTagMatch: false,
          tagDataWidth: 0,
          strbWidth: dataWidth ~/ 8,
          loopWidth: 0,
        );
}

/// AXI-5 Lite W channel.
class Axi5LiteWChannelInterface extends Axi5WChannelInterface {
  /// Constructor.
  Axi5LiteWChannelInterface(
      {required super.config, super.userMixInEnable, super.debugMixInEnable})
      : super(
            useCrediting: false,
            sharedCredits: false,
            numRp: 0,
            tagMixInEnable: false);

  /// Copy Constructor.
  @override
  Axi5LiteWChannelInterface clone() => Axi5LiteWChannelInterface(
        config: Axi5LiteWChannelConfig(
          userWidth: userWidth,
          tracePresent: tracePresent,
          dataWidth: dataWidth,
          usePoison: usePoison,
        ),
        userMixInEnable: userMixInEnable,
        debugMixInEnable: debugMixInEnable,
      );
}

/// A config object for constructing an AXI5 R channel.
class Axi5LiteRChannelConfig extends Axi5BaseRChannelConfig {
  /// Constructor.
  Axi5LiteRChannelConfig({
    super.userWidth = 32,
    super.dataWidth = 64,
    super.idWidth = 4,
    super.useIdUnq = false,
    super.tracePresent = false,
    super.usePoison = false,
    super.respWidth = 4,
  }) : super(
          useLast: false,
          useTag: false,
          tagDataWidth: 0,
          useTagMatch: false,
          useTagUpdate: false,
          useBusy: false,
          chunkNumWidth: 0,
          chunkStrbWidth: 0,
          strbWidth: 0,
          loopWidth: 0,
        );
}

/// AXI-5 Lite R channel.
class Axi5LiteRChannelInterface extends Axi5RChannelInterface {
  /// Constructor.
  Axi5LiteRChannelInterface(
      {required super.config,
      super.userMixInEnable,
      super.debugMixInEnable,
      super.responseMixInEnable,
      super.idMixInEnable})
      : super(
            useCrediting: false,
            sharedCredits: false,
            numRp: 0,
            tagMixInEnable: false,
            chunkMixInEnable: false);

  /// Copy Constructor.
  @override
  Axi5LiteRChannelInterface clone() => Axi5LiteRChannelInterface(
      config: Axi5LiteRChannelConfig(
          userWidth: userWidth,
          idWidth: idWidth,
          useIdUnq: useIdUnq,
          tracePresent: tracePresent,
          respWidth: respWidth,
          dataWidth: dataWidth,
          usePoison: usePoison),
      userMixInEnable: userMixInEnable,
      debugMixInEnable: debugMixInEnable,
      responseMixInEnable: responseMixInEnable,
      idMixInEnable: idMixInEnable);
}

/// A config object for constructor an AXI5 B channel.
class Axi5LiteBChannelConfig extends Axi5BaseBChannelConfig {
  /// Constructor.
  Axi5LiteBChannelConfig({
    super.userWidth = 16,
    super.idWidth = 4,
    super.useIdUnq = false,
    super.tracePresent = false,
    super.respWidth = 4,
  }) : super(
          useTag: false,
          useTagUpdate: false,
          useTagMatch: false,
          tagDataWidth: 0,
          useBusy: false,
          loopWidth: 0,
        );
}

/// AXI-5 Lite B channel.
class Axi5LiteBChannelInterface extends Axi5BChannelInterface {
  /// Constructor.
  Axi5LiteBChannelInterface({
    required super.config,
    super.userMixInEnable,
    super.debugMixInEnable,
    super.idMixInEnable,
  }) : super(
          useCrediting: false,
          sharedCredits: false,
          numRp: 0,
          tagMixInEnable: false,
        );

  /// Copy Constructor.
  @override
  Axi5LiteBChannelInterface clone() => Axi5LiteBChannelInterface(
      config: Axi5LiteBChannelConfig(
          userWidth: userWidth,
          idWidth: idWidth,
          useIdUnq: useIdUnq,
          tracePresent: tracePresent,
          respWidth: respWidth),
      userMixInEnable: userMixInEnable,
      debugMixInEnable: debugMixInEnable,
      idMixInEnable: idMixInEnable);
}

/// Grouping of read channels.
class Axi5LiteReadCluster extends PairInterface {
  /// AR channel.
  late final Axi5LiteArChannelInterface ar;

  /// R channel.
  late final Axi5LiteRChannelInterface r;

  /// Constructor.
  Axi5LiteReadCluster({required this.ar, required this.r}) {
    addSubInterface('AR', ar);
    addSubInterface('R', r);
  }

  /// Copy constructor.
  Axi5LiteReadCluster clone() => Axi5LiteReadCluster(
        ar: ar.clone(),
        r: r.clone(),
      );
}

/// Grouping of write channels.
class Axi5LiteWriteCluster extends PairInterface {
  /// AW channel.
  late final Axi5LiteAwChannelInterface aw;

  /// W channel.
  late final Axi5LiteWChannelInterface w;

  /// B channel.
  late final Axi5LiteBChannelInterface b;

  /// Constructor.
  Axi5LiteWriteCluster({required this.aw, required this.w, required this.b}) {
    addSubInterface('AW', aw);
    addSubInterface('W', w);
    addSubInterface('B', b);
  }

  /// Copy constructor.
  Axi5LiteWriteCluster clone() => Axi5LiteWriteCluster(
        aw: aw.clone(),
        w: w.clone(),
        b: b.clone(),
      );
}

/// Grouping of all channels.
class Axi5LiteCluster extends PairInterface {
  /// Read channels.
  late final Axi5LiteReadCluster read;

  /// Write channels.
  late final Axi5LiteWriteCluster write;

  /// Constructor.
  Axi5LiteCluster({required this.read, required this.write}) {
    addSubInterface('READ', read);
    addSubInterface('WRITE', write);
  }

  /// Copy constructor.
  Axi5LiteCluster clone() => Axi5LiteCluster(
        write: write.clone(),
        read: read.clone(),
      );
}
