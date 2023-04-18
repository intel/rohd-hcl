// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sort_bitonic.dart
// Implementation of bitonic parallel sorting network.
//
// 2023 February 17
// Author: Max Korbel <max.korbel@intel.com>
//

// ignore_for_file: avoid_unused_constructor_parameters, public_member_api_docs

// https://github.com/john9636/SortingNetwork/blob/master/SortingNetwork/verilog/recursive/rtl/bitonic_sorting_recursion.v

import 'dart:async';

import 'dart:math';
import 'package:rohd/rohd.dart';

class InputTwo extends Module {
  final dataWidth = 8;
  final labelWidth = 1;

  Logic get y0 => output('y0');
  Logic get y1 => output('y1');
  Logic get yLabel0 => output('yLabel0');
  Logic get yLabel1 => output('yLabel1');
  Logic get yValid => output('yValid');
  InputTwo(Logic clk, Logic reset, Logic xValid, Logic x0, Logic x1,
      Logic xLabel0, Logic xLabel1, int asc)
      : super(name: 'InputTwo') {
    clk = addInput('clk', clk);
    reset = addInput(reset.name, reset);
    xValid = addInput(xValid.name, xValid);
    x0 = addInput(x0.name, x0, width: x0.width);
    x1 = addInput(x1.name, x1, width: x1.width);
    xLabel0 = addInput(xLabel0.name, xLabel0, width: xLabel0.width);
    xLabel1 = addInput(xLabel1.name, xLabel1, width: xLabel1.width);

    final y0 = addOutput('y0', width: x0.width);
    final y1 = addOutput('y1', width: x1.width);
    final yLabel0 = addOutput('yLabel0', width: xLabel0.width);
    final yLabel1 = addOutput('yLabel1', width: xLabel1.width);
    final yValid = addOutput('yValid');

    // Ascending parameter
    final ascending = Const(asc);

    Sequential(clk, [
      IfBlock([
        Iff(reset, [
          y0 < 0,
          y1 < 0,
          yValid < 0,
        ]),
        Else([
          yValid < xValid,
          IfBlock([
            Iff(ascending, [
              If(x0.lt(x1), then: [
                y0 < x0,
                yLabel0 < xLabel0,
                y1 < x1,
                yLabel1 < xLabel1,
              ], orElse: [
                y0 < x1,
                yLabel0 < xLabel1,
                y1 < x0,
                yLabel1 < yLabel0,
              ]),
            ]),
            ElseIf(~ascending, [
              If(x0 > x1, then: [
                y0 < x0,
                yLabel0 < xLabel0,
                y1 < x1,
                yLabel1 < xLabel1,
              ], orElse: [
                y0 < x1,
                yLabel0 < xLabel1,
                y1 < x0,
                yLabel1 < yLabel0
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
  final labelWidth = 4;

  Logic get y => output('y');
  Logic get yLabel => output('yLabel');
  Logic get yValid => output('yValid');

  BitonicMerge(Logic clk, Logic rst, Logic xValid, Logic x, Logic xLabel,
      int logInputNum)
      : super(name: 'bitonic_merge') {
    clk = addInput('clk', clk);
    rst = addInput('rst', rst);
    xValid = addInput('x_valid', xValid);

    x = addInput('x', x, width: x.width);
    xLabel = addInput('x_label', xLabel, width: xLabel.width);
    var y = addOutput('y', width: x.width);
    var yLabel = addOutput('yLabel', width: xLabel.width);
    var yValid = addOutput('yValid');

    if (logInputNum > 1) {
      // local variable
      var stage0rslt = Logic(name: 'stage0_rslt', width: x.width);
      var stage0labl = Logic(name: 'stage0_labl', width: xLabel.width);
      var stage0valid = Logic(name: 'stage0_valid');

      for (var i = 0; i < pow(2, logInputNum - 1).toInt(); i++) {
        final inputTwoStage0 = InputTwo(
          clk,
          rst,
          xValid,
          x.slice(dataWidth * (i + 1) - 1, dataWidth * i), // x0

          x.slice(dataWidth * (i + 1 + pow(2, logInputNum - 1).toInt()) - 1,
              dataWidth * (i + pow(2, logInputNum - 1).toInt())), // x1

          xLabel.slice(labelWidth * (i + 1) - 1, labelWidth * i),
          xLabel.slice(
              labelWidth * (i + 1 + pow(2, logInputNum - 1).toInt()) - 1,
              labelWidth * (i + pow(2, logInputNum - 1).toInt())),
          1, // ascending
        );

        // stage0rslt.slice(dataWidth * (i + 1) - 1, dataWidth * i) <= inputTwoStage0.y0;
        // stage0rslt.slice(
        //         dataWidth * (i + 1 + pow(2, logInputNum - 1).toInt()) - 1,
        //         dataWidth * (i + pow(2, logInputNum - 1).toInt())) <=
        //     inputTwoStage0.y1;
        // stage0labl.slice(labelWidth * (i + 1) - 1, labelWidth * i) <=
        //     inputTwoStage0.yLabel0;
        // stage0labl.slice(
        //         labelWidth * (i + 1 + pow(2, logInputNum - 1).toInt()) - 1,
        //         labelWidth * (i + pow(2, logInputNum - 1).toInt())) <=
        //     inputTwoStage0.yLabel1;

        stage0rslt = stage0rslt.withSet(dataWidth * i, inputTwoStage0.y0);
        stage0rslt = stage0rslt.withSet(
            dataWidth * (i + pow(2, logInputNum - 1).toInt()),
            inputTwoStage0.y1);
        stage0labl = stage0labl.withSet(labelWidth * i, inputTwoStage0.yLabel0);
        stage0labl = stage0labl.withSet(
            labelWidth * (i + pow(2, logInputNum - 1).toInt()),
            inputTwoStage0.yLabel1);
      }

      final instStage10 = BitonicMerge(
        clk,
        rst,
        stage0valid,
        stage0rslt.slice(dataWidth * (pow(2, logInputNum - 1).toInt()) - 1, 0),
        stage0labl.slice(labelWidth * (pow(2, logInputNum - 1).toInt()) - 1, 0),
        logInputNum,
      );
      // y.slice(dataWidth * pow(2, logInputNum - 1).toInt() - 1, 0) <=
      //     instStage10.y;
      // yLabel.slice(labelWidth * (pow(2, logInputNum - 1).toInt()) - 1, 0) <=
      //     instStage10.yLabel;
      y = y.withSet(0, instStage10.y);
      yLabel = yLabel.withSet(0, instStage10.yLabel);

      // TODO: Missing yValid

      final instStage11 = BitonicMerge(
          clk,
          rst,
          stage0valid,
          stage0rslt.slice(dataWidth * pow(2, logInputNum).toInt() - 1,
              dataWidth * (pow(2, logInputNum - 1).toInt())),
          stage0labl.slice(labelWidth * pow(2, logInputNum).toInt() - 1,
              labelWidth * (pow(2, logInputNum - 1).toInt())),
          logInputNum);

      // y.slice(dataWidth * pow(2, logInputNum).toInt() - 1,
      //         dataWidth * (pow(2, logInputNum - 1).toInt())) <=
      //     instStage11.y;
      // yLabel.slice(labelWidth * pow(2, logInputNum).toInt() - 1,
      //         labelWidth * (pow(2, logInputNum - 1).toInt())) <=
      //     instStage11.yLabel;
      y = y.withSet(
          dataWidth * (pow(2, logInputNum - 1).toInt()), instStage11.y);
      yLabel = yLabel.withSet(
          labelWidth * (pow(2, logInputNum - 1).toInt()), instStage11.yLabel);

      // TODO: Missing yValid
    } else if (logInputNum == 1) {
      final input2Stage01 = InputTwo(
        clk,
        rst,
        xValid,
        x.slice(dataWidth - 1, 0),
        x.slice(dataWidth * 2 - 1, dataWidth),
        xLabel.slice(labelWidth - 1, 0),
        xLabel.slice(labelWidth * 2 - 1, labelWidth),
        1, // ascending
      );

      // y.slice(dataWidth - 1, 0) <= input2Stage01.y0;
      // y.slice(dataWidth * 2 - 1, dataWidth) <= input2Stage01.y1;
      // yLabel.slice(labelWidth - 1, 0) <= input2Stage01.yLabel0;
      // yLabel.slice(labelWidth * 2 - 1, labelWidth) <= input2Stage01.yLabel1;

      y = y.withSet(0, input2Stage01.y0);
      y = y.withSet(dataWidth, input2Stage01.y1);
      yLabel = yLabel.withSet(0, input2Stage01.yLabel0);
      yLabel = yLabel.withSet(labelWidth, input2Stage01.yLabel1);

      // TODO: Missing yValid
    }
  }
}

class BitonicSort extends Module {
  final dataWidth = 8;
  final labelWidth = 4;

  var _yResult = Logic(name: 'yResultIntermediate', width: 64);

  Logic get y => output('y');
  Logic get yLabel => output('yLabel');
  Logic get yValid => output('yValid');

  BitonicSort(Logic clk, Logic rst, Logic xValid, Logic x, Logic xLabel,
      int logInputNum,
      {int ascending = 1})
      : super(name: 'bitonic_sort') {
    clk = addInput('clk', clk);
    rst = addInput('rst', rst);
    xValid = addInput('xValid', xValid);
    x = addInput('x', x, width: x.width);
    xLabel = addInput('xLabel', xLabel, width: xLabel.width);
    var y = addOutput('y', width: x.width);
    var yLabel = addOutput('yLabel', width: xLabel.width);
    var yValid = addOutput('yValid');

    // debug pin
    // var y0 = addOutput('yDebug', width: 8);

    // recursive case
    if (logInputNum > 1) {
      // local variables / Intermediate signals
      final stage0rsltLeft =
          Logic(name: 'stage0_rslt_left', width: x.width ~/ 2);
      final stage0rsltRight =
          Logic(name: 'stage0_rslt_right', width: x.width ~/ 2);
      final stage0rslt = Logic(name: 'stage0_rslt', width: x.width);
      var stage0labl = Logic(name: 'stage0_labl', width: xLabel.width ~/ 2);
      var stage0valid = Logic(name: 'stage0_valid');

      // Stage 1 - Sort to Bitonic Sequence

      // Sort on the left side
      final instStage00 = BitonicSort(
        clk,
        rst,
        xValid,
        x.slice(dataWidth * (pow(2, logInputNum - 1).toInt()) - 1, 0),
        xLabel.slice(labelWidth * (pow(2, logInputNum - 1).toInt()) - 1, 0),
        logInputNum - 1,
        ascending: 1,
      );

      stage0rsltLeft <= instStage00.y;
      stage0labl = stage0labl.withSet(0, instStage00.yLabel);
      stage0valid <= instStage00.yValid;

      // Sort on right side
      final instStage01 = BitonicSort(
          clk,
          rst,
          xValid,
          x.slice(dataWidth * pow(2, logInputNum).toInt() - 1,
              dataWidth * (pow(2, logInputNum - 1).toInt())),
          xLabel.slice(labelWidth * pow(2, logInputNum).toInt() - 1,
              labelWidth * (pow(2, logInputNum - 1).toInt())),
          logInputNum - 1,
          ascending: 0 // ascending = 0
          );

      stage0rsltRight <= instStage01.y;
      // stage0labl = stage0labl.withSet(
      //     labelWidth * pow(2, logInputNum - 1).toInt(), instStage01.yLabel);

      stage0rslt <= [stage0rsltLeft, stage0rsltRight].swizzle();
      y <= stage0rslt;

      // stage 2 - Bitonic Merge
      // TODO: Temporary comment out the Merge as I want to try sort first
      final instStage1 = BitonicMerge(
          clk, rst, stage0valid, stage0rslt, stage0labl, logInputNum);
      // y <= instStage1.y;
      // yLabel <= instStage1.yLabel;
      // yValid <= instStage1.yValid;
    } else if (logInputNum == 1) {
      // Recursive Base case
      // Perform Sorting
      final input2stage01 = InputTwo(
        clk,
        rst,
        xValid,
        x.slice(dataWidth - 1, 0),
        x.slice(dataWidth * 2 - 1, dataWidth),
        xLabel.slice(labelWidth - 1, 0),
        xLabel.slice(labelWidth * 2 - 1, labelWidth),
        ascending, //ascending (need recheck again with params)
      );

      // y = y.withSet(0, input2stage01.y0);
      // y = y.withSet(dataWidth, input2stage01.y1);
      yLabel = yLabel.withSet(0, input2stage01.yLabel0);
      yLabel = yLabel.withSet(labelWidth, input2stage01.yLabel1);

      // debug pin
      final y0 =
          Logic(name: 'y0_intermediate_sort', width: input2stage01.y0.width);
      final y1 =
          Logic(name: 'y0_intermediate_sort', width: input2stage01.y1.width);
      y0 <= input2stage01.y0;
      y1 <= input2stage01.y1;

      y <= [y0, y1].swizzle();
    }
  }
}

// Top Level Module
class Bitonic extends Module {
  final dataWidth = 8;
  Bitonic(Logic clk, Logic rst, Logic xValid, Logic x, Logic xLabel,
      int logInputNum)
      : super(name: 'Bitonic') {
    final labelWidth = logInputNum;
    clk = addInput('clk', clk);
    rst = addInput('rst', rst);
    xValid = addInput('x_valid', xValid);

    x = addInput('x', x, width: x.width);
    xLabel = addInput('x_label', xLabel, width: xLabel.width);
    final y = addOutput('y', width: x.width);
    final yLabel = addOutput('y_label', width: xLabel.width);
    final yValid = addOutput('y_valid');

    // Bitonic Sorting Instance
    final bitonicSortingInst =
        BitonicSort(clk, rst, xValid, x, xLabel, logInputNum);

    y <= bitonicSortingInst.y;
    yLabel <= bitonicSortingInst.yLabel;
    yValid <= bitonicSortingInst.yValid;
  }
}

Future<void> main() async {
  const dataWidth = 8;
  const labelWidth = 4;
  const logInputNum = 3;

  final clk = SimpleClockGenerator(10).clk;
  final reset = Logic(name: 'reset');
  final xValid = Logic(name: 'xValid');

  final x = Logic(name: 'x', width: dataWidth * pow(2, logInputNum).toInt());
  final xLabel =
      Logic(name: 'xLabel', width: labelWidth * pow(2, logInputNum).toInt());

  final topMod = Bitonic(clk, reset, xValid, x, xLabel, logInputNum);
  await topMod.build();

  // print(topMod.generateSynth());

  reset.inject(1);
  xValid.inject(1);

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
