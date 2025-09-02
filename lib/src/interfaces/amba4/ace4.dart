// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ace4.dart
// Definitions for the ACE extension on the AXI interface.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';

/// ACE AR interface.
///
/// This is mostly the same as AXI-4 but with some coherency additions.
class Ace4ArChannelInterface extends Ace4BaseRequestChannelInterface {
  /// Constructor.
  ///
  /// Should match regular AXI4 but with DOMAIN and BAR.
  Ace4ArChannelInterface({
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
class Ace4AwChannelInterface extends Ace4BaseRequestChannelInterface {
  /// Constructor.
  ///
  /// Should match regular AXI4 but with DOMAIN and BAR.
  Ace4AwChannelInterface({
    super.idWidth = 4,
    super.addrWidth = 32,
    super.lenWidth = 8,
    super.userWidth = 32,
    super.useLock = true,
    super.domainWidth = 1,
    super.useBar = true,
  }) : super(prefix: 'AW');

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

// TODO: add Ace4SnoopInterface with the 3 new channels...
