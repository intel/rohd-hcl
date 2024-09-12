// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// find_min.dart
// Implementation of Find Minimum module.
//
// 2024 September 10
// Author: Roberto Torres <roberto.torres@intel.com>
//

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Takes in a List<[Logic]> to find position and value of minimum signal.
/// Output pin [index] contains position and [val] contains corresponding
///  signal value.

// Define a class FindMin that extends ROHD's abstract Module class.
class FindMin extends Module {
  /// [index] is a getter for output of FindMin
  Logic get index => output('index');

  /// [val] is a getter for output of FindMin
  Logic get val => output('val');

  /// [error] is a getter for error in FindMin
  /// When your FindMin is not found it will result in error `1`
  Logic? get error => tryOutput('error');

  /// If `true`, then the [error] output will be generated.
  final bool generateError;

  // Could take in search parameter [max] or [min]?

  // number of input ports depends on the list of logics received
  /// Find the minimum [Logic] in a ...
  FindMin(List<Logic> toCompare, {Logic? n, this.generateError = false}) {
    // Internal list to consume inputs internally
    final toCompareInternal = <Logic>[];

    // adds Input for every element in the toCompare list, to toCompareInternal
    for (var i = 0; i < toCompare.length; i++) {
      toCompareInternal.add(
          addInput('toCompare$i', toCompare[i], width: toCompare[i].width));
    }

    // needed? from find.dart
    if (n != null) {
      n = addInput('n', n, width: n.width);
    }

    // Initializes minVal with index 0 of toCompareInternal.
    var minVal = toCompareInternal[0];

    // Initializes minIndex with index to 0.
    Logic minIndex = Const(0, width: log2Ceil(toCompareInternal.length));

    // Start for loop at i = 1.
    for (var i = 1; i < toCompareInternal.length; i++) {
      minVal =
          mux(toCompareInternal[i].lt(minVal), toCompareInternal[i], minVal);
      minIndex = mux(toCompareInternal[i].lt(minVal),
          Const(i, width: log2Ceil(toCompareInternal.length)), minIndex);
    }

    // Generate outputs here.
    addOutput('index', width: minIndex.width);
    index <= minIndex;

    addOutput('val', width: minVal.width);
    val <= minVal;
/*
    // below is from find.dart May be needed
    final oneHotBinary =
        OneHotToBinary(oneHotList.rswizzle(), generateError: generateError);
    // Upon search complete, we get the position value in binary `bin` form
    final bin = oneHotBinary.binary;
    addOutput('index', width: bin.width);
    index <= bin;

    if (generateError) {
      addOutput('error');
      error! <= oneHotBinary.error!;
    }
  */
  }
}

// case of multiple drivers in [Logic] line 214 logic.dart
