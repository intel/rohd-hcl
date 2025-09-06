// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_lite.dart
// Definitions for the AXI-Lite interface.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';

/// A standard AXI4-Lite AR interface.
class Axi4LiteArChannelInterface extends Axi4BaseArChannelInterface {
  /// Construct a new instance of an AXI4 interface.
  ///
  /// Default values in constructor are from official spec.
  Axi4LiteArChannelInterface({
    super.addrWidth = 32,
  }) : super(
          userWidth: 0,
          idWidth: 0,
          lenWidth: 0,
          useLock: false,
          sizeWidth: 0,
          burstWidth: 0,
          cacheWidth: 0,
          protWidth: 3,
          qosWidth: 0,
          regionWidth: 0,
        );

  /// Copy constructor.
  Axi4LiteArChannelInterface clone() =>
      Axi4LiteArChannelInterface(addrWidth: addrWidth);
}

/// A standard AXI4-Lite AW interface.
class Axi4LiteAwChannelInterface extends Axi4BaseAwChannelInterface {
  /// Construct a new instance of an AXI4 interface.
  ///
  /// Default values in constructor are from official spec.
  Axi4LiteAwChannelInterface({
    super.addrWidth = 32,
  }) : super(
          idWidth: 0,
          lenWidth: 0,
          userWidth: 0,
          useLock: false,
          sizeWidth: 0,
          burstWidth: 0,
          cacheWidth: 0,
          protWidth: 3,
          qosWidth: 0,
          regionWidth: 0,
        );

  /// Copy constructor.
  Axi4LiteAwChannelInterface clone() =>
      Axi4LiteAwChannelInterface(addrWidth: addrWidth);
}

/// A standard AXI4-Lite R interface.
class Axi4LiteRChannelInterface extends Axi4BaseRChannelInterface {
  /// Construct a new instance of an AXI4 interface.
  ///
  /// Default values in constructor are from official spec.
  Axi4LiteRChannelInterface({
    super.dataWidth = 64,
    super.useLast = true,
  }) : super(
          idWidth: 0,
          userWidth: 0,
          respWidth: 2,
        );

  /// Copy constructor.
  Axi4LiteRChannelInterface clone() =>
      Axi4LiteRChannelInterface(dataWidth: dataWidth, useLast: useLast);
}

/// A standard AXI4-Lite W interface.
class Axi4LiteWChannelInterface extends Axi4BaseWChannelInterface {
  /// Construct a new instance of an AXI4 interface.
  ///
  /// Default values in constructor are from official spec.
  Axi4LiteWChannelInterface({
    super.dataWidth = 64,
    super.useLast = true,
  }) : super(
          idWidth: 0,
          userWidth: 0,
        );

  /// Copy constructor.
  Axi4LiteWChannelInterface clone() =>
      Axi4LiteWChannelInterface(dataWidth: dataWidth, useLast: useLast);
}

/// A standard AXI4-Lite B interface.
class Axi4LiteBChannelInterface extends Axi4BaseBChannelInterface {
  /// Construct a new instance of an AXI4 interface.
  ///
  /// Default values in constructor are from official spec.
  Axi4LiteBChannelInterface()
      : super(
          idWidth: 0,
          userWidth: 0,
          respWidth: 2,
        );

  /// Copy constructor.
  Axi4LiteBChannelInterface clone() => Axi4LiteBChannelInterface();
}

/// AXI4-Lite read cluster.
class Axi4LiteReadCluster extends Axi4BaseReadCluster {
  /// Constructor.
  Axi4LiteReadCluster({
    int addrWidth = 32,
    int dataWidth = 64,
    bool useLast = true,
  }) : super(
            arIntf: Axi4LiteArChannelInterface(addrWidth: addrWidth),
            rIntf: Axi4LiteRChannelInterface(
                dataWidth: dataWidth, useLast: useLast));

  /// Copy constructor.
  Axi4LiteReadCluster clone() => Axi4LiteReadCluster(
        addrWidth: arIntf.addrWidth,
        useLast: rIntf.useLast,
        dataWidth: rIntf.dataWidth,
      );
}

/// AXI4-Lite write cluster.
class Axi4LiteWriteCluster extends Axi4BaseWriteCluster {
  /// Constructor.
  Axi4LiteWriteCluster({
    int addrWidth = 32,
    int dataWidth = 64,
    bool useLast = true,
  }) : super(
            awIntf: Axi4LiteAwChannelInterface(
              addrWidth: addrWidth,
            ),
            wIntf: Axi4LiteWChannelInterface(
                dataWidth: dataWidth, useLast: useLast),
            bIntf: Axi4LiteBChannelInterface());

  /// Copy constructor.
  Axi4LiteWriteCluster clone() => Axi4LiteWriteCluster(
        addrWidth: awIntf.addrWidth,
        useLast: wIntf.useLast,
        dataWidth: wIntf.dataWidth,
      );
}

/// AXI4-Lite cluster.
class Axi4LiteCluster extends Axi4BaseCluster {
  /// Constructor.
  Axi4LiteCluster({
    int addrWidth = 32,
    int dataWidth = 64,
    bool useLast = true,
  }) : super(
            read: Axi4LiteReadCluster(
                addrWidth: addrWidth, dataWidth: dataWidth, useLast: useLast),
            write: Axi4LiteWriteCluster(
                addrWidth: addrWidth, dataWidth: dataWidth, useLast: useLast));

  /// Copy constructor.
  Axi4LiteCluster clone() => Axi4LiteCluster(
        addrWidth: read.arIntf.addrWidth,
        useLast: read.rIntf.useLast,
        dataWidth: read.rIntf.dataWidth,
      );
}
