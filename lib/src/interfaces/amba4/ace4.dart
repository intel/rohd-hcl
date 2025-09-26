// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ace4.dart
// Definitions for the ACE extension on the AXI interface.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// ACE AR interface.
///
/// This is mostly the same as AXI-4 but with some coherency additions.
class Ace4ArChannelInterface extends Axi4BaseArChannelInterface
    with Ace4RequestChannel {
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
    this.domainWidth = 1,
    this.useBar = true,
  }) {
    makeAcePorts();
  }

  /// Copy constructor.
  Ace4ArChannelInterface clone() => Ace4ArChannelInterface(
      idWidth: idWidth,
      addrWidth: addrWidth,
      lenWidth: lenWidth,
      userWidth: userWidth,
      useLock: useLock,
      domainWidth: domainWidth,
      useBar: useBar);
}

/// ACE AW interface.
///
/// This is mostly the same as AXI-4 but with some coherency additions.
class Ace4AwChannelInterface extends Axi4BaseAwChannelInterface
    with Ace4RequestChannel {
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
    this.domainWidth = 1,
    this.useBar = true,
  }) {
    makeAcePorts();
  }

  /// Copy constructor.
  Ace4AwChannelInterface clone() => Ace4AwChannelInterface(
      idWidth: idWidth,
      addrWidth: addrWidth,
      lenWidth: lenWidth,
      userWidth: userWidth,
      useLock: useLock,
      domainWidth: domainWidth,
      useBar: useBar);
}

/// ACE AC interface.
///
/// For snoop requests.
class Ace4AcChannelInterface extends Axi4RequestChannelInterface
    with Ace4RequestChannel {
  /// Width of the coherency domain signal.
  @override
  final int domainWidth;

  /// Should the ARBAR signal be present.
  @override
  final bool useBar;

  /// Constructor.
  Ace4AcChannelInterface({
    super.idWidth = 4,
    super.addrWidth = 32,
    super.userWidth = 32,
    this.domainWidth = 1,
    this.useBar = true,
  }) : super(
            prefix: 'AC',
            lenWidth: 0,
            sizeWidth: 3,
            burstWidth: 2,
            cacheWidth: 4,
            protWidth: 3,
            qosWidth: 0,
            regionWidth: 0,
            useLock: false) {
    makeAcePorts();
  }

  /// Copy constructor.
  Ace4AcChannelInterface clone() => Ace4AcChannelInterface(
      idWidth: idWidth,
      addrWidth: addrWidth,
      userWidth: userWidth,
      domainWidth: domainWidth,
      useBar: useBar);
}

/// ACE R interface.
///
/// This is mostly the same as AXI-4 but with some coherency additions.
class Ace4RChannelInterface extends Axi4BaseRChannelInterface {
  /// Constructor.
  ///
  /// Should match regular AXI4 but with DOMAIN and BAR.
  Ace4RChannelInterface({
    super.idWidth = 4,
    super.userWidth = 32,
    super.useLast = true,
    super.dataWidth = 64,
  }) : super(
          respWidth: 2,
        );

  /// Copy constructor.
  Ace4RChannelInterface clone() => Ace4RChannelInterface(
      idWidth: idWidth,
      userWidth: userWidth,
      useLast: useLast,
      dataWidth: dataWidth);
}

/// ACE W interface.
///
/// This is mostly the same as AXI-4 but with some coherency additions.
class Ace4WChannelInterface extends Axi4BaseWChannelInterface {
  /// Constructor.
  ///
  /// Should match regular AXI4 but with DOMAIN and BAR.
  Ace4WChannelInterface({
    super.idWidth = 4,
    super.userWidth = 32,
    super.useLast = true,
    super.dataWidth = 64,
  });

  /// Copy constructor.
  Ace4WChannelInterface clone() => Ace4WChannelInterface(
      idWidth: idWidth,
      userWidth: userWidth,
      useLast: useLast,
      dataWidth: dataWidth);
}

/// ACE CD interface.
///
/// For snoop data.
class Ace4CdChannelInterface extends Axi4DataChannelInterface {
  /// Constructor.
  Ace4CdChannelInterface({
    super.idWidth = 4,
    super.dataWidth = 64,
    super.userWidth = 32,
  }) : super(
          main: false,
          prefix: 'CD',
          useLast: true,
        );

  /// Copy constructor.
  Ace4CdChannelInterface clone() => Ace4CdChannelInterface(
      idWidth: idWidth, dataWidth: dataWidth, userWidth: userWidth);
}

/// ACE B interface.
///
/// This is mostly the same as AXI-4 but with some coherency additions.
class Ace4BChannelInterface extends Axi4BaseBChannelInterface {
  /// Constructor.
  ///
  /// Should match regular AXI4 but with DOMAIN and BAR.
  Ace4BChannelInterface({
    super.idWidth = 4,
    super.userWidth = 16,
  }) : super(
          respWidth: 2,
        );

  /// Copy constructor.
  Ace4BChannelInterface clone() =>
      Ace4BChannelInterface(idWidth: idWidth, userWidth: userWidth);
}

/// ACE CR interface.
///
/// For snoop responses.
class Ace4CrChannelInterface extends Axi4ResponseChannelInterface {
  /// Should the CRLAST signal be present.
  final bool useLast;

  /// For multi-beat snoops, indicates the end of a beat.
  ///
  /// Width is always 1.
  Logic? get last => tryPort('${prefix}LAST');

  /// Constructor.
  Ace4CrChannelInterface({
    super.idWidth = 4,
    super.userWidth = 32,
    super.respWidth = 2,
    this.useLast = true,
  }) : super(
          prefix: 'CR',
        ) {
    setPorts([
      if (useLast) Logic.port('${prefix}LAST'),
    ], [
      PairDirection.fromConsumer,
    ]);
  }

  /// Copy constructor.
  Ace4CrChannelInterface clone() => Ace4CrChannelInterface(
      idWidth: idWidth, respWidth: respWidth, userWidth: userWidth);
}

/// ACE4 read cluster.
class Ace4ReadCluster extends Axi4BaseReadCluster {
  /// Constructor.
  Ace4ReadCluster({
    int idWidth = 4,
    int addrWidth = 32,
    int lenWidth = 8,
    int userWidth = 32,
    bool useLock = false,
    int dataWidth = 64,
    bool useLast = true,
    int domainWidth = 1,
    bool useBar = true,
  }) : super(
            arIntf: Ace4ArChannelInterface(
                idWidth: idWidth,
                addrWidth: addrWidth,
                lenWidth: lenWidth,
                useLock: useLock,
                userWidth: userWidth,
                domainWidth: domainWidth,
                useBar: useBar),
            rIntf: Ace4RChannelInterface(
                idWidth: idWidth,
                userWidth: userWidth,
                dataWidth: dataWidth,
                useLast: useLast));

  /// Copy constructor.
  Ace4ReadCluster clone() => Ace4ReadCluster(
        idWidth: arIntf.idWidth,
        addrWidth: arIntf.addrWidth,
        lenWidth: arIntf.lenWidth,
        userWidth: arIntf.userWidth,
        useLast: rIntf.useLast,
        useLock: arIntf.useLock,
        dataWidth: rIntf.dataWidth,
        domainWidth: (arIntf as Ace4RequestChannel).domainWidth,
        useBar: (arIntf as Ace4RequestChannel).useBar,
      );
}

/// ACE4 write cluster.
class Ace4WriteCluster extends Axi4BaseWriteCluster {
  /// Constructor.
  Ace4WriteCluster({
    int idWidth = 4,
    int addrWidth = 32,
    int lenWidth = 8,
    int userWidth = 32,
    bool useLock = false,
    int dataWidth = 64,
    bool useLast = true,
    int domainWidth = 1,
    bool useBar = true,
  }) : super(
            awIntf: Ace4AwChannelInterface(
                idWidth: idWidth,
                addrWidth: addrWidth,
                lenWidth: lenWidth,
                useLock: useLock,
                userWidth: userWidth,
                domainWidth: domainWidth,
                useBar: useBar),
            wIntf: Ace4WChannelInterface(
                idWidth: idWidth,
                userWidth: userWidth,
                dataWidth: dataWidth,
                useLast: useLast),
            bIntf:
                Ace4BChannelInterface(idWidth: idWidth, userWidth: userWidth));

  /// Copy constructor.
  Ace4WriteCluster clone() => Ace4WriteCluster(
        idWidth: awIntf.idWidth,
        addrWidth: awIntf.addrWidth,
        lenWidth: awIntf.lenWidth,
        userWidth: awIntf.userWidth,
        useLast: wIntf.useLast,
        useLock: awIntf.useLock,
        dataWidth: wIntf.dataWidth,
        domainWidth: (awIntf as Ace4RequestChannel).domainWidth,
        useBar: (awIntf as Ace4RequestChannel).useBar,
      );
}

/// ACE4 snoop cluster.
class Ace4SnoopCluster extends PairInterface {
  /// AC channel.
  late final Ace4AcChannelInterface acIntf;

  /// CD channel.
  late final Ace4CdChannelInterface cdIntf;

  /// CR channel.
  late final Ace4CrChannelInterface crIntf;

  /// Constructor.
  Ace4SnoopCluster({
    int idWidth = 4,
    int addrWidth = 32,
    int userWidth = 32,
    int dataWidth = 64,
    int domainWidth = 1,
    bool useBar = true,
  }) {
    acIntf = Ace4AcChannelInterface(
        idWidth: idWidth, // TODO: split??
        addrWidth: addrWidth,
        userWidth: userWidth, // TODO: split??
        domainWidth: domainWidth,
        useBar: useBar);
    cdIntf = Ace4CdChannelInterface(
        idWidth: idWidth, userWidth: userWidth, dataWidth: dataWidth);
    crIntf = Ace4CrChannelInterface(idWidth: idWidth, userWidth: userWidth);

    addSubInterface('AC', acIntf);
    addSubInterface('CD', cdIntf);
    addSubInterface('CR', crIntf);
  }

  /// Copy constructor.
  Ace4SnoopCluster clone() => Ace4SnoopCluster(
        idWidth: acIntf.idWidth,
        addrWidth: acIntf.addrWidth,
        userWidth: acIntf.userWidth,
        dataWidth: cdIntf.dataWidth,
        domainWidth: acIntf.domainWidth,
        useBar: acIntf.useBar,
      );
}

/// ACE4 cluster.
class Ace4Cluster extends Axi4BaseCluster {
  /// Snoop channels.
  late final Ace4SnoopCluster snoop;

  /// Constructor.
  ///
  /// TODO: split params??
  Ace4Cluster({
    int idWidth = 4,
    int addrWidth = 32,
    int lenWidth = 8,
    int userWidth = 32,
    bool useLock = false,
    int dataWidth = 64,
    bool useLast = true,
    int domainWidth = 1,
    bool useBar = true,
  }) : super(
            read: Ace4ReadCluster(
                idWidth: idWidth,
                addrWidth: addrWidth,
                lenWidth: lenWidth,
                useLock: useLock,
                userWidth: userWidth,
                dataWidth: dataWidth,
                useLast: useLast,
                domainWidth: domainWidth,
                useBar: useBar),
            write: Ace4WriteCluster(
                idWidth: idWidth,
                addrWidth: addrWidth,
                lenWidth: lenWidth,
                useLock: useLock,
                userWidth: userWidth,
                dataWidth: dataWidth,
                useLast: useLast,
                domainWidth: domainWidth,
                useBar: useBar)) {
    snoop = Ace4SnoopCluster(
        idWidth: idWidth,
        addrWidth: addrWidth,
        userWidth: userWidth,
        dataWidth: dataWidth,
        domainWidth: domainWidth,
        useBar: useBar);
    addSubInterface('SNOOP', snoop);
  }

  /// Copy constructor.
  Ace4Cluster clone() => Ace4Cluster(
      idWidth: read.arIntf.idWidth,
      addrWidth: read.arIntf.addrWidth,
      lenWidth: read.arIntf.lenWidth,
      userWidth: read.arIntf.userWidth,
      useLast: read.rIntf.useLast,
      useLock: read.arIntf.useLock,
      dataWidth: read.rIntf.dataWidth,
      domainWidth: snoop.acIntf.domainWidth,
      useBar: snoop.acIntf.useBar);
}
