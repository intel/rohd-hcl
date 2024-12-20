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

/// Sub component for SPI Interface.
class SpiSub extends Module {
  /// Output bus from Sub.
  Logic get busOut => output('busOut');

  ///
  SpiSub(
      {required SpiInterface intf,
      Logic? busIn,
      Logic? reset,
      super.name = 'spiSub'}) {
    // SPI Interface
    intf = SpiInterface.clone(intf)
      ..pairConnectIO(this, intf, PairRole.consumer);

    // Bus Input to sub, if provided.
    if (busIn != null) {
      busIn = addInput('busIn', busIn, width: intf.dataLength);
    }

    // Reset signal for sub, if provided.
    // will need to be toggled to load new busIn values
    if (reset != null) {
      reset = addInput('reset', reset);
    }

    // Bus Output from Sub
    addOutput('busOut', width: intf.dataLength);

    // Shift Register
    final shiftReg = ShiftRegister(
      intf.mosi,
      enable: ~intf.csb,
      clk: intf.sclk,
      depth: intf.dataLength,
      reset: reset,
      asyncReset: true,
      resetValue: busIn?.elements,
    );

    // BusOut is connected to the stages of the shift register
    busOut <= shiftReg.stages.rswizzle();

    intf.miso <=
        flop(~intf.sclk, shiftReg.dataOut,
            en: ~intf.csb,
            reset: reset,
            asyncReset: true,
            resetValue: busIn?[-1]);
  }
}
