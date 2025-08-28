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

/// ACE-Lite read interface.
///
/// This is mostly the same as AXI-4 but with some coherency additions.
class Ace4LiteReadInterface extends Axi4BaseReadInterface {
  /// Width of the coherency domain signal.
  final int domainWidth;

  /// Should the ARBAR signal be present.
  final bool useBar;

  /// Coherency domain.
  ///
  /// Width is equal to [domainWidth].
  Logic? get arDomain => tryPort('ARDOMAIN');

  /// Coherency barrier.
  ///
  /// Width is always 1.
  Logic? get arBar => tryPort('ARBAR');

  /// Constructor.
  ///
  /// Should match regular AXI4 but with DOMAIN and BAR.
  Ace4LiteReadInterface({
    super.idWidth = 4,
    super.addrWidth = 32,
    super.lenWidth = 8,
    super.dataWidth = 64,
    super.aruserWidth = 32,
    super.ruserWidth = 32,
    super.useLock = true,
    super.useLast = true,
    this.domainWidth = 1,
    this.useBar = true,
  }) : super(
          sizeWidth: 3,
          burstWidth: 2,
          cacheWidth: 4,
          protWidth: 3,
          qosWidth: 4,
          regionWidth: 4,
          rrespWidth: 2,
        ) {
    setPorts([
      if (domainWidth > 0) Logic.port('ARDOMAIN', domainWidth),
      if (useBar) Logic.port('ARBAR'),
    ], [
      Axi4Direction.fromMain,
    ]);
  }

  /// Copy constructor.
  Ace4LiteReadInterface clone() => Ace4LiteReadInterface(
      idWidth: idWidth,
      addrWidth: addrWidth,
      lenWidth: lenWidth,
      dataWidth: dataWidth,
      aruserWidth: aruserWidth,
      ruserWidth: ruserWidth,
      useLock: useLock,
      useLast: useLast,
      domainWidth: domainWidth,
      useBar: useBar);
}

/// ACE-Lite write interface.
///
/// This is mostly the same as AXI-4 but with some coherency additions.
class Ace4LiteWriteInterface extends Axi4BaseWriteInterface {
  /// Width of the coherency domain signal.
  final int domainWidth;

  /// Should the ARBAR signal be present.
  final bool useBar;

  /// Coherency domain.
  ///
  /// Width is equal to [domainWidth].
  Logic? get arDomain => tryPort('AWDOMAIN');

  /// Coherency barrier.
  ///
  /// Width is always 1.
  Logic? get arBar => tryPort('AWBAR');

  /// Constructor.
  ///
  /// Should match regular AXI4 but with DOMAIN and BAR.
  Ace4LiteWriteInterface({
    super.idWidth = 4,
    super.addrWidth = 32,
    super.lenWidth = 8,
    super.dataWidth = 64,
    super.awuserWidth = 32,
    super.wuserWidth = 32,
    super.buserWidth = 16,
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
          brespWidth: 2,
        ) {
    setPorts([
      if (domainWidth > 0) Logic.port('AWDOMAIN', domainWidth),
      if (useBar) Logic.port('AWBAR'),
    ], [
      Axi4Direction.fromMain,
    ]);
  }

  /// Copy constructor.
  Ace4LiteWriteInterface clone() => Ace4LiteWriteInterface(
      idWidth: idWidth,
      addrWidth: addrWidth,
      lenWidth: lenWidth,
      dataWidth: dataWidth,
      awuserWidth: awuserWidth,
      wuserWidth: wuserWidth,
      buserWidth: buserWidth,
      useLock: useLock,
      domainWidth: domainWidth,
      useBar: useBar);
}
