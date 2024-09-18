// Copyright (C) 2024 Intel Corporation
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

  /// Finds an extrema of List<[Logic]> [toCompare]. Inputs need not be the same
  /// width, and will all be considered positive unsigned numbers.
  ///
  /// If [max] is `true`, will find maximum value, else will find minimum.
  /// If [first] is `true`, will find first extrema, else will find last.
  ///
  /// Outputs the [index] and [val] of the extrema in the list of [toCompare].

  Extrema(List<Logic> toCompare, {bool max = true, bool first = true}) {
    // List to consume inputs internally.
    final logics = <Logic>[];

    // Adds input for every element in the toCompare list, to logics.
    for (var i = 0; i < toCompare.length; i++) {
      logics.add(
          addInput('toCompare$i', toCompare[i], width: toCompare[i].width));
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

    // Function to handle for loop logic.
    // If max is true, find max value. Else, find min value.
    void logicExtrema(int i) {
      final compareVal =
          max ? logics[i].gt(extremaVal) : logics[i].lt(extremaVal);
      extremaVal = Logic(name: 'myName$i', width: maxWidth)
        ..gets(mux(compareVal, logics[i], extremaVal));
      extremaIndex = mux(compareVal, Const(i, width: indexWidth), extremaIndex);
    }

    // If first is true, find first instance of extrema value. Else, find last.
    if (first) {
      for (var i = 1; i < logics.length; i++) {
        logicExtrema(i);
      }
    } else {
      extremaVal = logics[logics.length - 1];
      extremaIndex = Const(logics.length - 1, width: indexWidth);
      for (var i = logics.length - 2; i >= 0; i--) {
        logicExtrema(i);
      }
    }

    // Generate outputs here.
    addOutput('index', width: extremaIndex.width);
    index <= extremaIndex;

    addOutput('val', width: extremaVal.width);
    val <= extremaVal;
  }
}
