// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// vector_reduce.dart
// Masked inference vector reductions.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/conversion/numeric_narrowing.dart';
import 'package:rohd_hcl/src/bit_operations/population_count/count.dart';
import 'package:rohd_hcl/src/dataflow/reduction/reduction_tree_generator.dart';
import 'package:rohd_hcl/src/dataflow/selection/extrema.dart';

/// Reduction operation performed by [VectorReduce].
enum InferenceVectorReduction {
  /// Adds all active lanes.
  sum,

  /// Selects the smallest active lane.
  minimum,

  /// Selects the largest active lane.
  maximum,
}

int _defaultReductionWidth(
  InferenceVectorReduction operation,
  int elementWidth,
  int laneCount,
  int? requested,
) =>
    requested ??
    (operation == InferenceVectorReduction.sum
        ? elementWidth + laneCount.log2Ceil
        : elementWidth);

/// Reduces a masked one-dimensional inference vector.
/// {@category Inference}
class VectorReduce extends Module {
  /// Number of physical input lanes.
  final int laneCount;

  /// Width of each input lane.
  final int elementWidth;

  /// Width of [result].
  final int outputWidth;

  /// Reduction operation.
  final InferenceVectorReduction operation;

  /// Whether lanes and the sum are two's-complement signed.
  final bool signed;

  /// Result of the selected reduction.
  Logic get result => output('result');

  /// Original index selected by minimum or maximum.
  ///
  /// This value is not meaningful while [empty] is high.
  Logic get selectedIndex => output('selectedIndex');

  /// Number of active input lanes.
  Logic get activeCount => output('activeCount');

  /// High when no input lane is active.
  Logic get empty => output('empty');

  /// High when a sum exceeds the positive output range.
  Logic get overflowed => output('overflowed');

  /// High when a signed sum is below the output minimum.
  Logic get underflowed => output('underflowed');

  /// Creates a combinational masked vector reduction.
  VectorReduce(
    LogicArray lanes, {
    required this.operation,
    Logic? activeMask,
    this.signed = false,
    int? outputWidth,
    NumericOverflowMode overflowMode = NumericOverflowMode.saturate,
    super.name = 'vector_reduce',
  })  : laneCount = lanes.arrayElements.length,
        elementWidth = lanes.elementWidth,
        outputWidth = _defaultReductionWidth(
          operation,
          lanes.elementWidth,
          lanes.arrayElements.length,
          outputWidth,
        ),
        super(
          definitionName: 'VectorReduce_${operation.name}_'
              'L${lanes.arrayElements.length}_W${lanes.elementWidth}_'
              'O${_defaultReductionWidth(
            operation,
            lanes.elementWidth,
            lanes.arrayElements.length,
            outputWidth,
          )}_S${signed ? 1 : 0}_${overflowMode.name}_'
              'M${activeMask == null ? 0 : 1}',
        ) {
    if (lanes.dimensions.length != 1 || laneCount < 1) {
      throw ArgumentError('Input lanes must be a non-empty 1-D typed array.');
    }
    if (this.outputWidth < 1 ||
        (operation != InferenceVectorReduction.sum &&
            this.outputWidth < elementWidth)) {
      throw ArgumentError(
        'Reduction output width is invalid for the selected operation.',
      );
    }
    if (activeMask != null && activeMask.width != laneCount) {
      throw PortWidthMismatchException(activeMask, laneCount);
    }

    lanes = addTypedInput('lanes', lanes);
    final localMask = activeMask == null
        ? Const(-1, width: laneCount)
        : addInput('activeMask', activeMask, width: laneCount);
    final isEmpty = ~localMask.or();
    final count = Count(localMask, name: '${name}_active_count').count;
    final indexWidth = max(1, laneCount.log2Ceil);

    final Logic reducedResult;
    final Logic reducedIndex;
    final Logic didOverflow;
    final Logic didUnderflow;
    if (operation == InferenceVectorReduction.sum) {
      final calculationWidth =
          max(elementWidth + laneCount.log2Ceil, this.outputWidth) + 1;
      final terms = [
        for (var lane = 0; lane < laneCount; lane++)
          mux(
            localMask[lane],
            signed
                ? lanes.arrayElements[lane].signExtend(calculationWidth)
                : lanes.arrayElements[lane].zeroExtend(calculationWidth),
            Const(0, width: calculationWidth),
          ),
      ];
      final sum = ReductionTreeGenerator(
        terms,
        (inputs, {depth = 0, control, name = 'sum'}) => inputs.reduce(
          (left, right) => (left + right).getRange(0, calculationWidth),
        ),
      ).out;
      final narrowed = NumericNarrowing(
        sum,
        outputWidth: this.outputWidth,
        signed: signed,
        overflowMode: overflowMode,
        name: '${name}_narrow',
      );
      reducedResult = narrowed.result;
      reducedIndex = Const(0, width: indexWidth);
      didOverflow = narrowed.overflowed;
      didUnderflow = narrowed.underflowed;
    } else {
      final keys = <Logic>[];
      for (var lane = 0; lane < laneCount; lane++) {
        final value = signed
            ? lanes.arrayElements[lane] ^
                Const(
                  BigInt.one << (elementWidth - 1),
                  width: elementWidth,
                )
            : lanes.arrayElements[lane];
        final activePriority = operation == InferenceVectorReduction.maximum
            ? localMask[lane]
            : ~localMask[lane];
        keys.add([activePriority, value].concat());
      }
      final extrema = Extrema(
        keys,
        max: operation == InferenceVectorReduction.maximum,
        name: '${name}_extrema',
      );
      final selected = lanes.arrayElements.selectIndex(extrema.index);
      reducedResult = mux(
        isEmpty,
        Const(0, width: this.outputWidth),
        signed
            ? selected.signExtend(this.outputWidth)
            : selected.zeroExtend(this.outputWidth),
      );
      reducedIndex = extrema.index;
      didOverflow = Const(0);
      didUnderflow = Const(0);
    }

    addOutput('result', width: this.outputWidth) <= reducedResult;
    addOutput('selectedIndex', width: indexWidth) <= reducedIndex;
    addOutput('activeCount', width: count.width) <= count;
    addOutput('empty') <= isEmpty;
    addOutput('overflowed') <= didOverflow;
    addOutput('underflowed') <= didUnderflow;
  }
}
