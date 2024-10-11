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
  Logic get busOut => output('busOut');

  ///
  SpiSub({required SpiInterface intf, Logic? busIn, Logic? reset}) {
    // SPI Interface
    intf = SpiInterface.clone(intf)
      ..pairConnectIO(this, intf, PairRole.consumer);

    // Bus Input to Sub
    if (busIn != null) {
      busIn = addInput('busIn', busIn, width: intf.dataLength);
    }

    if (reset != null) {
      reset = addInput('reset', reset);
    }

    // Bus Output from Sub
    addOutput('busOut', width: intf.dataLength);

    // Shift Register
    final shiftReg = ShiftRegister(
      intf.mosi,
      clk: intf.sclk & ~intf.cs,
      depth: intf.dataLength,
      reset: reset,
      asyncReset: true,
      resetValue: busIn?.elements,
    );

    // BusOut is connected to the stages of the shift register
    busOut <= shiftReg.stages.swizzle();

    // Connect miso to the output of the shift register
    intf.miso <= shiftReg.dataOut;
  }
}
