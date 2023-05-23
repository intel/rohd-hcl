// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sort.dart
// Implementation of sorting module.
//
// 2023 April 18
// Author: Yao Jing Quek <yao.jing.quek@intel.com>
//

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// An abstract class for all sort algorithm.
abstract class Sort extends Module {
  /// The List of logic to Sort
  final Iterable<Logic> toSort;

  /// Whether the sort [isAscending] order.
  final bool isAscending;

  /// Sort algorithm MUST have List of [toSort], direction of
  /// sort [isAscending] and a name for the sorting module.
  Sort({required this.toSort, this.isAscending = true, super.name});
}

/// Compare and Swap [Logic] to the specified order.
class _CompareSwap extends Module {
  final List<Logic> _inputs = [];

  /// The list of sorted [Logic] result.
  final List<Logic> _outputs = [];

  /// The [swapped] list of result.
  List<Logic> get swapped => _outputs;

  /// The sorting [isAscending] that this [_CompareSwap] should
  /// compare and swap.
  final bool isAscending;

  /// Compare and Swap the order of [i] and [j] in [toSort] based on the
  /// direction given.
  ///
  /// The position [i] and [j] will swapped if [isAscending] is 1 and [_inputs]
  /// of [i] greater than [_inputs] of [j] or [isAscending] is 0 and [_inputs]
  /// of [i] lower than [_inputs] of [j]. The latency of the signals will only
  /// be increased by 1 cycle if the signals for [i] and [j] are considered for
  /// swapping.
  _CompareSwap(Logic clk, Logic reset, List<Logic> toSort, int i, int j,
      {required this.isAscending})
      : super(name: 'compare_swap_${i}_$j') {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    for (var i = 0; i < toSort.length; i++) {
      _inputs.add(addInput('toSort$i', toSort[i], width: toSort[i].width));
    }

    final ascending = isAscending == true ? Const(1) : Const(0);
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
      _outputs.add(addOutput('swapped$k', width: _inputs[k].width));
      _outputs[k] <= _inputs[k];
    }
  }
}

class _BitonicMerge extends Module {
  /// A list of [Logic] that hold inputs.
  List<Logic> _inputs = [];

  /// A list of [Logic] that hold the final outputs of List of result.
  final List<Logic> _outputs = [];

  /// The [sorted] result.
  List<Logic> get sorted => UnmodifiableListView(_outputs);

  /// Merge and sort [bitonicSequence] based on [isAscending] given.
  ///
  /// List of [Logic] will compare and swap [Logic] position based on the
  /// [isAscending] given by [BitonicSort] to first created a bitonic sequence.
  /// The final stage will sort the bitonic sequence into sorted order
  /// of [isAscending].
  _BitonicMerge(
    Logic clk,
    Logic reset, {
    required bool isAscending,
    required Iterable<Logic> bitonicSequence,
    super.name = 'bitonic_merge',
  }) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    for (var i = 0; i < bitonicSequence.length; i++) {
      _inputs.add(addInput('bitonicSequence$i', bitonicSequence.elementAt(i),
          width: bitonicSequence.elementAt(i).width));
    }

    if (_inputs.length > 1) {
      for (var i = 0; i < 0 + _inputs.length ~/ 2; i++) {
        final indexA = i;
        final indexB = i + _inputs.length ~/ 2;
        final swap = _CompareSwap(clk, reset, _inputs, indexA, indexB,
            isAscending: isAscending);
        _inputs = swap.swapped;
      }

      final mergeLeft = _BitonicMerge(
        clk,
        reset,
        bitonicSequence: _inputs.getRange(0, _inputs.length ~/ 2),
        isAscending: isAscending,
        name: 'merge_left',
      );
      final mergeRight = _BitonicMerge(
        clk,
        reset,
        bitonicSequence: _inputs.getRange(_inputs.length ~/ 2, _inputs.length),
        isAscending: isAscending,
        name: 'merge_right',
      );

      final mergeRes = mergeLeft.sorted + mergeRight.sorted;

      for (var i = 0; i < mergeRes.length; i++) {
        _outputs.add(addOutput('sorted_$i', width: mergeRes[i].width));
        _outputs[i] <= mergeRes[i];
      }
    } else if (_inputs.length == 1) {
      _outputs.add(addOutput('sorted_0', width: _inputs[0].width));
      _outputs[0] <= _inputs[0];
    }
  }
}

/// Bitonic Sort is a pipelined sort module that sort [toSort] to
/// specified order based on [isAscending].
///
/// Bitonic Sort is a pipeline comparison based sorting module that recursively
/// constructus a bitonic sequence and then utilizes a pipeline to merge and
/// compare pairs of elements for sorting the sequence in either ascending or
/// descending order.
///
/// The latency of this sorter is denoted by summation of x where the index of
/// summation is i = 1, and upper limit of the summation is log base two of
/// inputs. The details information on bitonic sort can be check on
/// https://en.wikipedia.org/wiki/Bitonic_sorter.
class BitonicSort extends Sort {
  /// The list of inputs port.
  final List<Logic> _inputs = [];

  /// The list of outputs port.
  final List<Logic> _outputs = [];

  /// The [sorted] result.
  List<Logic> get sorted => UnmodifiableListView(_outputs);

  /// Constructs a [Module] to sort list of [Logic].
  ///
  /// The sorting module will recursively split inputs into a bitonic sequence
  /// perform sorting based on [isAscending] flag given to the module.
  ///
  /// The below example shows a simple use case to sort four inputs
  /// in ascending order:
  /// ```dart
  /// final toSort = <Logic>[
  ///   Const(0, width: 8);
  ///   Const(3, width: 8);
  ///   Const(1, width: 8);
  ///   Const(7, width: 8);
  /// ];
  ///
  /// final sortMod =
  ///            BitonicSort(clk, reset, toSort: toSort, name: 'top_level');
  /// await sortMod.build();
  /// ```
  BitonicSort(Logic clk, Logic reset,
      {required super.toSort, super.isAscending, super.name}) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    int? prevWidth;
    final inputLength = super.toSort.length;

    for (final signal in toSort) {
      prevWidth = prevWidth ?? signal.width;

      if (signal.width != prevWidth) {
        throw RohdHclException('All inputs width must be the same.');
      } else {
        prevWidth = signal.width;
      }
    }

    if (((inputLength != 0) && (inputLength & (inputLength - 1) == 0)) ==
        false) {
      throw RohdHclException('Bitonic sort requires inputs length of '
          'power of 2.');
    }

    for (var i = 0; i < toSort.length; i++) {
      _inputs.add(addInput('toSort$i', super.toSort.elementAt(i),
          width: super.toSort.elementAt(i).width));
    }

    if (_inputs.length > 1) {
      final sortLeft = BitonicSort(clk, reset,
          toSort: _inputs.getRange(0, _inputs.length ~/ 2),
          name: 'sort_left_${_inputs.length ~/ 2}');

      final sortRight = BitonicSort(clk, reset,
          toSort: _inputs.getRange(_inputs.length ~/ 2, _inputs.length),
          isAscending: false,
          name: 'sort_right_${_inputs.length ~/ 2}');

      final bitonicSequence = sortLeft.sorted + sortRight.sorted;
      final mergeResult = _BitonicMerge(clk, reset,
              bitonicSequence: bitonicSequence, isAscending: isAscending)
          .sorted;
      for (var i = 0; i < mergeResult.length; i++) {
        _outputs.add(addOutput('sorted_$i', width: _inputs[i].width));
        _outputs[i] <= mergeResult[i];
      }
    } else {
      _outputs.add(addOutput('sorted_0', width: _inputs[0].width));
      _outputs[0] <= _inputs[0];
    }
  }
}
