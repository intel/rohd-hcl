// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// Axi5.dart
// Definitions for the AXI interface.
//
// 2025 January
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

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
            tagMixInEnable: false);
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
      super.responseMixInEnable})
      : super(
            useCrediting: false,
            sharedCredits: false,
            numRp: 0,
            tagMixInEnable: false,
            chunkMixInEnable: false);
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
  }) : super(
          useCrediting: false,
          sharedCredits: false,
          numRp: 0,
          tagMixInEnable: false,
        );
}
