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
    required DataPortInterface outputSamplesA,
    required DataPortInterface outputSamplesB,
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
    final _valid = Logic(name: "_valid");
    valid = addOutput('valid')..gets(_valid);

    inputSamplesA = inputSamplesA.clone()
      ..connectIO(
        this,
        inputSamplesA,
        inputTags: [DataPortGroup.data],
        outputTags: [DataPortGroup.control],
        uniquify: (name) => "inputSamplesA${name}",
      );
    inputSamplesB = inputSamplesB.clone()
      ..connectIO(
        this,
        inputSamplesB,
        inputTags: [DataPortGroup.data],
        outputTags: [DataPortGroup.control],
        uniquify: (name) => "inputSamplesB${name}",
      );
    twiddleFactorROM = twiddleFactorROM.clone()
      ..connectIO(
        this,
        twiddleFactorROM,
        inputTags: [DataPortGroup.data],
        outputTags: [DataPortGroup.control],
        uniquify: (name) => "twiddleFactorROM${name}",
      );

    outputSamplesA = outputSamplesA.clone()
      ..connectIO(
        this,
        outputSamplesA,
        inputTags: [DataPortGroup.control],
        outputTags: [DataPortGroup.data],
        uniquify: (name) => "outputSamplesA${name}",
      );
    outputSamplesB = outputSamplesB.clone()
      ..connectIO(
        this,
        outputSamplesB,
        inputTags: [DataPortGroup.control],
        outputTags: [DataPortGroup.data],
        uniquify: (name) => "outputSamplesB${name}",
      );

    final outputSamplesWritePortA = DataPortInterface(
      inputSamplesA.dataWidth,
      inputSamplesA.addrWidth,
    );
    final outputSamplesWritePortB = DataPortInterface(
      inputSamplesA.dataWidth,
      inputSamplesA.addrWidth,
    );
    final outputSamplesReadPortA = DataPortInterface(
      inputSamplesA.dataWidth,
      inputSamplesA.addrWidth,
    );
    final outputSamplesReadPortB = DataPortInterface(
      inputSamplesA.dataWidth,
      inputSamplesA.addrWidth,
    );

    final n = 1 << inputSamplesA.addrWidth;
    RegisterFile(
      clk,
      reset,
      [outputSamplesWritePortA, outputSamplesWritePortB],
      [outputSamplesReadPortA, outputSamplesReadPortB],
      numEntries: n,
    );
    outputSamplesA.data <= outputSamplesReadPortA.data;
    outputSamplesReadPortA.en <= outputSamplesA.en;
    outputSamplesReadPortA.addr <= outputSamplesA.addr;
    outputSamplesB.data <= outputSamplesReadPortB.data;
    outputSamplesReadPortB.en <= outputSamplesB.en;
    outputSamplesReadPortB.addr <= outputSamplesB.addr;

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
      name: "i",
    );
    _valid <= i.equalsMax;

    final k = ((i.count >> (mShift - 1)) << mShift).named("k");
    final j = (i.count & Const((m >> 1) - 1, width: i.width)).named("j");

    //     for k = 0 to n-1 by m do
    //         ω ← 1
    //         for j = 0 to m/2 – 1 do
    //             t ← ω A[k + j + m/2]
    //             u ← A[k + j]
    //             A[k + j] ← u + t
    //             A[k + j + m/2] ← u – t
    //             ω ← ω ωm
    Logic addressA = (k + j).named("addressA");
    Logic addressB = (addressA + n ~/ 2).named("addressB");
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
      outputSamplesWritePortA.data < butterfly.outA.named("butterflyOutA"),
      outputSamplesWritePortB.data < butterfly.outB.named("butterflyOutB"),
    ], reset: reset);
  }
}
