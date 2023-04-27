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

class CompareSwap extends Module {
  final List<Logic> _inputs = [];
  final List<Logic> _outputs = [];

  List<Logic> get yList => _outputs;

  CompareSwap(
      Logic clk, Logic reset, List<Logic> a, int i, int j, int direction)
      : super(name: 'compare_swap_${i}_$j') {
    clk = addInput('clk', clk);
    reset = addInput(reset.name, reset);

    for (var i = 0; i < a.length; i++) {
      _inputs.add(addInput('x$i', a[i], width: a[i].width));
    }

    // Ascending parameter = 1
    final ascending = Const(direction);

    final newValA = Logic(width: 8);
    final newValB = Logic(width: 8);

    Sequential(clk, [
      If(
          (ascending & (_inputs[i] > _inputs[j])) |
              (~ascending & _inputs[i].lt(_inputs[j])),
          then: [
            newValA < _inputs[j],
            newValB < _inputs[i],
          ],
          orElse: [
            newValA < _inputs[i],
            newValB < _inputs[j]
          ]),
    ]);

    _inputs[i] = newValA;
    _inputs[j] = newValB;

    for (var k = 0; k < _inputs.length; k++) {
      _outputs.add(addOutput('y$k', width: _inputs[k].width));
      _outputs[k] <= _inputs[k];
    }
  }
}

class BitonicMerge extends Module {
  List<Logic> _inputs = [];
  final List<Logic> _outputs = [];

  List<Logic> get yList => _outputs;

  BitonicMerge(
      Logic clk, Logic reset, List<Logic> a, int low, int cnt, int direction)
      : super(name: 'bitonic_merge_${low}_$cnt') {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    for (var i = 0; i < a.length; i++) {
      _inputs.add(addInput('x$i', a[i], width: a[i].width));
    }

    if (cnt > 1) {
      final k = cnt ~/ 2;
      for (var i = low; i < low + k; i++) {
        // compare and swap based on direction
        final swap = CompareSwap(clk, reset, _inputs, i, i + k, direction);
        _inputs = swap.yList;
      }

      final mergeLeft = BitonicMerge(clk, reset, _inputs, low, k, direction);
      final mergeRight =
          BitonicMerge(clk, reset, _inputs, low + k, k, direction);

      for (var i = 0; i < _inputs.length; i++) {
        _outputs.add(addOutput('y$i', width: _inputs[i].width));
        _outputs[i] <= _inputs[i];
      }
    }
  }
}

class BitonicSort extends Module {
  final List<Logic> _inputs = [];
  final List<Logic> _outputs = [];

  List<Logic> get yList => _outputs;

  BitonicSort(
      Logic clk, Logic reset, List<Logic> a, int low, int cnt, int direction,
      {super.name}) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    // add input port
    for (var i = 0; i < a.length; i++) {
      _inputs.add(addInput('x$i', a[i], width: a[i].width));
    }

    // add output port
    for (var i = 0; i < a.length; i++) {
      _outputs.add(addOutput('y$i', width: a[i].width));
    }

    if (cnt > 1) {
      final k = cnt ~/ 2;
      // sort ascending
      final sortLeft = BitonicSort(clk, reset, _inputs, low, k, 1,
          name: 'sort_left_${low}_$k');

      // sort decending
      final sortRight = BitonicSort(clk, reset, _inputs, low + k, k, 0,
          name: 'sort_right_${low + k}_$k');

      // var temp = _inputs;
      // temp.setRange(low, low + k, sortLeft.yList.sublist(low, low + k));

      // temp.setRange(
      //     low + k, low + k + k, sortRight.yList.sublist(low + k, low + k + k));

      // ...sortLeft.yList.sublist(low, low + k),
      // ...sortRight.yList.sublist(low + k, low + k + k)

      final y = BitonicMerge(clk, reset, _inputs, low, cnt, direction);
      for (var i = 0; i < y.yList.length; i++) {
        _outputs[i] <= y.yList[i];
      }
    }
  }
}

Future<void> main() async {
  const dataWidth = 8;

  const direction = 1;

  final clk = SimpleClockGenerator(10).clk;
  final reset = Logic(name: 'reset');

  const logInputNum = 2;
  final x = <Logic>[
    Const(8, width: dataWidth),
    Const(3, width: dataWidth),
    Const(4, width: dataWidth),
    Const(9, width: dataWidth),
    // Const(6, width: dataWidth),
    // Const(2, width: dataWidth),
    // Const(1, width: dataWidth),
    // Const(7, width: dataWidth)
  ];

  final topMod = BitonicSort(
    clk,
    reset,
    x,
    0, // low: first index
    pow(2, logInputNum).toInt(),
    direction,
    name: 'top_level',
  );
  await topMod.build();

  print(topMod.generateSynth());

  reset.inject(1);

  Simulator.setMaxSimTime(100);
  WaveDumper(topMod, outputPath: 'lib/src/sort/recursive_list.vcd');

  Simulator.registerAction(25, () {
    reset.put(0);
  });

  await Simulator.run();
}
