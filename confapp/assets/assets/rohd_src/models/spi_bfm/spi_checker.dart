// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_checker.dart
// Implementation of SPI Checker component.
//
// 2025 January 22
// Author: Roberto Torres <roberto.torres@intel.com>

import 'dart:async';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Checker component for Serial Peripheral Interface (SPI).
class SpiChecker extends Component {
  /// Interface to check.
  final SpiInterface intf;

  /// Creates a SPI Checker component that interfaces with [SpiInterface].
  SpiChecker(
    this.intf, {
    required Component parent,
    String name = 'spiChecker',
  }) : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    // checking prev value at posedge
    intf.sclk.posedge.listen((event) {
      if (intf.miso.previousValue != intf.miso.value) {
        logger.severe('Data on MISO is changing on posedge of sclk');
      }
      if (intf.mosi.previousValue != intf.mosi.value) {
        logger.severe('Data on MOSI is changing on posedge of sclk');
      }
    });
  }
}
