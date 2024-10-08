// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_main.dart
// Implementation of SPI Main component.
//
// 2024 October 1
// Author: Roberto Torres <roberto.torres@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Main component for SPI Interface.
class SpiMain extends Module {
  ///
  SpiMain(Logic busIn, Logic busOut, SpiInterface intf,
      {required Logic clk, required Logic reset, required Logic start}) {
    busIn = addInput('bus', busIn, width: busIn.width);

    busOut = addOutput('busOut', width: busOut.width);

    intf = SpiInterface.clone(intf)
      ..pairConnectIO(this, intf, PairRole.provider);

    // Convert Logic bus into a LogicArray of bits
    final busInArray = LogicArray([busIn.width], 1);
    for (var i = 0; i < busIn.width; i++) {
      busInArray.elements[i] <= busIn[i];
    }

    //
    final isRunning = Logic(name: 'isRunning');

    // Serializes busInArray
    final serializer = Serializer(busInArray,
        clk: clk, reset: reset, enable: isRunning, flopInput: true);

    isRunning <= flop(clk, Const(1), en: start, reset: reset | serializer.done);

    // Shift register in from MISO
    final srMiso =
        ShiftRegister(intf.miso, clk: intf.sclk, depth: intf.dataLength);

    busOut <= srMiso.dataOut;

    intf.sclk <= clk & isRunning;
    intf.cs <= ~isRunning;
    intf.mosi <= serializer.serialized;
  }
}
// shift register for miso

// Knob for SPI data lenght, SPI mode, CS qty
