// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_main.dart
// Implementation of SPI Main component.
//
// 2024 October 1
// Author: Roberto Torres <roberto.torres@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Main component for Serial Peripheral Interface (SPI).
class SpiMain extends Module {
  /// Output bus from Main.
  Logic get busOut => output('busOut');

  /// Done signal from Main.
  Logic get done => output('done');

  /// Creates a SPI Main component that interfaces with [SpiInterface].
  ///
  /// The SPI Main component will drive a clock signal on [SpiInterface.sclk],
  /// chip select on [SpiInterface.csb], shift data out on [SpiInterface.mosi],
  /// and shift data in from [SpiInterface.miso]. Data to shift out is provided
  /// on [busIn]. Data shifted in from [SpiInterface.miso] will be available on
  /// [busOut]. After data is available on [busIn], pulsing [reset] will load
  /// the data, and pulsing [start] will begin transmitting data until all bits
  /// from [busIn] are shifted out. After transmissions is complete [done]
  /// signal will go high.
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

    // Counter to track of the number of bits shifted out.
    final count = Counter.simple(
        clk: ~clk,
        enable: start | isRunning,
        reset: reset,
        asyncReset: true,
        resetValue: busIn.width - 1,
        maxValue: busIn.width - 1);

    // Done signal will be high when the counter is at the max value.
    done <= count.equalsMax;

    // isRunning will be high when start is pulsed high or counter is not done.
    isRunning <=
        flop(
          clk,
          start | ~done,
          reset: reset,
          asyncReset: true,
        );

    // Shift register in from MISO.
    // NOTE: Reset values are set to busIn values.
    final shiftReg = ShiftRegister(
      intf.miso,
      clk: intf.sclk,
      depth: intf.dataLength,
      reset: reset,
      asyncReset: true,
      resetValue: busIn.elements,
    );

    // busOut bits are connected to the corresponding shift register data stage.
    // NOTE: dataStage0 corresponds to the last bit shifted in.
    busOut <= shiftReg.stages.rswizzle();

    // SCLK runs off clk when isRunning is true or start is pulsed high.
    intf.sclk <= ~clk & (isRunning | start);

    // CS is active low. It will go low when isRunning or start is pulsed high.
    intf.csb <= ~(isRunning | start);

    // MOSI is connected shift register dataOut.
    intf.mosi <=
        flop(~intf.sclk, shiftReg.dataOut,
            reset: reset, asyncReset: true, resetValue: busIn[-1]);
  }
}
