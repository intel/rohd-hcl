// Copyright (C) 2024-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ace4.dart
// Definitions for the ACE extension on the AXI interface.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

int _ace4FixedWidth(String name, int? width, int expected) {
  if (width != null && width != expected) {
    throw RohdHclException('$name must be $expected in ACE4 signal mode.');
  }
  return expected;
}

void _validateAce4UserWidth(int width) {
  if (width < 0) {
    throw RohdHclException('userWidth must not be negative.');
  }
}

/// ACE AR interface.
///
/// This is mostly the same as AXI-4 but with some coherency additions.
class Ace4ArChannelInterface extends Axi4BaseArChannelInterface
    with Ace4RequestChannel {
  /// Whether to retain the historical port layout.
  final bool legacyMode;

  /// Width of the coherency domain signal.
  @override
  final int domainWidth;

  /// Should the ARBAR signal be present.
  @override
  final bool useBar;

  /// Constructor.
  ///
  /// Should match regular AXI4 but with DOMAIN and BAR.
  Ace4ArChannelInterface({
    super.idWidth = 4,
    super.addrWidth = 32,
    super.lenWidth = 8,
    super.userWidth = 32,
    super.useLock = true,
    int? domainWidth,
    this.useBar = true,
    this.legacyMode = true,
  }) : domainWidth = legacyMode
            ? domainWidth ?? 1
            : _ace4FixedWidth('domainWidth', domainWidth, 2) {
    if (legacyMode) {
      makeAcePorts();
    } else {
      _ace4FixedWidth('lenWidth', lenWidth, 8);
      _validateAce4UserWidth(userWidth);
      if (!useBar) {
        throw RohdHclException('ARBAR is required in ACE4 signal mode.');
      }
      setPorts([
        Logic.port('ARDOMAIN', 2),
        Logic.port('ARBAR', 2),
        Logic.port('ARSNOOP', 4),
      ], [
        PairDirection.fromProvider,
      ]);
    }
  }

  /// Read transaction type, present in ACE4 signal mode.
  Logic? get snoop => tryPort('ARSNOOP');

  /// Copy constructor.
  @override
  Ace4ArChannelInterface clone() => Ace4ArChannelInterface(
      idWidth: idWidth,
      addrWidth: addrWidth,
      lenWidth: lenWidth,
      userWidth: userWidth,
      useLock: useLock,
      domainWidth: domainWidth,
      useBar: useBar,
      legacyMode: legacyMode);
}

/// ACE AW interface.
///
/// This is mostly the same as AXI-4 but with some coherency additions.
class Ace4AwChannelInterface extends Axi4BaseAwChannelInterface
    with Ace4RequestChannel {
  /// Whether to retain the historical port layout.
  final bool legacyMode;

  /// Width of the coherency domain signal.
  @override
  final int domainWidth;

  /// Should the ARBAR signal be present.
  @override
  final bool useBar;

  /// Constructor.
  ///
  /// Should match regular AXI4 but with DOMAIN and BAR.
  Ace4AwChannelInterface({
    super.idWidth = 4,
    super.addrWidth = 32,
    super.lenWidth = 8,
    super.userWidth = 32,
    super.useLock = true,
    int? domainWidth,
    this.useBar = true,
    this.legacyMode = true,
  }) : domainWidth = legacyMode
            ? domainWidth ?? 1
            : _ace4FixedWidth('domainWidth', domainWidth, 2) {
    if (legacyMode) {
      makeAcePorts();
    } else {
      _ace4FixedWidth('lenWidth', lenWidth, 8);
      _validateAce4UserWidth(userWidth);
      if (!useBar) {
        throw RohdHclException('AWBAR is required in ACE4 signal mode.');
      }
      setPorts([
        Logic.port('AWDOMAIN', 2),
        Logic.port('AWBAR', 2),
        Logic.port('AWSNOOP', 3),
        Logic.port('AWUNIQUE'),
      ], [
        PairDirection.fromProvider,
      ]);
    }
  }

  /// Write transaction type, present in ACE4 signal mode.
  Logic? get snoop => tryPort('AWSNOOP');

  /// WriteEvict unique-state indication, present in ACE4 signal mode.
  Logic? get unique => tryPort('AWUNIQUE');

  /// Copy constructor.
  @override
  Ace4AwChannelInterface clone() => Ace4AwChannelInterface(
      idWidth: idWidth,
      addrWidth: addrWidth,
      lenWidth: lenWidth,
      userWidth: userWidth,
      useLock: useLock,
      domainWidth: domainWidth,
      useBar: useBar,
      legacyMode: legacyMode);
}

/// ACE AC interface.
///
/// For snoop requests.
class Ace4AcChannelInterface extends Axi4RequestChannelInterface
    with Ace4RequestChannel {
  /// Whether to retain the historical port layout.
  final bool legacyMode;

  /// Width of the coherency domain signal.
  @override
  final int domainWidth;

  /// Should the ARBAR signal be present.
  @override
  final bool useBar;

  /// Constructor.
  Ace4AcChannelInterface({
    int? idWidth,
    super.addrWidth = 32,
    int? userWidth,
    int? domainWidth,
    bool? useBar,
    this.legacyMode = true,
  })  : domainWidth = legacyMode
            ? domainWidth ?? 1
            : _ace4FixedWidth('domainWidth', domainWidth, 0),
        useBar = useBar ?? legacyMode,
        super(
            prefix: 'AC',
            main: legacyMode,
            idWidth: legacyMode
                ? idWidth ?? 4
                : _ace4FixedWidth('idWidth', idWidth, 0),
            userWidth: legacyMode
                ? userWidth ?? 32
                : _ace4FixedWidth('userWidth', userWidth, 0),
            lenWidth: 0,
            sizeWidth: legacyMode ? 3 : 0,
            burstWidth: legacyMode ? 2 : 0,
            cacheWidth: legacyMode ? 4 : 0,
            protWidth: 3,
            qosWidth: 0,
            regionWidth: 0,
            useLock: false) {
    if (legacyMode) {
      makeAcePorts();
    } else {
      if (this.useBar) {
        throw RohdHclException('ACBAR is not an ACE4 signal.');
      }
      setPorts([Logic.port('ACSNOOP', 4)], [PairDirection.fromConsumer]);
    }
  }

  /// Snoop transaction type, present in ACE4 signal mode.
  Logic? get snoop => tryPort('ACSNOOP');

  /// Copy constructor.
  @override
  Ace4AcChannelInterface clone() => Ace4AcChannelInterface(
      idWidth: idWidth,
      addrWidth: addrWidth,
      userWidth: userWidth,
      domainWidth: domainWidth,
      useBar: useBar,
      legacyMode: legacyMode);
}

/// ACE R interface.
///
/// This is mostly the same as AXI-4 but with some coherency additions.
class Ace4RChannelInterface extends Axi4BaseRChannelInterface {
  /// Whether to retain the historical port layout.
  final bool legacyMode;

  /// Constructor.
  ///
  /// Should match regular AXI4 but with DOMAIN and BAR.
  Ace4RChannelInterface({
    super.idWidth = 4,
    super.userWidth = 32,
    super.useLast = true,
    super.dataWidth = 64,
    this.legacyMode = true,
  }) : super(
          respWidth: legacyMode ? 2 : 4,
        ) {
    if (!legacyMode) {
      _validateAce4UserWidth(userWidth);
      if (idWidth < 0 || idWidth > 32) {
        throw RohdHclException('idWidth must be >= 0 and <= 32.');
      }
      if (!useLast || dataWidth < 32) {
        throw RohdHclException(
            'ACE4 read data requires RLAST and a data width of at least 32.');
      }
    }
  }

  /// Copy constructor.
  @override
  Ace4RChannelInterface clone() => Ace4RChannelInterface(
      idWidth: idWidth,
      userWidth: userWidth,
      useLast: useLast,
      dataWidth: dataWidth,
      legacyMode: legacyMode);
}

/// ACE W interface.
///
/// This is mostly the same as AXI-4 but with some coherency additions.
class Ace4WChannelInterface extends Axi4BaseWChannelInterface {
  /// Whether to retain the historical port layout.
  final bool legacyMode;

  /// Constructor.
  ///
  /// Should match regular AXI4 but with DOMAIN and BAR.
  Ace4WChannelInterface({
    int? idWidth,
    super.userWidth = 32,
    super.useLast = true,
    super.dataWidth = 64,
    this.legacyMode = true,
  }) : super(
          idWidth: legacyMode
              ? idWidth ?? 4
              : _ace4FixedWidth('idWidth', idWidth, 0),
        ) {
    if (!legacyMode) {
      _validateAce4UserWidth(userWidth);
      if (!useLast || dataWidth < 32) {
        throw RohdHclException(
            'ACE4 write data requires WLAST and a data width of at least 32.');
      }
    }
  }

  /// Copy constructor.
  @override
  Ace4WChannelInterface clone() => Ace4WChannelInterface(
      idWidth: idWidth,
      userWidth: userWidth,
      useLast: useLast,
      dataWidth: dataWidth,
      legacyMode: legacyMode);
}

/// ACE CD interface.
///
/// For snoop data.
class Ace4CdChannelInterface extends Axi4DataChannelInterface {
  /// Whether to retain the historical port layout.
  final bool legacyMode;

  /// Constructor.
  Ace4CdChannelInterface({
    int? idWidth,
    super.dataWidth = 64,
    int? userWidth,
    this.legacyMode = true,
  }) : super(
          main: !legacyMode,
          prefix: 'CD',
          useLast: true,
          idWidth: legacyMode
              ? idWidth ?? 4
              : _ace4FixedWidth('idWidth', idWidth, 0),
          userWidth: legacyMode
              ? userWidth ?? 32
              : _ace4FixedWidth('userWidth', userWidth, 0),
        ) {
    if (!legacyMode && dataWidth < 32) {
      throw RohdHclException('CDDATA must be at least 32 bits wide.');
    }
  }

  /// Copy constructor.
  @override
  Ace4CdChannelInterface clone() => Ace4CdChannelInterface(
      idWidth: idWidth,
      dataWidth: dataWidth,
      userWidth: userWidth,
      legacyMode: legacyMode);
}

/// ACE B interface.
///
/// This is mostly the same as AXI-4 but with some coherency additions.
class Ace4BChannelInterface extends Axi4BaseBChannelInterface {
  /// Whether to retain the historical port layout.
  final bool legacyMode;

  /// Constructor.
  ///
  /// Should match regular AXI4 but with DOMAIN and BAR.
  Ace4BChannelInterface({
    super.idWidth = 4,
    super.userWidth = 16,
    this.legacyMode = true,
  }) : super(
          respWidth: 2,
        ) {
    if (!legacyMode) {
      _validateAce4UserWidth(userWidth);
      if (idWidth < 0 || idWidth > 32) {
        throw RohdHclException('idWidth must be >= 0 and <= 32.');
      }
    }
  }

  /// Copy constructor.
  @override
  Ace4BChannelInterface clone() => Ace4BChannelInterface(
      idWidth: idWidth, userWidth: userWidth, legacyMode: legacyMode);
}

/// ACE CR interface.
///
/// For snoop responses.
class Ace4CrChannelInterface extends Axi4ResponseChannelInterface {
  /// Whether to retain the historical port layout.
  final bool legacyMode;

  /// Should the CRLAST signal be present.
  final bool useLast;

  /// For multi-beat snoops, indicates the end of a beat.
  ///
  /// Width is always 1.
  Logic? get last => tryPort('${prefix}LAST');

  /// Constructor.
  Ace4CrChannelInterface({
    int? idWidth,
    int? userWidth,
    int? respWidth,
    bool? useLast,
    this.legacyMode = true,
  })  : useLast = useLast ?? legacyMode,
        super(
          prefix: 'CR',
          main: !legacyMode,
          idWidth: legacyMode
              ? idWidth ?? 4
              : _ace4FixedWidth('idWidth', idWidth, 0),
          userWidth: legacyMode
              ? userWidth ?? 32
              : _ace4FixedWidth('userWidth', userWidth, 0),
          respWidth: legacyMode
              ? respWidth ?? 2
              : _ace4FixedWidth('respWidth', respWidth, 5),
        ) {
    if (!legacyMode && this.useLast) {
      throw RohdHclException('CRLAST is not an ACE4 signal.');
    }
    setPorts([
      if (this.useLast) Logic.port('${prefix}LAST'),
    ], [
      PairDirection.fromConsumer,
    ]);
  }

  /// Copy constructor.
  @override
  Ace4CrChannelInterface clone() => Ace4CrChannelInterface(
      idWidth: idWidth,
      respWidth: respWidth,
      userWidth: userWidth,
      useLast: useLast,
      legacyMode: legacyMode);
}

/// ACE4 read cluster.
class Ace4ReadCluster extends Axi4BaseReadCluster {
  /// Whether to retain the historical port layout.
  final bool legacyMode;

  /// Constructor.
  Ace4ReadCluster({
    int idWidth = 4,
    int addrWidth = 32,
    int lenWidth = 8,
    int userWidth = 32,
    int? arUserWidth,
    int? rUserWidth,
    bool useLock = false,
    int dataWidth = 64,
    bool useLast = true,
    int? domainWidth,
    bool useBar = true,
    this.legacyMode = true,
  }) : super(
            arIntf: Ace4ArChannelInterface(
                idWidth: idWidth,
                addrWidth: addrWidth,
                lenWidth: lenWidth,
                useLock: useLock,
                userWidth: arUserWidth ?? userWidth,
                domainWidth: domainWidth,
                useBar: useBar,
                legacyMode: legacyMode),
            rIntf: Ace4RChannelInterface(
                idWidth: idWidth,
                userWidth: rUserWidth ?? userWidth,
                dataWidth: dataWidth,
                useLast: useLast,
                legacyMode: legacyMode));

  /// Copy constructor.
  @override
  Ace4ReadCluster clone() => Ace4ReadCluster(
        idWidth: arIntf.idWidth,
        addrWidth: arIntf.addrWidth,
        lenWidth: arIntf.lenWidth,
        userWidth: arIntf.userWidth,
        rUserWidth: rIntf.userWidth,
        useLast: rIntf.useLast,
        useLock: arIntf.useLock,
        dataWidth: rIntf.dataWidth,
        domainWidth: (arIntf as Ace4RequestChannel).domainWidth,
        useBar: (arIntf as Ace4RequestChannel).useBar,
        legacyMode: legacyMode,
      );
}

/// ACE4 write cluster.
class Ace4WriteCluster extends Axi4BaseWriteCluster {
  /// Whether to retain the historical port layout.
  final bool legacyMode;

  /// Constructor.
  Ace4WriteCluster({
    int idWidth = 4,
    int addrWidth = 32,
    int lenWidth = 8,
    int userWidth = 32,
    int? awUserWidth,
    int? wUserWidth,
    int? bUserWidth,
    bool useLock = false,
    int dataWidth = 64,
    bool useLast = true,
    int? domainWidth,
    bool useBar = true,
    this.legacyMode = true,
  }) : super(
            awIntf: Ace4AwChannelInterface(
                idWidth: idWidth,
                addrWidth: addrWidth,
                lenWidth: lenWidth,
                useLock: useLock,
                userWidth: awUserWidth ?? userWidth,
                domainWidth: domainWidth,
                useBar: useBar,
                legacyMode: legacyMode),
            wIntf: Ace4WChannelInterface(
                idWidth: legacyMode ? idWidth : null,
                userWidth: wUserWidth ?? userWidth,
                dataWidth: dataWidth,
                useLast: useLast,
                legacyMode: legacyMode),
            bIntf: Ace4BChannelInterface(
                idWidth: idWidth,
                userWidth: bUserWidth ?? userWidth,
                legacyMode: legacyMode));

  /// Copy constructor.
  @override
  Ace4WriteCluster clone() => Ace4WriteCluster(
        idWidth: awIntf.idWidth,
        addrWidth: awIntf.addrWidth,
        lenWidth: awIntf.lenWidth,
        userWidth: awIntf.userWidth,
        wUserWidth: wIntf.userWidth,
        bUserWidth: bIntf.userWidth,
        useLast: wIntf.useLast,
        useLock: awIntf.useLock,
        dataWidth: wIntf.dataWidth,
        domainWidth: (awIntf as Ace4RequestChannel).domainWidth,
        useBar: (awIntf as Ace4RequestChannel).useBar,
        legacyMode: legacyMode,
      );
}

/// ACE4 snoop cluster.
class Ace4SnoopCluster extends PairInterface {
  /// Whether to retain the historical port layout.
  final bool legacyMode;

  /// AC channel.
  late final Ace4AcChannelInterface acIntf;

  /// CD channel.
  late final Ace4CdChannelInterface cdIntf;

  /// CR channel.
  late final Ace4CrChannelInterface crIntf;

  /// Constructor.
  Ace4SnoopCluster({
    int? idWidth,
    int addrWidth = 32,
    int? userWidth,
    int dataWidth = 64,
    int? domainWidth,
    bool? useBar,
    this.legacyMode = true,
  }) {
    acIntf = Ace4AcChannelInterface(
        idWidth: idWidth,
        addrWidth: addrWidth,
        userWidth: userWidth,
        domainWidth: domainWidth,
        useBar: useBar,
        legacyMode: legacyMode);
    cdIntf = Ace4CdChannelInterface(
        idWidth: idWidth,
        userWidth: userWidth,
        dataWidth: dataWidth,
        legacyMode: legacyMode);
    crIntf = Ace4CrChannelInterface(
        idWidth: idWidth, userWidth: userWidth, legacyMode: legacyMode);

    addSubInterface('AC', acIntf);
    addSubInterface('CD', cdIntf);
    addSubInterface('CR', crIntf);
  }

  /// Copy constructor.
  @override
  Ace4SnoopCluster clone() => Ace4SnoopCluster(
        idWidth: acIntf.idWidth,
        addrWidth: acIntf.addrWidth,
        userWidth: acIntf.userWidth,
        dataWidth: cdIntf.dataWidth,
        domainWidth: acIntf.domainWidth,
        useBar: acIntf.useBar,
        legacyMode: legacyMode,
      );
}

/// ACE4 cluster.
class Ace4Cluster extends Axi4BaseCluster {
  /// Whether to retain the historical port layout.
  final bool legacyMode;

  final int _idWidth;
  final int _userWidth;

  /// Snoop channels.
  late final Ace4SnoopCluster snoop;

  /// Read acknowledgement, present in ACE4 signal mode.
  Logic? get rack => tryPort('RACK');

  /// Write acknowledgement, present in ACE4 signal mode.
  Logic? get wack => tryPort('WACK');

  /// Constructor.
  ///
  /// The optional channel-specific widths override [userWidth] and [idWidth].
  /// Set [legacyMode] to false for ACE4 signal layouts; this does not implement
  /// or validate the ACE protocol's transaction and coherency behavior.
  Ace4Cluster({
    int idWidth = 4,
    int? readIdWidth,
    int? writeIdWidth,
    int addrWidth = 32,
    int lenWidth = 8,
    int userWidth = 32,
    int? arUserWidth,
    int? rUserWidth,
    int? awUserWidth,
    int? wUserWidth,
    int? bUserWidth,
    bool useLock = false,
    int dataWidth = 64,
    int? snoopDataWidth,
    bool useLast = true,
    int? domainWidth,
    bool useBar = true,
    this.legacyMode = true,
  })  : _idWidth = idWidth,
        _userWidth = userWidth,
        super(
            read: Ace4ReadCluster(
                idWidth: readIdWidth ?? idWidth,
                addrWidth: addrWidth,
                lenWidth: lenWidth,
                useLock: useLock,
                userWidth: userWidth,
                arUserWidth: arUserWidth,
                rUserWidth: rUserWidth,
                dataWidth: dataWidth,
                useLast: useLast,
                domainWidth: domainWidth,
                useBar: useBar,
                legacyMode: legacyMode),
            write: Ace4WriteCluster(
                idWidth: writeIdWidth ?? idWidth,
                addrWidth: addrWidth,
                lenWidth: lenWidth,
                useLock: useLock,
                userWidth: userWidth,
                awUserWidth: awUserWidth,
                wUserWidth: wUserWidth,
                bUserWidth: bUserWidth,
                dataWidth: dataWidth,
                useLast: useLast,
                domainWidth: domainWidth,
                useBar: useBar,
                legacyMode: legacyMode)) {
    snoop = Ace4SnoopCluster(
        idWidth: legacyMode ? idWidth : null,
        addrWidth: addrWidth,
        userWidth: legacyMode ? userWidth : null,
        dataWidth: snoopDataWidth ?? dataWidth,
        domainWidth: legacyMode ? domainWidth : null,
        useBar: legacyMode ? useBar : null,
        legacyMode: legacyMode);
    addSubInterface('SNOOP', snoop);
    if (!legacyMode) {
      setPorts([Logic.port('RACK'), Logic.port('WACK')],
          [PairDirection.fromProvider]);
    }
  }

  /// Copy constructor.
  @override
  Ace4Cluster clone() => Ace4Cluster(
      idWidth: _idWidth,
      readIdWidth: read.arIntf.idWidth,
      writeIdWidth: write.awIntf.idWidth,
      addrWidth: read.arIntf.addrWidth,
      lenWidth: read.arIntf.lenWidth,
      userWidth: _userWidth,
      arUserWidth: read.arIntf.userWidth,
      rUserWidth: read.rIntf.userWidth,
      awUserWidth: write.awIntf.userWidth,
      wUserWidth: write.wIntf.userWidth,
      bUserWidth: write.bIntf.userWidth,
      useLast: read.rIntf.useLast,
      useLock: read.arIntf.useLock,
      dataWidth: read.rIntf.dataWidth,
      snoopDataWidth: snoop.cdIntf.dataWidth,
      domainWidth: (read.arIntf as Ace4RequestChannel).domainWidth,
      useBar: (read.arIntf as Ace4RequestChannel).useBar,
      legacyMode: legacyMode);
}
