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

/// Takes in a List<[Logic]> to find position and value of extremas (max or min)
/// of signals.
///
/// Outputs [index] contains position of first extrema signal and [val] contains
/// corresponding signal value.

class Extrema extends Module {
  /// [index] is a getter for output of Extrema.
  Logic get index => output('index');

  /// [val] is a getter for output of Extrema.
  Logic get val => output('val');

  /// Finds an extrema of List<[Logic]> [toCompare]. Inputs need not be the same
  /// width, and will all be considered positive unsigned numbers.
  /// If [max] is `true`, will find maximum value, else will find minimum value.
  /// Outputs [index] and [val] of first extrema in the list of [toCompare].

  Extrema(List<Logic> toCompare, {bool max = true}) {
    // List to consume inputs internally.
    final toCompareInternal = <Logic>[];

    // Adds input for every element in the toCompare list, to toCompareInternal.
    for (var i = 0; i < toCompare.length; i++) {
      toCompareInternal.add(
          addInput('toCompare$i', toCompare[i], width: toCompare[i].width));
    }

    // Check if list is empty
    if (toCompareInternal.isEmpty) {
      throw RohdHclException('List cannot be empty.');
    }

    // Find the max width of all inputs.
    var maxWidth = 0;
    for (var i = 0; i < toCompareInternal.length; i++) {
      if (toCompareInternal[i].width > maxWidth) {
        maxWidth = toCompareInternal[i].width;
      }
    }

    // Check max width and prepend with 0s. Will make all inputs same width.
    for (var i = 0; i < toCompareInternal.length; i++) {
      if (toCompareInternal[i].width < maxWidth) {
        toCompareInternal[i] = toCompareInternal[i].zeroExtend(maxWidth);
      }
    }

    // Initializes extremaVal with value from index 0 of toCompareInternal.
    var extremaVal = toCompareInternal[0];

    // Find indexWidth and initialize extremaIndex with index to 0.
    final indexWidth = log2Ceil(toCompareInternal.length);
    Logic extremaIndex = Const(0, width: indexWidth);

    // If max is true, find max value. Else, find min value.
    for (var i = 1; i < toCompareInternal.length; i++) {
      final compareVal = max
          ? toCompareInternal[i].gt(extremaVal)
          : toCompareInternal[i].lt(extremaVal);
      extremaVal = Logic(name: 'myName$i', width: maxWidth)
        ..gets(mux(compareVal, toCompareInternal[i], extremaVal));
      extremaIndex = mux(compareVal, Const(i, width: indexWidth), extremaIndex);
    }

    // Generate outputs here.
    addOutput('index', width: extremaIndex.width);
    index <= extremaIndex;

    addOutput('val', width: extremaVal.width);
    val <= extremaVal;
  }
}
