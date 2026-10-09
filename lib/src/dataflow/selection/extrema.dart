// Copyright (C) 2025-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// extrema.dart
// Implementation of finding extremas (max or min) of signals.
//
// 2024 September 16
// Author: Roberto Torres <roberto.torres@intel.com>
//

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Determines the extremas (maximum or minimum) of a [List<Logic>].
class Extrema extends Module {
  /// The [index] of the extrema.
  Logic get index => output('index');

  /// The [val] of the extrema.
  Logic get val => output('val');

  /// The combinational depth of the balanced indexed reduction tree.
  late final int treeDepth;

  /// Finds an extrema of [List<Logic>] [signals]. Inputs need not be the same
  /// width, and will all be considered positive unsigned numbers.
  ///
  /// If [max] is `true`, will find maximum value, else will find minimum.
  ///
  /// [radix] controls the maximum number of candidates compared by each
  /// balanced reduction node. Equal candidates preserve the earliest index.
  ///
  /// Outputs the [index] and [val] of the extrema in the list of [signals].
  Extrema(
    List<Logic> signals, {
    bool max = true,
    int radix = 2,
    super.name = 'extrema',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
          definitionName: definitionName ??
              'Extrema_W${signals.map((signal) => signal.width).join('_')}_'
                  '${max ? "Max" : "Min"}_R$radix',
        ) {
    // List to consume inputs internally.
    final logics = <Logic>[];

    // Adds input for every element in the signals list, to logics.
    for (var i = 0; i < signals.length; i++) {
      logics.add(addInput('signal$i', signals[i], width: signals[i].width));
    }

    // Check if list is empty
    if (logics.isEmpty) {
      throw RohdHclException('List cannot be empty.');
    }

    // Find the max width of all inputs.
    var maxWidth = 0;
    for (var i = 0; i < logics.length; i++) {
      if (logics[i].width > maxWidth) {
        maxWidth = logics[i].width;
      }
    }

    // Check max width and prepend with 0s. Will make all inputs same width.
    for (var i = 0; i < logics.length; i++) {
      if (logics[i].width < maxWidth) {
        logics[i] = logics[i].zeroExtend(maxWidth);
      }
    }

    // Carry each original index through the same comparisons as its value,
    // combining candidates with a balanced reduction tree.
    final indexWidth = widthFor(logics.length);
    final tree = ReductionTreeGenerator(
      [
        for (var i = 0; i < logics.length; i++)
          [Const(i, width: indexWidth), logics[i]].swizzle(),
      ],
      (inputs, {depth = 0, control, name = 'extrema'}) =>
          inputs.reduce((current, candidate) {
        final currentVal = current.getRange(0, maxWidth);
        final candidateVal = candidate.getRange(0, maxWidth);
        final selectCandidate =
            max ? candidateVal.gt(currentVal) : candidateVal.lt(currentVal);
        return mux(selectCandidate, candidate, current);
      }),
      radix: radix,
    );
    treeDepth = tree.depth;
    final extremaVal = tree.out.getRange(0, maxWidth);
    final extremaIndex = tree.out.getRange(maxWidth, maxWidth + indexWidth);

    // Generate outputs here.
    addOutput('index', width: extremaIndex.width);
    index <= extremaIndex;

    addOutput('val', width: extremaVal.width);
    val <= extremaVal;
  }
}
