// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// msi.dart
// Definitions for the MSI AXI-S interface.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';

/// A standard AXI5 MSI interface.
class Axi5MsiInterface extends Axi5StreamInterface {
  /// Construct a new instance of an MSI interface.
  ///
  /// Default values in constructor are from official spec.
  Axi5MsiInterface({
    super.useWakeup = false,
  }) : super(
            idWidth: 0,
            dataWidth: 64,
            userWidth: 0,
            destWidth: 0,
            useKeep: false,
            useStrb: false,
            useLast: false);

  /// Constructs a new [Axi5MsiInterface] with identical parameters.
  @override
  Axi5MsiInterface clone() => Axi5MsiInterface(useWakeup: useWakeup);
}
