// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_sub.dart
// Implementation of SPI Sub component.
//
// 2024 October 4
// Author: Roberto Torres <roberto.torres@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Main component for SPI Interface.
class SpiSub extends Module {
  ///
  SpiSub(Logic busIn, Logic busOut, Logic reset, SpiInterface intf) {
    // SPI Interface
    intf = SpiInterface.clone(intf)
      ..pairConnectIO(this, intf, PairRole.consumer);

    // Bus Input to Sub
    busIn = addInput('busIn', busIn, width: intf.dataLength);

    // Bus Output from Sub
    busOut = addOutput('busOut', width: intf.dataLength);

    // Shift Register in from MOSI
    final srMosi = ShiftRegister(intf.mosi,
        clk: intf.sclk, depth: intf.dataLength, reset: reset);

    // Shift Register out to MISO
    final srMiso = ShiftRegister(busIn,
        clk: intf.sclk, depth: intf.dataLength, reset: reset);

    intf.miso <= srMiso.dataOut;
    busOut <= srMosi.dataOut;
  }
}
