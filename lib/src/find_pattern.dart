// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// find_pattern.dart
// Implementation of Find Pattern Functionality.
//
// 2025 March 07
// Author: Ramli, Nurul Izziany <nurul.izziany.ramli@intel.com>
//

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// [FindPattern] functionality
///
/// Takes in a [Logic] `bus` to find location of a fixed-width pattern.
/// Outputs pin `index` contains position of the pattern in the bus.
class FindPattern extends Module {
  /// [index] is a getter for output of FindPattern.
  /// It contains the position of the pattern in the bus depending on the
  /// search direction defined.
  /// [index] starts from `0` based and is `0` if pattern is not found.
  Logic get index => output('index');

  /// [error] is a getter for error in FindPattern and is generated when
  /// [generateError] is `true`.
  /// When pattern is not found it will result in error `1`.
  Logic? get error => tryOutput('error');

  /// If [generateError] is `true`, [error] output will be generated.
  final bool generateError;

  /// Find a position for a fixed-width pattern in a bus.
  ///
  /// Takes in search pattern [pattern] and a boolean [fromStart] to
  /// determine the search direction.
  /// If [fromStart] is `true`, the search starts from the beginning of the bus.
  /// If [fromStart] is `false`, the search starts from the end of the bus.
  ///
  /// By default, [FindPattern] will look for the first occurrence
  /// of the pattern and returns an output [index] containing the position.
  /// If [n] is given, [FindPattern] will find the N'th occurrence
  /// of the pattern.
  /// [n] starts from `0` as the first occurrence.
  /// [index] position starts from `0` as the first position in bus.
  ///
  /// For example, if [bus] is `10000001` and [pattern] is `01`, the [index]
  /// will be `0` if [fromStart] is `true` as the pattern is found at the
  /// 0th position from the start of the bus. Otherwise, if [fromStart] is
  /// `false`, the [index] will be `6` as the pattern is found at the
  /// 6th position from end of the bus.
  ///
  /// [index] will be `0` when pattern is not found.
  FindPattern(Logic bus, Logic pattern,
      {bool fromStart = true, Logic? n, this.generateError = false})
      : super(definitionName: 'FindPattern_W${bus.width}_P${pattern.width}') {
    bus = addInput('bus', bus, width: bus.width);
    pattern = addInput('pattern', pattern, width: pattern.width);

    // A list to store the index of the found pattern
    final indexList = <Logic>[];

    if (n != null) {
      n = addInput('n', n, width: n.width);
    }

    // Initialize counter pattern occurrence to 0
    var count = Const(0, width: log2Ceil(bus.width + 1)).named('count');
    final nVal = ((n ?? Const(0)) + 1)
        .named('nVal')
        .zeroExtend(count.width)
        .named('nValX');

    for (var i = 0; i <= bus.width - pattern.width; i = i + 1) {
      int minBit;
      int maxBit;
      if (fromStart) {
        // Read from start of bus
        minBit = i;
        maxBit = i + pattern.width;
      } else {
        // Read from end of bus
        minBit = bus.width - i - pattern.width;
        maxBit = bus.width - i;
      }

      // Check if pattern matches, add to count
      final valCheck = bus.getRange(minBit, maxBit).eq(pattern);
      count = (count + valCheck.zeroExtend(count.width).named('valCheck_$i'))
          .named('count_$i');
      // Append result to the index list
      indexList.add(valCheck & nVal.eq(count));
    }
    final indexBinary = OneHotToBinary(indexList.rswizzle());
    final bin = indexBinary.binary;
    addOutput('index', width: bin.width);
    index <= bin;

    if (generateError) {
      // If pattern is not found, return error
      addOutput('error');
      error! <= count.lt(nVal) | count.eq(0);
    }
  }
}
