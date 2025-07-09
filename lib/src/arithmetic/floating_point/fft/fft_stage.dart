// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/arithmetic/floating_point/fft/butterfly.dart';
import 'package:rohd_hcl/src/arithmetic/signals/floating_point_logics/complex_floating_point_logic.dart';

class BadFFTStage extends Module {
  final int logStage;
  final int exponentWidth;
  final int mantissaWidth;
  Logic clk;
  Logic reset;
  Logic ready;
  DataPortInterface inputSamplesA;
  DataPortInterface inputSamplesB;
  DataPortInterface twiddleFactorROM;

  late final Logic valid;
  late final DataPortInterface outputSamples;

  BadFFTStage({
    required this.logStage,
    required this.exponentWidth,
    required this.mantissaWidth,
    required this.clk,
    required this.reset,
    required this.ready,
    required this.inputSamplesA,
    required this.inputSamplesB,
    required this.twiddleFactorROM,
    super.name = 'badfftstage',
  }) : assert(ready.width == 1),
       assert(
         inputSamplesA.dataWidth == 2 * (1 + exponentWidth + mantissaWidth),
       ),
       assert(
         inputSamplesB.dataWidth == 2 * (1 + exponentWidth + mantissaWidth),
       ) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    ready = addInput('ready', ready);
    final _valid = Logic();
    valid = addOutput('valid')..gets(_valid);

    inputSamplesA = inputSamplesA.clone()
      ..connectIO(
        this,
        inputSamplesA,
        inputTags: [DataPortGroup.data, DataPortGroup.control],
        uniquify: (name) => "inputSamplesA${name}",
      );
    inputSamplesB = inputSamplesB.clone()
      ..connectIO(
        this,
        inputSamplesB,
        inputTags: [DataPortGroup.data, DataPortGroup.control],
        uniquify: (name) => "inputSamplesB${name}",
      );
    twiddleFactorROM = twiddleFactorROM.clone()
      ..connectIO(
        this,
        twiddleFactorROM,
        inputTags: [DataPortGroup.data, DataPortGroup.control],
        uniquify: (name) => "twiddleFactorROM${name}",
      );

    outputSamples = DataPortInterface(
      inputSamplesA.dataWidth,
      inputSamplesA.addrWidth,
    ).clone();
    outputSamples.connectIO(
      this,
      outputSamples,
      outputTags: [DataPortGroup.data, DataPortGroup.control],
      uniquify: (name) => "outputSamples${name}",
    );

    final outputSamplesWritePortATemp = DataPortInterface(
      inputSamplesA.dataWidth,
      inputSamplesA.addrWidth,
    );
    final outputSamplesWritePortBTemp = DataPortInterface(
      inputSamplesA.dataWidth,
      inputSamplesA.addrWidth,
    );

    final outputSamplesWritePortA = outputSamplesWritePortATemp.clone();
    outputSamplesWritePortA.connectIO(
      this,
      outputSamplesWritePortATemp,
      inputTags: [DataPortGroup.data, DataPortGroup.control],
      uniquify: (name) => "outputSamplesWritePortA${name}",
    );
    final outputSamplesWritePortB = outputSamplesWritePortBTemp.clone();
    outputSamplesWritePortB.connectIO(
      this,
      outputSamplesWritePortBTemp,
      inputTags: [DataPortGroup.data, DataPortGroup.control],
      uniquify: (name) => "outputSamplesWritePortB${name}",
    );

    MemoryModel(
      clk,
      reset,
      [outputSamplesWritePortA, outputSamplesWritePortB],
      [outputSamples],
      readLatency: 0,
    );
    final n = 1 << inputSamplesA.addrWidth;
    final log2Length = inputSamplesA.addrWidth;
    final m = 1 << logStage;
    final mShift = log2Ceil(m);

    final i = Counter.ofLogics(
      [~_valid],
      clk: clk,
      reset: reset,
      restart: this.ready & _valid,
      width: max(log2Length - 1, 1),
      maxValue: n ~/ 2 - 1,
    );
    _valid <= i.equalsMax;

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
    Logic addressB = addressA + n ~/ 2;
    inputSamplesA.addr <= addressA;
    inputSamplesA.en <= ~_valid;
    inputSamplesB.addr <= addressB;
    inputSamplesB.en <= ~_valid;
    twiddleFactorROM.addr <= j;
    twiddleFactorROM.en <= ~_valid;

    final butterfly = Butterfly(
      inA: ComplexFloatingPoint.of(
        inputSamplesA.data,
        exponentWidth: exponentWidth,
        mantissaWidth: mantissaWidth,
      ),
      inB: ComplexFloatingPoint.of(
        inputSamplesB.data,
        exponentWidth: exponentWidth,
        mantissaWidth: mantissaWidth,
      ),
      twiddleFactor: ComplexFloatingPoint.of(
        twiddleFactorROM.data,
        exponentWidth: exponentWidth,
        mantissaWidth: mantissaWidth,
      ),
    );

    outputSamplesWritePortA.addr <= addressA;
    outputSamplesWritePortA.en <= ~_valid;
    outputSamplesWritePortB.addr <= addressB;
    outputSamplesWritePortB.en <= ~_valid;

    Sequential(clk, [
      outputSamplesWritePortA.data < butterfly.outA,
      outputSamplesWritePortB.data < butterfly.outB,
    ], reset: reset);
  }
}
