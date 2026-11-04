// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_shift_register.dart
// Shared SPI transmit and receive shift logic.
//
// 2026 November 4
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Builds the shared SPI transmit and receive shift logic.
({Logic serialOut, Logic parallelOut}) buildSpiShiftRegister({
  required Logic clock,
  required Logic serialIn,
  required int width,
  Logic? enable,
  Logic? reset,
  Logic? parallelIn,
}) {
  final data = Logic(name: 'spiShiftData', width: width);
  final Logic loadPending;
  final Logic outputPending;
  if (reset != null && parallelIn != null) {
    loadPending = Logic(name: 'spiLoadPending');
    outputPending = Logic(name: 'spiOutputPending');
    Sequential(
        clock,
        [
          If(enable ?? Const(1), then: [loadPending < 0]),
        ],
        reset: reset,
        asyncReset: true,
        resetValues: {loadPending: 1});
    Sequential(
        ~clock,
        [
          If((enable ?? Const(1)) & ~loadPending, then: [outputPending < 0]),
        ],
        reset: reset,
        asyncReset: true,
        resetValues: {outputPending: 1});
  } else {
    loadPending = Const(0);
    outputPending = Const(0);
  }

  final shiftSource =
      parallelIn != null ? mux(loadPending, parallelIn, data) : data;
  Sequential(
      clock,
      [
        If(enable ?? Const(1), then: [
          data < ((shiftSource << 1) | serialIn.zeroExtend(width)),
        ]),
      ],
      reset: reset,
      asyncReset: true);

  final registeredOut =
      flop(~clock, data[-1], en: enable, reset: reset, asyncReset: true);
  final serialOut = parallelIn != null
      ? mux(outputPending, parallelIn[-1], registeredOut)
      : registeredOut;
  return (serialOut: serialOut, parallelOut: data);
}
