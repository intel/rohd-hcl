// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_checker.dart
// Implementation of SPI Checker component.
//
// 2025 January 22
// Author: Roberto Torres <roberto.torres@intel.com>

import 'dart:async';
import 'package:rohd/rohd.dart';
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

    LogicValue? mosiVal;
    LogicValue? misoVal;

    // Save the value of mosi and miso on posedge
    intf.sclk.posedge.listen((event) {
      mosiVal = intf.mosi.value;
      misoVal = intf.miso.value;
    });

    // checking prev value at negedge
    intf.sclk.negedge.listen((event) {
      if (misoVal != null && misoVal != intf.miso.previousValue) {
        logger.severe('Data on MISO is changing on posedge of sclk');
      }
      if (mosiVal != null && mosiVal != intf.mosi.previousValue) {
        logger.severe('Data on MOSI is changing on posedge of sclk');
      }
    });
  }
}
