// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// count_pattern.dart
// Implementation of Count Pattern Functionality.
//
// 2025 June 24
// Author: Ramli, Nurul Izziany <nurul.izziany.ramli@intel.com>
//

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/utils.dart';

/// [CountPattern] functionality.
///
/// Takes in a [Logic] `bus` to count occurrences of a fixed-width pattern.
/// Outputs pin `count` contains the number of occurrences of the
/// pattern in the bus.

class CountPattern extends Module {
  /// [_output] is output of CountPattern.
  /// Use count for accessing from outside Module.
  late Logic _output;

  /// [count] is a getter for output of CountPattern.
  Logic get count => _output;

  /// If [generateError] is `true`, an error output will be generated
  /// when the pattern is not found in the bus.
  final bool generateError;

  /// [error] is a getter for error in CountPattern and is generated when
  /// [generateError] is `true`.
  /// When pattern is not found, it will result in error `1`.
  Logic? get error => tryOutput('error');

  /// Count the number of occurence of a fixed-width pattern in a bus.
  ///
  /// Takes in [bus] of type [Logic].
  /// [pattern] is the pattern to be counted in the bus.
  /// If [fromStart] is `true`, the search starts from the beginning of the bus.
  /// If [fromStart] is `false`, the search starts from the end of the bus.
  CountPattern(Logic bus, Logic pattern,
      {bool fromStart = true, this.generateError = false})
      : super(definitionName: 'CountPattern_W${bus.width}_P${pattern.width}') {
    bus = addInput('bus', bus, width: bus.width);
    pattern = addInput('pattern', pattern, width: pattern.width);

    // Initialize count to zero
    Logic count = Const(0, width: max(1, log2Ceil(bus.width + 1)));

    for (var i = 0; i <= bus.width - pattern.width; i = i + 1) {
      int minBit;
      int maxBit;
      if (fromStart) {
        // Read from start of the bus
        minBit = i;
        maxBit = i + pattern.width;
      } else {
        // Read from end of the bus
        minBit = bus.width - i - pattern.width;
        maxBit = bus.width - i;
      }

      // Check if pattern matches, add to count
      final valCheck = bus.getRange(minBit, maxBit).eq(pattern);
      count += valCheck.zeroExtend(count.width);
    }

    _output = addOutput('count', width: count.width);
    _output <= count;

    if (generateError) {
      // If pattern is not found (count equals to 0), return error
      addOutput('error');
      error! <= count.eq(0);
    }
  }
}
