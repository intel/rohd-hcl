// Copyright (C) 2024-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_sub.dart
// Implementation of SPI Sub component.
//
// 2024 October 4
// Author: Roberto Torres <roberto.torres@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/spi/endpoints/spi_shift_register.dart';

/// Sub component for Serial Peripheral Interface (SPI).
class SpiSub extends Module {
  /// Output bus from Sub.
  Logic get busOut => output('busOut');

  /// Done signal from Sub.
  Logic? get done => tryOutput('done');

  /// Creates a SPI Sub component that interfaces with [SpiInterface].
  ///
  /// The SPI Sub component will enable via chip select from [SpiInterface.csb].
  /// Clock signal will be received on [SpiInterface.sclk], data will shift in
  /// from [SpiInterface.mosi], and shift data out from [SpiInterface.miso].
  /// Data shifted in from [SpiInterface.mosi] will be available on [busOut].
  ///
  /// If [busIn] and [reset] are provided, reset clears the receive state and
  /// prepares a transmit load. Hold [busIn] stable through the first enabled
  /// falling SPI clock edge after reset; its most significant bit is driven
  /// before the first rising edge and the rest is loaded on that rising edge.
  /// An optional [done] indicates completion.
  SpiSub(
      {required SpiInterface intf,
      Logic? busIn,
      Logic? reset,
      super.name = 'spiSub',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'SpiSub_W${busIn?.width ?? 0}_'
                    '${intf.dataLength}_'
                    '${intf.sclk.width}') {
    // SPI Interface
    intf = addPairInterfacePorts(intf, PairRole.consumer);

    // Bus Input to sub, if provided.
    if (busIn != null) {
      busIn = addInput('busIn', busIn, width: intf.dataLength);
    }

    // If reset is provided, add the reset input and done output.
    if (reset != null) {
      reset = addInput('reset', reset);

      addOutput('done');

      // Counter to track of the number of bits shifted out.
      final count = Counter.simple(
          clk: intf.sclk,
          enable: ~intf.csb,
          reset: reset,
          asyncReset: true,
          resetValue: intf.dataLength - 1,
          maxValue: intf.dataLength - 1);

      // Done signal will be high when the counter is at the max value.
      done! <= count.equalsMax;
    }

    // Bus Output from Sub
    addOutput('busOut', width: intf.dataLength);

    final shiftReg = buildSpiShiftRegister(
      serialIn: intf.mosi,
      enable: ~intf.csb,
      clock: intf.sclk,
      width: intf.dataLength,
      reset: reset,
      parallelIn: busIn,
    );

    busOut <= shiftReg.parallelOut;

    intf.miso <= shiftReg.serialOut;
  }
}
