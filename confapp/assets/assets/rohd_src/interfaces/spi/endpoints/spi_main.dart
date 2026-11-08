// Copyright (C) 2024-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_main.dart
// Implementation of SPI Main component.
//
// 2024 October 1
// Author: Roberto Torres <roberto.torres@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/spi/endpoints/spi_shift_register.dart';

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
  /// [busOut]. [reset] clears the receive state and prepares a transmit load.
  /// Hold [busIn] stable through the first falling SPI clock edge after reset;
  /// its most significant bit is driven before the first rising edge and the
  /// rest is loaded on that rising edge.
  /// Pulsing [start] begins the transfer. [done] goes high when it completes.
  SpiMain(SpiInterface intf,
      {required Logic clk,
      required Logic reset,
      required Logic start,
      required Logic busIn,
      super.name = 'spiMain',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'SpiMain_W${busIn.width}_'
                    '${intf.dataLength}_'
                    '${intf.sclk.width}') {
    busIn = addInput('busIn', busIn, width: busIn.width);

    clk = addInput('clk', clk);

    reset = addInput('reset', reset);

    start = addInput('start', start);

    addOutput('busOut', width: busIn.width);

    addOutput('done');

    intf = addPairInterfacePorts(intf, PairRole.provider);

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

    final shiftReg = buildSpiShiftRegister(
      serialIn: intf.miso,
      clock: intf.sclk,
      width: intf.dataLength,
      reset: reset,
      parallelIn: busIn,
    );

    busOut <= shiftReg.parallelOut;

    // SCLK runs off clk when isRunning is true or start is pulsed high.
    intf.sclk <= ~clk & (isRunning | start);

    // CS is active low. It will go low when isRunning or start is pulsed high.
    intf.csb <= ~(isRunning | start);

    intf.mosi <= shiftReg.serialOut;
  }
}
