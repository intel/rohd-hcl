// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_lite.dart
// Definitions for the AXI-Lite interface.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';

/// A standard AXI4-Lite read interface.
class Axi4LiteReadInterface extends Axi4BaseReadInterface {
  /// Construct a new instance of an AXI4 interface.
  ///
  /// Default values in constructor are from official spec.
  Axi4LiteReadInterface({
    super.addrWidth = 32,
    super.dataWidth = 64,
    super.useLast = true,
  }) : super(
          aruserWidth: 0,
          idWidth: 0,
          lenWidth: 0,
          ruserWidth: 0,
          useLock: false,
          sizeWidth: 0,
          burstWidth: 0,
          cacheWidth: 0,
          protWidth: 3,
          qosWidth: 0,
          regionWidth: 0,
          rrespWidth: 2,
        );
}

/// A standard AXI4-Lite read interface.
class Axi4LiteWriteInterface extends Axi4BaseWriteInterface {
  /// Construct a new instance of an AXI4 interface.
  ///
  /// Default values in constructor are from official spec.
  Axi4LiteWriteInterface({
    super.addrWidth = 32,
    super.dataWidth = 64,
  }) : super(
          awuserWidth: 0,
          idWidth: 0,
          lenWidth: 0,
          wuserWidth: 0,
          buserWidth: 0,
          useLock: false,
          sizeWidth: 0,
          burstWidth: 0,
          cacheWidth: 0,
          protWidth: 3,
          qosWidth: 0,
          regionWidth: 0,
          brespWidth: 2,
        );
}
