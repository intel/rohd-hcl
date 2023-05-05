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

import 'dart:async';
import 'package:rohd/rohd.dart';
import 'package:test/test.dart';

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
  final List<Logic> _outputsFinal = [];

  List<Logic> get sortedList => _outputsFinal;

  BitonicMerge(Logic clk, Logic reset, List<Logic> inputs, int direction)
      : super(name: 'bitonic_merge') {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    for (var i = 0; i < inputs.length; i++) {
      _inputs.add(addInput('x$i', inputs[i], width: inputs[i].width));
    }

    if (_inputs.length > 1) {
      final k = _inputs.length ~/ 2;

      for (var i = 0; i < 0 + k; i++) {
        // compare and swap based on direction
        final indexA = i;
        final indexB = i + k;
        final swap =
            CompareSwap(clk, reset, _inputs, indexA, indexB, direction);
        _inputs = swap.yList;
      }

      // Update the yList value to the results of the compare swap
      for (var i = 0; i < _inputs.length; i++) {
        _outputs.add(addOutput('y$i', width: _inputs[i].width));
        _outputs[i] <= _inputs[i];
      }

      // Keep on sorting the left and right of the bitonic sort
      final mergeLeft = BitonicMerge(clk, reset,
          _inputs.getRange(0, _inputs.length ~/ 2).toList(), direction);
      final mergeRight = BitonicMerge(
          clk,
          reset,
          _inputs.getRange(_inputs.length ~/ 2, _inputs.length).toList(),
          direction);

      // Combine the sorted list
      final mergeRes = mergeLeft.sortedList + mergeRight.sortedList;

      // register to the final outputs
      for (var i = 0; i < mergeRes.length; i++) {
        _outputsFinal.add(addOutput('sorted_$i', width: mergeRes[i].width));
        _outputsFinal[i] <= mergeRes[i];
      }
    } else if (_inputs.length == 1) {
      _outputsFinal.add(addOutput('sorted_0', width: _inputs[0].width));
      _outputsFinal[0] <= _inputs[0];
    }
  }
}

class BitonicSort extends Module {
  final List<Logic> _inputs = [];
  final List<Logic> _outputs = [];

  List<Logic> get yList => _outputs;

  BitonicSort(Logic clk, Logic reset, List<Logic> a, int direction,
      {super.name}) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    // add input port
    for (var i = 0; i < a.length; i++) {
      _inputs.add(addInput('x$i', a[i], width: a[i].width));
    }

    if (_inputs.length > 1) {
      final k = _inputs.length ~/ 2;
      final sortLeft = BitonicSort(
          clk, reset, _inputs.getRange(0, _inputs.length ~/ 2).toList(), 1,
          name: 'sort_left_$k');

      final sortRight = BitonicSort(clk, reset,
          _inputs.getRange(_inputs.length ~/ 2, _inputs.length).toList(), 0,
          name: 'sort_right_$k');

      final res = sortLeft.yList + sortRight.yList;

      final y = BitonicMerge(clk, reset, res, direction);
      for (var i = 0; i < y.sortedList.length; i++) {
        _outputs.add(addOutput('sorted_$i', width: _inputs[i].width));
        _outputs[i] <= y.sortedList[i];
      }
    } else {
      _outputs.add(addOutput('sorted_0', width: _inputs[0].width));
      _outputs[0] <= _inputs[0];
    }
  }
}
