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
  /// Output bus from Main.
  Logic get busOut => output('busOut');

  /// Done signal from Main.
  Logic get done => output('done');

  /// Constructs a SPI Main component.
  SpiMain(SpiInterface intf,
      {required Logic clk,
      required Logic reset,
      required Logic start,
      required Logic busIn,
      super.name = 'spiMain'}) {
    busIn = addInput('busIn', busIn, width: busIn.width);

    clk = addInput('clk', clk);

    reset = addInput('reset', reset);

    start = addInput('start', start);

    addOutput('busOut', width: busIn.width);

    addOutput('done');

    intf = SpiInterface.clone(intf)
      ..pairConnectIO(this, intf, PairRole.provider);

    final isRunning = Logic(name: 'isRunning');

    final count = Counter.simple(
        clk: ~clk,
        // enable: start | (isRunning & ~done),
        enable: start | isRunning,
        reset: reset,
        minValue: 1,
        maxValue: busIn.width);

    // done <= flop(~clk, count.equalsMax, reset: reset, asyncReset: true);
    done <= count.equalsMax;
    // Will run when start is pulsed high, reset on reset or when serializer is
    // done and start is low.
    isRunning <=
        flop(
          clk,
          // start | (isRunning & ~done),
          start | ~done,
          // en: start,
          reset: reset,
          asyncReset: true,
        );

    // Shift register in from MISO.
    final shiftReg = ShiftRegister(
      intf.miso,
      clk: intf.sclk,
      depth: intf.dataLength,
      reset: reset,
      asyncReset: true,
      resetValue: busIn.elements,
    );

    // Each busOut bit is connected to the corresponding shift Register stage
    busOut <= shiftReg.stages.rswizzle();

    // Sclk runs off clk when isRunning is true or start is pulsed high.
    intf.sclk <= ~clk & (isRunning | start);

    // CS is active low. It will go low when isRunning or start is pulsed high.
    intf.csb <= ~(isRunning | start);

    // Mosi is connected to the serializer output.
    intf.mosi <=
        flop(~intf.sclk, shiftReg.dataOut,
            reset: reset, asyncReset: true, resetValue: busIn[-1]);
  }
}
