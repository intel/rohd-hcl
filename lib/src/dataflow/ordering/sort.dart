// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sort.dart
// Implementation of sorting module.
//
// 2023 April 18
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/exceptions.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';

import 'package:rohd_hcl/src/utils.dart';

/// An abstract class for all sort algorithm.
abstract class Sort<T extends Logic> extends Module {
  /// The list of [Logic] to sort.
  final Iterable<T> toSort;

  // Accessed only through the covariantly checked instance method.
  // ignore: unsafe_variance
  final Logic Function(T a, T b)? _isLessThan;

  /// Strict less-than comparison, defaulting to the payload's [Logic.lt].
  Logic isLessThan(T a, T b) => _isLessThan?.call(a, b) ?? a.lt(b);

  /// Whether the sort [isAscending] order.
  final bool isAscending;

  /// Sort algorithm MUST have a list of [toSort], direction of
  /// sort [isAscending] and a name for the sorting module.
  Sort(
      {required this.toSort,
      Logic Function(T a, T b)? isLessThan,
      this.isAscending = true,
      super.name = 'sort',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : _isLessThan = isLessThan,
        super(definitionName: definitionName ?? 'Sort_W${toSort.length}');
}

/// Compare and Swap [Logic] to the specified order.
class _CompareSwap<T extends Logic> extends Module {
  final List<T> _inputs = [];

  /// The [List] of sorted [Logic] result.
  final List<T> _outputs = [];

  /// The [swapped] list of result.
  List<T> get swapped => _outputs;

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
  _CompareSwap(Logic clk, Logic reset, List<T> toSort, int i, int j,
      {required this.isAscending,
      Logic Function(T a, T b)? isLessThan,
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            name: 'compare_swap_${i}_$j',
            definitionName:
                definitionName ?? '_CompareSwap_W${toSort.length}') {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    for (var i = 0; i < toSort.length; i++) {
      _inputs.add(addTypedInput('toSort$i', toSort[i]));
    }

    final newValA = _inputs[i].cloneTyped(name: 'newValA');
    final newValB = _inputs[j].cloneTyped(name: 'newValB');
    final compare = isLessThan ?? (T a, T b) => a.lt(b);

    Sequential(clk, [
      If(
          isAscending
              ? compare(_inputs[j], _inputs[i])
              : compare(_inputs[i], _inputs[j]),
          then: [
            newValA < _inputs[j],
            newValB < _inputs[i],
          ],
          orElse: [
            newValA < _inputs[i],
            newValB < _inputs[j],
          ])
    ]);

    _inputs[i] = newValA;
    _inputs[j] = newValB;

    for (var k = 0; k < _inputs.length; k++) {
      _outputs.add(addTypedOutput('swapped$k', _inputs[k].cloneTyped));
      _outputs[k] <= _inputs[k];
    }
  }
}

/// Perfoms a bitonic merge on a bitonic sequence to produce a sorted
/// sequence. The input sequence must be bitonic.The merging process compares
/// the corresponding elements from both halves and swaps them if necessary
/// to maintain the desired order.
///
/// Returns a single sorted sequence.
class _BitonicMerge<T extends Logic> extends Module {
  /// A [List] of [Logic] that hold the final outputs of the result.
  final List<T> _outputs = [];

  /// The [sorted] result.
  List<T> get sorted => UnmodifiableListView(_outputs);

  /// Merge and sort [bitonicSequence] based on [isAscending] given.
  ///
  /// [List] of [Logic] will compare and swap [Logic] position based on the
  /// [isAscending] given by [BitonicSort] to first created a bitonic sequence.
  /// The final stage will sort the bitonic sequence into sorted order
  /// of [isAscending].
  _BitonicMerge(Logic clk, Logic reset,
      {required bool isAscending,
      required Iterable<T> bitonicSequence,
      Logic Function(T a, T b)? isLessThan,
      super.name = 'bitonic_merge',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName:
                definitionName ?? '_BitonicMerge_W${bitonicSequence.length}') {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    var inputs = <T>[];

    for (var i = 0; i < bitonicSequence.length; i++) {
      inputs.add(
          addTypedInput('bitonicSequence$i', bitonicSequence.elementAt(i)));
    }

    if (inputs.length > 1) {
      for (var i = 0; i < inputs.length ~/ 2; i++) {
        final indexA = i;
        final indexB = i + inputs.length ~/ 2;
        final swap = _CompareSwap<T>(clk, reset, inputs, indexA, indexB,
            isAscending: isAscending,
            isLessThan: isLessThan,
            reserveName: reserveName,
            reserveDefinitionName: reserveDefinitionName);
        inputs = swap.swapped;
      }

      final mergeLeft = _BitonicMerge<T>(
        clk,
        reset,
        bitonicSequence: inputs.getRange(0, inputs.length ~/ 2),
        isAscending: isAscending,
        isLessThan: isLessThan,
        name: 'merge_left',
        reserveName: reserveName,
        reserveDefinitionName: reserveDefinitionName,
      );
      final mergeRight = _BitonicMerge<T>(
        clk,
        reset,
        bitonicSequence: inputs.getRange(inputs.length ~/ 2, inputs.length),
        isAscending: isAscending,
        isLessThan: isLessThan,
        name: 'merge_right',
        reserveName: reserveName,
        reserveDefinitionName: reserveDefinitionName,
      );

      final mergeRes = mergeLeft.sorted + mergeRight.sorted;

      for (var i = 0; i < mergeRes.length; i++) {
        _outputs.add(addTypedOutput('sorted_$i', mergeRes[i].cloneTyped));
        _outputs[i] <= mergeRes[i];
      }
    } else if (inputs.length == 1) {
      _outputs.add(addTypedOutput('sorted_0', inputs[0].cloneTyped));
      _outputs[0] <= inputs[0];
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
/// The latency of this sorter is denoted by the sum of integers
/// from 1 to the log2 of the number of inputs. The details information on
/// bitonic sort can be check on https://en.wikipedia.org/wiki/Bitonic_sorter.
class BitonicSort<T extends Logic> extends Sort<T> {
  /// The [List] of inputs port.
  final List<T> _inputs = [];

  /// The [List] of outputs port.
  final List<T> _outputs = [];

  /// The [sorted] result.
  List<T> get sorted => UnmodifiableListView(_outputs);

  /// The [latency] of the bitonic sort algorithm.
  int get latency => List.generate(log2Ceil(_inputs.length) + 1, (i) => i)
      .reduce((a, b) => a + b);

  /// Constructs a [Module] to sort list of [Logic].
  ///
  /// The sorting module will recursively split inputs into a bitonic sequence
  /// perform sorting based on [isAscending] flag given to the module.
  ///
  /// All elements of [toSort] must be the same width, and the length must be a
  /// power of two.
  ///
  /// The below example shows a simple use case to sort four inputs in ascending
  /// order:
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
      {required super.toSort,
      super.isLessThan,
      super.isAscending,
      super.name = 'bitonic_sort',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ?? 'BitonicSort_W${toSort.length}') {
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

    if (!((inputLength != 0) && (inputLength & (inputLength - 1) == 0))) {
      throw RohdHclException('Bitonic sort requires inputs length of '
          'power of 2.');
    }

    for (final signal in toSort.skip(1)) {
      if (!sameDeclaredPayloadShape(toSort.first, signal)) {
        throw RohdHclException(
            'Bitonic sort requires matching payload layouts.');
      }
    }

    for (var i = 0; i < toSort.length; i++) {
      _inputs.add(addTypedInput('toSort$i', super.toSort.elementAt(i)));
    }

    if (_inputs.length > 1) {
      final sortLeft = BitonicSort<T>(clk, reset,
          toSort: _inputs.getRange(0, _inputs.length ~/ 2),
          isLessThan: isLessThan,
          name: 'sort_left_${_inputs.length ~/ 2}',
          reserveName: reserveName,
          reserveDefinitionName: reserveDefinitionName);

      final sortRight = BitonicSort<T>(clk, reset,
          toSort: _inputs.getRange(_inputs.length ~/ 2, _inputs.length),
          isAscending: false,
          isLessThan: isLessThan,
          name: 'sort_right_${_inputs.length ~/ 2}',
          reserveName: reserveName,
          reserveDefinitionName: reserveDefinitionName);

      final bitonicSequence = sortLeft.sorted + sortRight.sorted;
      final mergeResult = _BitonicMerge<T>(clk, reset,
              bitonicSequence: bitonicSequence,
              isAscending: isAscending,
              isLessThan: isLessThan,
              reserveName: reserveName,
              reserveDefinitionName: reserveDefinitionName)
          .sorted;
      for (var i = 0; i < mergeResult.length; i++) {
        _outputs.add(addTypedOutput('sorted_$i', _inputs[i].cloneTyped));
        _outputs[i] <= mergeResult[i];
      }
    } else {
      _outputs.add(addTypedOutput('sorted_0', _inputs[0].cloneTyped));
      _outputs[0] <= _inputs[0];
    }
  }
}
