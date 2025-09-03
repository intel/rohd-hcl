// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ace4_lite.dart
// Definitions for the ACE-Lite extension on the AXI interface.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Abstraction on top of the request interface adding coherency signals.
///
/// This is mostly the same as AXI-4 but with some coherency additions.
mixin Ace4RequestChannel on Axi4RequestChannelInterface {
  /// Width of the coherency domain signal.
  int get domainWidth;

  /// Should the ARBAR signal be present.
  bool get useBar;

  /// Coherency domain.
  ///
  /// Width is equal to [domainWidth].
  Logic? get domain => tryPort('${prefix}DOMAIN');

  /// Coherency barrier.
  ///
  /// Width is always 1.
  Logic? get bar => tryPort('${prefix}BAR');

  /// Helper to instantiate ACE specific request ports.
  @protected
  void makeAcePorts() {
    setPorts([
      if (domainWidth > 0) Logic.port('${prefix}DOMAIN', domainWidth),
      if (useBar) Logic.port('${prefix}BAR'),
    ], [
      PairDirection.fromProvider,
    ]);
  }
}

/// ACE-Lite AR interface.
///
/// This is mostly the same as AXI-4 but with some coherency additions.
class Ace4LiteArChannelInterface extends Axi4BaseArChannelInterface
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
  Ace4LiteArChannelInterface({
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
  Ace4LiteArChannelInterface clone() => Ace4LiteArChannelInterface(
      idWidth: idWidth,
      addrWidth: addrWidth,
      lenWidth: lenWidth,
      userWidth: userWidth,
      useLock: useLock,
      domainWidth: domainWidth,
      useBar: useBar);
}

/// ACE-Lite AW interface.
///
/// This is mostly the same as AXI-4 but with some coherency additions.
class Ace4LiteAwChannelInterface extends Axi4BaseAwChannelInterface
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
  Ace4LiteAwChannelInterface({
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
  Ace4LiteAwChannelInterface clone() => Ace4LiteAwChannelInterface(
      idWidth: idWidth,
      addrWidth: addrWidth,
      lenWidth: lenWidth,
      userWidth: userWidth,
      useLock: useLock,
      domainWidth: domainWidth,
      useBar: useBar);
}

/// ACE-Lite R interface.
///
/// This is mostly the same as AXI-4 but with some coherency additions.
class Ace4LiteRChannelInterface extends Axi4BaseRChannelInterface {
  /// Constructor.
  ///
  /// Should match regular AXI4 but with DOMAIN and BAR.
  Ace4LiteRChannelInterface({
    super.idWidth = 4,
    super.userWidth = 32,
    super.useLast = true,
    super.dataWidth = 64,
  }) : super(
          respWidth: 2,
        );

  /// Copy constructor.
  Ace4LiteRChannelInterface clone() => Ace4LiteRChannelInterface(
      idWidth: idWidth,
      userWidth: userWidth,
      useLast: useLast,
      dataWidth: dataWidth);
}

/// ACE-Lite W interface.
///
/// This is mostly the same as AXI-4 but with some coherency additions.
class Ace4LiteWChannelInterface extends Axi4BaseWChannelInterface {
  /// Constructor.
  ///
  /// Should match regular AXI4 but with DOMAIN and BAR.
  Ace4LiteWChannelInterface({
    super.idWidth = 4,
    super.userWidth = 32,
    super.useLast = true,
    super.dataWidth = 64,
  });

  /// Copy constructor.
  Ace4LiteWChannelInterface clone() => Ace4LiteWChannelInterface(
      idWidth: idWidth,
      userWidth: userWidth,
      useLast: useLast,
      dataWidth: dataWidth);
}

/// ACE-Lite B interface.
///
/// This is mostly the same as AXI-4 but with some coherency additions.
class Ace4LiteBChannelInterface extends Axi4BaseBChannelInterface {
  /// Constructor.
  ///
  /// Should match regular AXI4 but with DOMAIN and BAR.
  Ace4LiteBChannelInterface({
    super.idWidth = 4,
    super.userWidth = 16,
  }) : super(
          respWidth: 2,
        );

  /// Copy constructor.
  Ace4LiteBChannelInterface clone() =>
      Ace4LiteBChannelInterface(idWidth: idWidth, userWidth: userWidth);
}

/// ACE4-Lite read cluster.
class Ace4LiteReadCluster extends Axi4BaseReadCluster {
  /// Constructor.
  Ace4LiteReadCluster({
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
            arIntf: Ace4LiteArChannelInterface(
                idWidth: idWidth,
                addrWidth: addrWidth,
                lenWidth: lenWidth,
                useLock: useLock,
                userWidth: userWidth,
                domainWidth: domainWidth,
                useBar: useBar),
            rIntf: Ace4LiteRChannelInterface(
                idWidth: idWidth,
                userWidth: userWidth,
                dataWidth: dataWidth,
                useLast: useLast));

  /// Copy constructor.
  Ace4LiteReadCluster clone() => Ace4LiteReadCluster(
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

/// ACE4-Lite write cluster.
class Ace4LiteWriteCluster extends Axi4BaseWriteCluster {
  /// Constructor.
  Ace4LiteWriteCluster({
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
            awIntf: Ace4LiteAwChannelInterface(
                idWidth: idWidth,
                addrWidth: addrWidth,
                lenWidth: lenWidth,
                useLock: useLock,
                userWidth: userWidth,
                domainWidth: domainWidth,
                useBar: useBar),
            wIntf: Ace4LiteWChannelInterface(
                idWidth: idWidth,
                userWidth: userWidth,
                dataWidth: dataWidth,
                useLast: useLast),
            bIntf: Ace4LiteBChannelInterface(
                idWidth: idWidth, userWidth: userWidth));

  /// Copy constructor.
  Ace4LiteWriteCluster clone() => Ace4LiteWriteCluster(
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

/// ACE4-Lite cluster.
class Ace4LiteCluster extends Axi4BaseCluster {
  /// Constructor.
  Ace4LiteCluster({
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
            read: Ace4LiteReadCluster(
                idWidth: idWidth,
                addrWidth: addrWidth,
                lenWidth: lenWidth,
                useLock: useLock,
                userWidth: userWidth,
                dataWidth: dataWidth,
                useLast: useLast,
                domainWidth: domainWidth,
                useBar: useBar),
            write: Ace4LiteWriteCluster(
                idWidth: idWidth,
                addrWidth: addrWidth,
                lenWidth: lenWidth,
                useLock: useLock,
                userWidth: userWidth,
                dataWidth: dataWidth,
                useLast: useLast,
                domainWidth: domainWidth,
                useBar: useBar));

  /// Copy constructor.
  Ace4LiteCluster clone() => Ace4LiteCluster(
        idWidth: read.arIntf.idWidth,
        addrWidth: read.arIntf.addrWidth,
        lenWidth: read.arIntf.lenWidth,
        userWidth: read.arIntf.userWidth,
        useLast: read.rIntf.useLast,
        useLock: read.arIntf.useLock,
        dataWidth: read.rIntf.dataWidth,
        domainWidth: (read.arIntf as Ace4RequestChannel).domainWidth,
        useBar: (read.arIntf as Ace4RequestChannel).useBar,
      );
}
