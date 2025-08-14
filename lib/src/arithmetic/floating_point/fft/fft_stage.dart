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
  Logic go;
  DataPortInterface inputSamplesA;
  DataPortInterface inputSamplesB;
  DataPortInterface twiddleFactorROM;

  late final Logic done;

  BadFFTStage({
    required this.logStage,
    required this.exponentWidth,
    required this.mantissaWidth,
    required this.clk,
    required this.reset,
    required this.go,
    required this.inputSamplesA,
    required this.inputSamplesB,
    required this.twiddleFactorROM,
    required DataPortInterface outputSamplesA,
    required DataPortInterface outputSamplesB,
    super.name = 'badfftstage',
  })  : assert(go.width == 1),
        assert(
          inputSamplesA.dataWidth == 2 * (1 + exponentWidth + mantissaWidth),
        ),
        assert(
          inputSamplesB.dataWidth == 2 * (1 + exponentWidth + mantissaWidth),
        ) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    go = addInput('go', go);
    final _done = Logic(name: "_done");
    done = addOutput('done')..gets(_done);
    final en = (go & ~_done).named("enable");

    inputSamplesA = connectInterface(
      inputSamplesA,
      inputTags: [DataPortGroup.data],
      outputTags: [DataPortGroup.control],
      uniquify: (name) => "inputSamplesA${name}",
    );
    inputSamplesB = connectInterface(
      inputSamplesB,
      inputTags: [DataPortGroup.data],
      outputTags: [DataPortGroup.control],
      uniquify: (name) => "inputSamplesB${name}",
    );
    twiddleFactorROM = connectInterface(
      twiddleFactorROM,
      inputTags: [DataPortGroup.data],
      outputTags: [DataPortGroup.control],
      uniquify: (name) => "twiddleFactorROM${name}",
    );

    outputSamplesA = connectInterface(
      outputSamplesA,
      inputTags: [DataPortGroup.control],
      outputTags: [DataPortGroup.data],
      uniquify: (name) => "outputSamplesA${name}",
    );
    outputSamplesB = connectInterface(
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
      name: 'outputSamplesBuffer',
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
      [flop(clk, en)],
      clk: clk,
      reset: reset | (this.go & _done),
      resetValue: 0,
      width: max(log2Length - 1, 1),
      maxValue: n ~/ 2,
      name: "i",
    );
    _done <= i.equalsMax;

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
    Logic addressB = (addressA + m ~/ 2).named("addressB");
    inputSamplesA.addr <= addressA;
    inputSamplesA.en <= en;
    inputSamplesB.addr <= addressB;
    inputSamplesB.en <= en;
    twiddleFactorROM.addr <= j;
    twiddleFactorROM.en <= en;

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
    outputSamplesWritePortA.en <= en;
    outputSamplesWritePortB.addr <= addressB;
    outputSamplesWritePortB.en <= en;

    Sequential(
        clk,
        [
          outputSamplesWritePortA.data < butterfly.outA.named("butterflyOutA"),
          outputSamplesWritePortB.data < butterfly.outB.named("butterflyOutB"),
        ],
        reset: reset);
  }
}
