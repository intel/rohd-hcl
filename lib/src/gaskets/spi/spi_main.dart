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
  Logic get busOut => output('busOut');

  ///
  Logic get done => output('done');

  ///
  SpiMain(Logic busIn, SpiInterface intf,
      {required Logic clk,
      required Logic reset,
      required Logic start,
      super.name = 'spiMain'}) {
    busIn = addInput('busIn', busIn, width: busIn.width);

    clk = addInput('clk', clk);

    reset = addInput('reset', reset);

    start = addInput('start', start);

    addOutput('busOut', width: busIn.width);

    addOutput('done');

    intf = SpiInterface.clone(intf)
      ..pairConnectIO(this, intf, PairRole.provider);

    // Convert Logic bus into a LogicArray of bits
    final busInArray = LogicArray([busIn.width], 1);
    for (var i = 0; i < busIn.width; i++) {
      busInArray.elements[i] <= busIn[i];
    }

    //
    final isRunning = Logic(name: 'isRunning');

    // Serializes busInArray.
    final serializer = Serializer(busInArray,
        clk: clk,
        reset: reset,
        enable: start | (isRunning & ~done),
        flopInput: true);

    // Will run when start is pulsed high, reset on reset or when serializer is done
    isRunning <=
        flop(clk, Const(1),
            en: start, reset: reset | (serializer.done & ~start));

    done <= serializer.done;

    // Shift register in from MISO.
    final shiftReg =
        ShiftRegister(intf.miso, clk: intf.sclk, depth: intf.dataLength);

    // Each busOut bit is connected to the corresponding shift Register stage
    busOut <= shiftReg.stages.swizzle();

    // Sclk runs off clk when isRunning is true
    intf.sclk <= clk & isRunning;

    // CS is active low. It will go low when isRunning is high
    intf.cs <= ~(isRunning | start);

    // Mosi is connected to the serializer output.
    intf.mosi <= flop(~intf.sclk, serializer.serialized);
  }
}

// Knob for SPI data lenght, SPI mode, CS qty
