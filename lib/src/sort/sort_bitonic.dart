// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sort_bitonic.dart
// Implementation of bitonic parallel sorting network.
//
// 2023 April 18
// Author: Yao Jing Quek <yao.jing.quek@intel.com>
//

// ignore_for_file: avoid_unused_constructor_parameters, public_member_api_docs

// https://github.com/john9636/SortingNetwork/blob/master/SortingNetwork/verilog/recursive/rtl/bitonic_sorting_recursion.v

import 'dart:async';

import 'dart:math';
import 'package:rohd/rohd.dart';

class InputTwo extends Module {
  final dataWidth = 8;

  Logic get y0 => output('y0');
  Logic get y1 => output('y1');

  InputTwo(Logic clk, Logic reset, Logic x0, Logic x1, int asc)
      : super(name: 'InputTwo') {
    clk = addInput('clk', clk);
    reset = addInput(reset.name, reset);
    x0 = addInput(x0.name, x0, width: x0.width);
    x1 = addInput(x1.name, x1, width: x1.width);

    final y0 = addOutput('y0', width: x0.width);
    final y1 = addOutput('y1', width: x1.width);

    // Ascending parameter
    final ascending = Const(asc);

    Sequential(clk, [
      IfBlock([
        Iff(reset, [
          y0 < 0,
          y1 < 0,
        ]),
        Else([
          IfBlock([
            Iff(ascending, [
              If(x0.lt(x1), then: [
                y0 < x0,
                y1 < x1,
              ], orElse: [
                y0 < x1,
                y1 < x0,
              ]),
            ]),
            ElseIf(~ascending, [
              If(x0.lt(x1), then: [
                y0 < x1,
                y1 < x0,
              ], orElse: [
                y0 < x0,
                y1 < x1,
              ])
            ])
          ])
        ])
      ])
    ]);
  }
}

class BitonicMerge extends Module {
  final dataWidth = 8;

  Logic get y => output('y');

  BitonicMerge(Logic clk, Logic rst, Logic x, int logInputNum, int ascending)
      : super(name: 'bitonic_merge') {
    clk = addInput('clk', clk);
    rst = addInput('rst', rst);

    x = addInput('x', x, width: x.width);
    var y = addOutput('y', width: x.width);

    var stage0rslt = Logic(name: 'stage0_rslt', width: x.width);
    var stage0rsltLeft = Logic(name: 'stage0_rslt_left', width: x.width ~/ 2);
    var stage0rsltRight = Logic(name: 'stage0_rslt_right', width: x.width ~/ 2);

    if (logInputNum > 1) {
      for (var i = 0; i < pow(2, logInputNum - 1).toInt(); i++) {
        final inputTwoStage0 = InputTwo(
          clk,
          rst,
          x.slice(dataWidth * (i + 1) - 1, dataWidth * i), // x0

          x.slice(dataWidth * (i + 1 + pow(2, logInputNum - 1).toInt()) - 1,
              dataWidth * (i + pow(2, logInputNum - 1).toInt())), // x1
          ascending, // ascending
        );

        stage0rslt = stage0rslt.withSet(dataWidth * i, inputTwoStage0.y0);
        stage0rslt = stage0rslt.withSet(
            dataWidth * (i + pow(2, logInputNum - 1).toInt()),
            inputTwoStage0.y1);
      }

      final instStage10 = BitonicMerge(
          clk,
          rst,
          stage0rslt.slice(
              dataWidth * (pow(2, logInputNum - 1).toInt()) - 1, 0),
          logInputNum - 1,
          ascending);

      // left merge
      // y = y.withSet(0, instStage10.y);
      stage0rsltLeft <= instStage10.y;

      final instStage11 = BitonicMerge(
          clk,
          rst,
          stage0rslt.slice(dataWidth * pow(2, logInputNum).toInt() - 1,
              dataWidth * (pow(2, logInputNum - 1).toInt())),
          logInputNum - 1,
          ascending);

      // right merge
      // y = y.withSet(
      //     dataWidth * (pow(2, logInputNum - 1).toInt()), instStage11.y);
      stage0rsltRight <= instStage11.y;

      y <= [stage0rsltRight, stage0rsltLeft].swizzle();
    } else if (logInputNum == 1) {
      final input2Stage01 = InputTwo(
        clk,
        rst,
        x.slice(dataWidth - 1, 0),
        x.slice(dataWidth * 2 - 1, dataWidth),
        ascending, // ascending
      );

      // y = y.withSet(0, input2Stage01.y0);
      // y = y.withSet(dataWidth, input2Stage01.y1);

      y <= [input2Stage01.y1, input2Stage01.y0].swizzle();
    }
  }
}

class BitonicSort extends Module {
  final dataWidth = 8;

  Logic get y => output('y');

  BitonicSort(Logic clk, Logic rst, Logic x, int logInputNum,
      {String side = 'Module', int ascending = 1})
      : super(name: 'bitonic_sort_$side') {
    clk = addInput('clk', clk);
    rst = addInput('rst', rst);
    x = addInput('x', x, width: x.width);
    final y = addOutput('y', width: x.width);

    // recursive case
    if (logInputNum > 1) {
      // local variables / Intermediate signals
      final stage0rsltLeft =
          Logic(name: 'stage0_rslt_left', width: x.width ~/ 2);
      final stage0rsltRight =
          Logic(name: 'stage0_rslt_right', width: x.width ~/ 2);
      final stage0rslt = Logic(name: 'stage0_rslt', width: x.width);

      // Stage 1 - Sort to Bitonic Sequence
      final instStage00 = BitonicSort(
          clk,
          rst,
          x.slice(dataWidth * (pow(2, logInputNum - 1).toInt()) - 1, 0),
          logInputNum - 1,
          ascending: 1,
          side: 'left_side');
      stage0rsltLeft <= instStage00.y;

      final instStage01 = BitonicSort(
          clk,
          rst,
          x.slice(dataWidth * pow(2, logInputNum).toInt() - 1,
              dataWidth * (pow(2, logInputNum - 1).toInt())),
          logInputNum - 1,
          ascending: 0, //decending
          side: 'right_side');
      stage0rsltRight <= instStage01.y;

      stage0rslt <= [stage0rsltRight, stage0rsltLeft].swizzle();

      // stage 2 - Bitonic Merge
      // TODO: Temporary comment out the Merge as I want to try sort first
      final instStage1 =
          BitonicMerge(clk, rst, stage0rslt, logInputNum, ascending);
      y <= instStage1.y;
    } else if (logInputNum == 1) {
      // Recursive Base case
      // Perform Sorting
      final input2stage01 = InputTwo(
        clk,
        rst,
        x.slice(dataWidth - 1, 0),
        x.slice(dataWidth * 2 - 1, dataWidth),
        ascending, //ascending (need recheck again with params)
      );

      // debug pin
      final y0 =
          Logic(name: 'y0_intermediate_sort', width: input2stage01.y0.width);
      final y1 =
          Logic(name: 'y0_intermediate_sort', width: input2stage01.y1.width);
      y0 <= input2stage01.y0;
      y1 <= input2stage01.y1;

      y <= [y1, y0].swizzle();
    }
  }
}

class Bitonic extends Module {
  final dataWidth = 8;
  Bitonic(Logic clk, Logic rst, Logic x, int logInputNum)
      : super(name: 'Bitonic') {
    clk = addInput('clk', clk);
    rst = addInput('rst', rst);

    x = addInput('x', x, width: x.width);
    final y = addOutput('y', width: x.width);

    // Bitonic Sorting Instance
    final bitonicSortingInst = BitonicSort(clk, rst, x, logInputNum);
    y <= bitonicSortingInst.y;
  }
}

Future<void> main() async {
  const dataWidth = 8;
  const logInputNum = 3;

  final clk = SimpleClockGenerator(10).clk;
  final reset = Logic(name: 'reset');

  final x = Logic(name: 'x', width: dataWidth * pow(2, logInputNum).toInt());

  final topMod = Bitonic(clk, reset, x, logInputNum);
  await topMod.build();

  // print(topMod.generateSynth());

  reset.inject(1);

  final xVal = [
    Const(7, width: 8),
    Const(5, width: 8),
    Const(4, width: 8),
    Const(3, width: 8),
    Const(11, width: 8),
    Const(13, width: 8),
    Const(10, width: 8),
    Const(1, width: 8)
  ].swizzle();

  Simulator.setMaxSimTime(100);
  WaveDumper(topMod, outputPath: 'recursive.vcd');

  Simulator.registerAction(25, () {
    reset.put(0);
    x.put(bin(xVal.value.toString(includeWidth: false)));
  });

  await Simulator.run();
}
