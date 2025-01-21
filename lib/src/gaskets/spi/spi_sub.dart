// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_sub.dart
// Implementation of SPI Sub component.
//
// 2024 October 4
// Author: Roberto Torres <roberto.torres@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Sub component for Serial Peripheral Interface (SPI).
class SpiSub extends Module {
  /// Output bus from Sub.
  Logic get busOut => output('busOut');

  /// Creates a SPI Sub component that interfaces with [SpiInterface].
  ///
  /// The SPI Sub component will enable via chip select from [SpiInterface.csb].
  /// Clock signal will be received on [SpiInterface.sclk], data will shift in
  /// from [SpiInterface.mosi], and shift data out from [SpiInterface.miso].
  /// Data to shift out is provided from [busIn]. Data shifted in from
  /// [SpiInterface.mosi] will be available on [busOut]. After data is available
  /// on [busIn], pulsing [reset] will load the data, and a bit of data will be
  /// transmitted per clock pulse.
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
    if (reset != null) {
      reset = addInput('reset', reset);
    }

    // Bus Output from Sub
    addOutput('busOut', width: intf.dataLength);

    // Shift Register in from MOSI.
    // NOTE: Reset values are set to busIn values.
    final shiftReg = ShiftRegister(
      intf.mosi,
      enable: ~intf.csb,
      clk: intf.sclk,
      depth: intf.dataLength,
      reset: reset,
      asyncReset: true,
      resetValue: busIn?.elements,
    );

    // busOut bits are connected to the corresponding shift register data stage.
    // NOTE: dataStage0 corresponds to the last bit shifted in.
    busOut <= shiftReg.stages.rswizzle();

    // MISO is connected to shift register dataOut.
    intf.miso <=
        flop(~intf.sclk, shiftReg.dataOut,
            en: ~intf.csb,
            reset: reset,
            asyncReset: true,
            resetValue: busIn?[-1]);
  }
}
