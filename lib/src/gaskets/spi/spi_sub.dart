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

  /// Done signal from Sub.
  Logic? get done => tryOutput('done');

  /// Creates a SPI Sub component that interfaces with [SpiInterface].
  ///
  /// The SPI Sub component will enable via chip select from [SpiInterface.csb].
  /// Clock signal will be received on [SpiInterface.sclk], data will shift in
  /// from [SpiInterface.mosi], and shift data out from [SpiInterface.miso].
  /// Data shifted in from [SpiInterface.mosi] will be available on [busOut].
  ///
  /// If [busIn] and [reset] are provided, data to shift out will be loaded from
  /// [busIn]. After data is available on [busIn], pulsing [reset] will load the
  /// data asynchronously, and a bit of data will be transmitted per pulse of
  /// [SpiInterface.sclk]. After all data is shifted out, an optional [done]
  /// signal will indicate completion.
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
    intf = intf.clone()..pairConnectIO(this, intf, PairRole.consumer);

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
