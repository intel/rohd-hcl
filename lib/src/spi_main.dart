// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_main.dart
// Definitions for the SPI interface.
//
// 2024 October 1
// Author: Roberto Torres <roberto.torres@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Main component for SPI Interface.
class SpiMain extends Module {
  ///
  SpiMain(Logic bus, SpiInterface intf,
      {required Logic clk, required Logic reset, required Logic start}) {
    bus = addInput('bus', bus, width: bus.width);

    intf = SpiInterface.clone(intf)
      ..pairConnectIO(this, intf, PairRole.provider);

    // Convert Logic bus into a LogicArray of bits
    final busArray = LogicArray([bus.width], 1);
    for (var i = 0; i < bus.width; i++) {
      busArray.elements[i] <= bus[i];
    }

    //
    final isRunning = Logic(name: 'isRunning');

    final serializer = Serializer(busArray,
        clk: clk, reset: reset, enable: isRunning, flopInput: true);

    isRunning <= flop(clk, Const(1), en: start, reset: reset | serializer.done);

    intf.sclk <= clk & isRunning;
    intf.cs <= ~isRunning;
    intf.mosi <= serializer.serialized;
  }
}
// shift register for miso

// Knob for SPI data lenght, SPI mode, CS qty
