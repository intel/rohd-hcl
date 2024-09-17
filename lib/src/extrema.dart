// Copyright (C) 2023-2024 Intel Corporation
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

/// Defines a class Extrema that extends ROHD's abstract Module class.
class Extrema extends Module {
  /// [index] is a getter for output of Extrema.
  Logic get index => output('index');

  /// [val] is a getter for output of Extrema.
  Logic get val => output('val');

  /// Find an extrema of List<[Logic]> [toCompare]. Will output [index] and
  /// [val] of first extrema in the list of [toCompare]. If [max] is `true`,
  /// will find maximum value, else will find minimum value.
  ///
  /// If [toCompare] contains elements of different widths, it will be extended
  /// and prepended with 0s to make all inputs same width.
  Extrema(List<Logic> toCompare, {bool max = true}) {
    // List to consume inputs internally.
    final toCompareInternal = <Logic>[];

    // Adds input for every element in the toCompare list, to toCompareInternal.
    for (var i = 0; i < toCompare.length; i++) {
      toCompareInternal.add(
          addInput('toCompare$i', toCompare[i], width: toCompare[i].width));
    }

    // Find the max width.
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

    // Initializes extremaIndex with index to 0.
    Logic extremaIndex = Const(0, width: log2Ceil(toCompareInternal.length));

    // If max is true, find max value. Else, find min value.
    if (max) {
      for (var i = 1; i < toCompareInternal.length; i++) {
        final compareVal = toCompareInternal[i].gt(extremaVal);
        extremaVal = Logic(name: 'myName$i', width: extremaVal.width)
          ..gets(mux(compareVal, toCompareInternal[i], extremaVal));
        extremaIndex = mux(compareVal,
            Const(i, width: log2Ceil(toCompareInternal.length)), extremaIndex);
      }
    } else {
      for (var i = 1; i < toCompareInternal.length; i++) {
        final compareVal = toCompareInternal[i].lt(extremaVal);
        extremaVal = Logic(name: 'myName$i', width: extremaVal.width)
          ..gets(mux(compareVal, toCompareInternal[i], extremaVal));
        extremaIndex = mux(compareVal,
            Const(i, width: log2Ceil(toCompareInternal.length)), extremaIndex);
      }
    }
    // Generate outputs here.
    addOutput('index', width: extremaIndex.width);
    index <= extremaIndex;

    addOutput('val', width: extremaVal.width);
    val <= extremaVal;
  }
}
