// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// apb_completer.dart
// Base implementation for APB completer HW and associated variants.
//
// 2025 December
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// APB Completer that is meant to be used against CSRs
/// as defined in ROHD-HCL.
class ApbCsrCompleter extends ApbCompleter {
  /// How many APB clock cycles before we should indicate
  /// data is complete.
  late final int responseLatency;

  /// CSR frontdoor reads.
  late final DataPortInterface rd;

  /// CSR frontdoor writes.
  late final DataPortInterface wr;

  /// Constructor.
  ApbCsrCompleter(
      {required super.apb,
      required DataPortInterface csrRd,
      required DataPortInterface csrWr,
      this.responseLatency = 0,
      super.name}) {
    rd = csrRd.clone()
      ..connectIO(
        this,
        csrRd,
        inputTags: {DataPortGroup.data},
        outputTags: {DataPortGroup.control},
        uniquify: (original) => '${name}_rd_$original',
      );
    wr = csrWr.clone()
      ..connectIO(
        this,
        csrWr,
        inputTags: {},
        outputTags: {DataPortGroup.control, DataPortGroup.data},
        uniquify: (original) => '${name}_wr_$original',
      );

    _buildCustomLogic();
  }

  /// Calculates a strobed version of data.
  Logic _strobeData(Logic originalData, Logic newData, Logic strobe) =>
      List.generate(
          strobe.width,
          (i) => mux(strobe[i], newData.getRange(i * 8, (i + 1) * 8),
              originalData.getRange(i * 8, (i + 1) * 8))).rswizzle();

  void _buildCustomLogic() {
    // we drop the following APB inputs on the floor
    // apb.aUser;
    // apb.nse;
    // apb.prot;
    // apb.wUser;

    // drive downstream
    // reads must happen unconditionally for strobing
    rd.en <= downstreamValid;
    rd.addr <= apb.addr;

    wr.en <= downstreamValid & apb.write;
    wr.addr <= apb.addr;
    wr.data <= _strobeData(rd.data, apb.wData, apb.strb);

    // drive APB output
    apb.rData <= rd.data;

    // NOP outputs
    apb.slvErr?.gets(Const(0, width: apb.slvErr?.width));
    apb.bUser?.gets(Const(0, width: apb.bUser?.width));
    apb.rUser?.gets(Const(0, width: apb.rUser?.width));

    // zero latency operation
    if (responseLatency == 0) {
      upstreamValid <= rd.en | wr.en;
    }
    // non-zero latency operation
    else {
      upstreamValid <=
          ShiftRegister(rd.en | wr.en, clk: apb.clk, depth: responseLatency)
              .dataOut;
    }
  }
}
