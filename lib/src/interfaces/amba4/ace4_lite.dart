// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ace4_lite.dart
// Definitions for the ACE-Lite extension on the AXI interface.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Abstraction on top of the request interface adding coherency signals.
///
/// This is mostly the same as AXI-4 but with some coherency additions.
abstract class Ace4BaseRequestChannelInterface
    extends Axi4RequestChannelInterface {
  /// Width of the coherency domain signal.
  final int domainWidth;

  /// Should the ARBAR signal be present.
  final bool useBar;

  /// Coherency domain.
  ///
  /// Width is equal to [domainWidth].
  Logic? get domain => tryPort('${prefix}DOMAIN');

  /// Coherency barrier.
  ///
  /// Width is always 1.
  Logic? get bar => tryPort('${prefix}BAR');

  /// Constructor.
  ///
  /// Should match regular AXI4 but with DOMAIN and BAR.
  Ace4BaseRequestChannelInterface({
    required super.prefix,
    super.idWidth = 4,
    super.addrWidth = 32,
    super.lenWidth = 8,
    super.userWidth = 32,
    super.useLock = true,
    this.domainWidth = 1,
    this.useBar = true,
  }) : super(
          sizeWidth: 3,
          burstWidth: 2,
          cacheWidth: 4,
          protWidth: 3,
          qosWidth: 4,
          regionWidth: 4,
        ) {
    setPorts([
      if (domainWidth > 0) Logic.port('${prefix}DOMAIN', domainWidth),
      if (useBar) Logic.port('${prefix}BAR'),
    ], [
      Axi4Direction.fromMain,
    ]);
  }
}

/// ACE-Lite AR interface.
///
/// This is mostly the same as AXI-4 but with some coherency additions.
class Ace4LiteArChannelInterface extends Ace4BaseRequestChannelInterface {
  /// Constructor.
  ///
  /// Should match regular AXI4 but with DOMAIN and BAR.
  Ace4LiteArChannelInterface({
    super.idWidth = 4,
    super.addrWidth = 32,
    super.lenWidth = 8,
    super.userWidth = 32,
    super.useLock = true,
    super.domainWidth = 1,
    super.useBar = true,
  }) : super(
          prefix: 'AR',
        );

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
class Ace4LiteAwChannelInterface extends Ace4BaseRequestChannelInterface {
  /// Constructor.
  ///
  /// Should match regular AXI4 but with DOMAIN and BAR.
  Ace4LiteAwChannelInterface({
    super.idWidth = 4,
    super.addrWidth = 32,
    super.lenWidth = 8,
    super.userWidth = 32,
    super.useLock = true,
    super.domainWidth = 1,
    super.useBar = true,
  }) : super(prefix: 'AW');

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

// TODO
class Ace4LiteReadCluster extends Axi4BaseReadCluster {
  Ace4LiteReadCluster({
    int idWidth = 4,
    int addrWidth = 32,
    int lenWidth = 8,
    int userWidth = 32,
    bool useLock = false,
    int dataWidth = 64,
    bool useLast = true,
  }) : super(
            arIntf: Ace4LiteArChannelInterface(
                idWidth: idWidth,
                addrWidth: addrWidth,
                lenWidth: lenWidth,
                useLock: useLock,
                userWidth: userWidth),
            rIntf: Ace4LiteRChannelInterface(
                idWidth: idWidth,
                userWidth: userWidth,
                dataWidth: dataWidth,
                useLast: useLast));
}
