// Copyright (C) 2025 Intel Corporation
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

/// Determines the extremas (maximum or minimum) of a List<[Logic]>.
class Extrema extends Module {
  /// The [index] of the extrema.
  Logic get index => output('index');

  /// The [val] of the extrema.
  Logic get val => output('val');

  /// Finds an extrema of List<[Logic]> [signals]. Inputs need not be the same
  /// width, and will all be considered positive unsigned numbers.
  ///
  /// If [max] is `true`, will find maximum value, else will find minimum.
  ///
  /// Outputs the [index] and [val] of the extrema in the list of [signals].
  Extrema(List<Logic> signals, {bool max = true})
      : super(definitionName: 'Extrema_L${signals.length}') {
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

    // Find indexWidth, initialize extremaIndex and extremaVal.
    final indexWidth = log2Ceil(logics.length);
    Logic extremaIndex = Const(0, width: indexWidth);
    var extremaVal = logics[0];

    // If max is true, find max value. Else, find min value.
    for (var i = 1; i < logics.length; i++) {
      final compareVal =
          (max ? logics[i].gt(extremaVal) : logics[i].lt(extremaVal))
              .named('compareVal_$i');
      extremaVal = Logic(name: 'muxOut$i', width: maxWidth)
        ..gets(mux(compareVal, logics[i], extremaVal).named('extremaVal_$i'));
      extremaIndex = mux(compareVal, Const(i, width: indexWidth), extremaIndex)
          .named('extremaIndex_$i');
    }

    // Generate outputs here.
    addOutput('index', width: extremaIndex.width);
    index <= extremaIndex;

    addOutput('val', width: extremaVal.width);
    val <= extremaVal;
  }
}
