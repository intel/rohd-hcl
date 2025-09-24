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
class Axi5AwChannelConfig extends Axi5BaseAwChannelConfig {
  /// Constructor.
  Axi5AwChannelConfig({
    super.userWidth = 32,
    super.idWidth = 4,
    super.useIdUnq = false,
    super.addrWidth = 32,
    super.lenWidth = 8,
    super.useLock = true,
    super.rmeSupport = false,
    super.instPrivPresent = false,
    super.pasWidth = 0,
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
    super.actWidth = 0,
    super.subSysIdWidth = 0,
    super.domainWidth = 0,
    super.stashNidPresent = false,
    super.stashLPidPresent = false,
    super.cmoWidth = 0,
    super.useFlow = false,
    super.supportGdi = false,
    super.supportRmeAndPasMmu = false,
    super.untranslatedTransVersion = 4,
  }) : super(
          sizeWidth: 3,
          burstWidth: 2,
          cacheWidth: 4,
          protWidth: 3,
          qosWidth: 4,
          regionWidth: 4,
        );
}

/// A config object for constructing an AXI5 AR channel.
class Axi5ArChannelConfig extends Axi5BaseArChannelConfig {
  /// Constructor.
  Axi5ArChannelConfig({
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
    super.instPrivPresent = false,
    super.pasWidth = 0,
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
    super.actWidth = 0,
    super.subSysIdWidth = 0,
    super.useFlow = false,
    super.supportGdi = false,
    super.supportRmeAndPasMmu = false,
    super.untranslatedTransVersion = 4,
  }) : super(
          sizeWidth: 3,
          burstWidth: 2,
          cacheWidth: 4,
          protWidth: 3,
          qosWidth: 4,
          regionWidth: 4,
        );
}

/// A config object for constructing an AXI5 W channel.
class Axi5WChannelConfig extends Axi5BaseWChannelConfig {
  /// Constructor.
  Axi5WChannelConfig({
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

/// A config object for constructing an AXI5 R channel.
class Axi5RChannelConfig extends Axi5BaseRChannelConfig {
  /// Constructor.
  Axi5RChannelConfig({
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

/// A config object for constructor an AXI5 B channel.
class Axi5BChannelConfig extends Axi5BaseBChannelConfig {
  /// Constructor.
  Axi5BChannelConfig({
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

/// Grouping of read channels.
class Axi5ReadCluster extends PairInterface {
  /// AR channel.
  late final Axi5ArChannelInterface ar;

  /// R channel.
  late final Axi5RChannelInterface r;

  /// Constructor.
  Axi5ReadCluster({required this.ar, required this.r}) {
    addSubInterface('AR', ar);
    addSubInterface('R', r);
  }

  /// Copy constructor.
  Axi5ReadCluster clone() => Axi5ReadCluster(
        ar: ar.clone(),
        r: r.clone(),
      );
}

/// Grouping of write channels.
class Axi5WriteCluster extends PairInterface {
  /// AW channel.
  late final Axi5AwChannelInterface aw;

  /// W channel.
  late final Axi5WChannelInterface w;

  /// B channel.
  late final Axi5BChannelInterface b;

  /// Constructor.
  Axi5WriteCluster({required this.aw, required this.w, required this.b}) {
    addSubInterface('AW', aw);
    addSubInterface('W', w);
    addSubInterface('B', b);
  }

  /// Copy constructor.
  Axi5WriteCluster clone() => Axi5WriteCluster(
        aw: aw.clone(),
        w: w.clone(),
        b: b.clone(),
      );
}

/// Grouping of snoop channels.
class Axi5SnoopCluster extends PairInterface {
  /// AC channel.
  late final Axi5AcChannelInterface ac;

  /// CR channel.
  late final Axi5CrChannelInterface cr;

  /// Constructor.
  Axi5SnoopCluster({required this.ac, required this.cr}) {
    addSubInterface('AC', ac);
    addSubInterface('CR', cr);
  }

  /// Copy constructor.
  Axi5SnoopCluster clone() => Axi5SnoopCluster(
        ac: ac.clone(),
        cr: cr.clone(),
      );
}

/// Grouping of all channels.
class Axi5Cluster extends PairInterface {
  /// Read channels.
  late final Axi5ReadCluster read;

  /// Write channels.
  late final Axi5WriteCluster write;

  /// B channel.
  late final Axi5SnoopCluster snoop;

  /// Constructor.
  Axi5Cluster({required this.read, required this.write, required this.snoop}) {
    addSubInterface('READ', read);
    addSubInterface('WRITE', write);
    addSubInterface('SNOOP', snoop);
  }

  /// Copy constructor.
  Axi5Cluster clone() => Axi5Cluster(
        write: write.clone(),
        read: read.clone(),
        snoop: snoop.clone(),
      );
}
