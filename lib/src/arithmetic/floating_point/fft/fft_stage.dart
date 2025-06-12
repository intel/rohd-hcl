// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/arithmetic/floating_point/fft/butterfly.dart';
import 'package:rohd_hcl/src/arithmetic/signals/floating_point_logics/complex_floating_point_logic.dart';

class BadFFTStage extends Module {
  final int logStage;
  final int exponentWidth;
  final int mantissaWidth;
  final Logic clk;
  final Logic reset;
  final Logic ready;
  final DataPortInterface inputSamplesA;
  final DataPortInterface inputSamplesB;
  final DataPortInterface twiddleFactorROM;

  Logic get valid => output("valid");
  late final DataPortInterface outputSamples;

  BadFFTStage(
      {required this.logStage,
      required this.exponentWidth,
      required this.mantissaWidth,
      required this.clk,
      required this.reset,
      required this.ready,
      required this.inputSamplesA,
      required this.inputSamplesB,
      required this.twiddleFactorROM,
      super.name = 'badfftstage'})
      : assert(ready.width == 1) {
    addInput('clk', clk);
    addInput('reset', reset);
    addInput('ready', ready);

    outputSamples =
        DataPortInterface(inputSamplesA.dataWidth, inputSamplesA.addrWidth);
    final outputSamplesWritePortA =
        DataPortInterface(inputSamplesA.dataWidth, inputSamplesA.addrWidth);
    final outputSamplesWritePortB =
        DataPortInterface(inputSamplesA.dataWidth, inputSamplesA.addrWidth);
    MemoryModel(clk, reset, [outputSamplesWritePortA, outputSamplesWritePortB],
        [outputSamples],
        readLatency: 0);

    // outputSamplesWritePort.connectIO(this, srcInterface)

    final n = 1 << inputSamplesA.addrWidth;
    final log2Length = inputSamplesA.addrWidth;
    final m = 1 << logStage;
    final mShift = log2Ceil(m);

    final i = Counter.ofLogics([~this.valid],
        clk: clk,
        reset: reset,
        restart: this.ready & this.valid,
        width: log2Length - 1,
        maxValue: n / 2);
    valid <= i.equalsMax;

    final k = (i.count >> (mShift - 1)) << mShift;
    final j = (i.count & Const((m >> 1) - 1, width: i.width));

    //     for k = 0 to n-1 by m do
    //         ω ← 1
    //         for j = 0 to m/2 – 1 do
    //             t ← ω A[k + j + m/2]
    //             u ← A[k + j]
    //             A[k + j] ← u + t
    //             A[k + j + m/2] ← u – t
    //             ω ← ω ωm
    Logic addressA = k + j;
    Logic addressB = addressA + n / 2;
    inputSamplesA.addr <= addressA;
    inputSamplesA.en <= ~this.valid;
    inputSamplesB.addr <= addressB;
    inputSamplesB.en <= ~this.valid;
    twiddleFactorROM.addr <= j;
    twiddleFactorROM.en <= ~this.valid;

    final butterfly = Butterfly(
        inA: ComplexFloatingPoint.of(inputSamplesA.data,
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth),
        inB: ComplexFloatingPoint.of(inputSamplesB.data,
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth),
        twiddleFactor: ComplexFloatingPoint.of(twiddleFactorROM.data,
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth));

    outputSamplesWritePortA.addr <= addressA;
    outputSamplesWritePortA.en <= ~this.valid;
    outputSamplesWritePortB.addr <= addressB;
    outputSamplesWritePortB.en <= ~this.valid;

    Sequential(
        clk,
        [
          outputSamplesWritePortA.data < butterfly.outA,
          outputSamplesWritePortB.data < butterfly.outB
        ],
        reset: reset);
  }
}
