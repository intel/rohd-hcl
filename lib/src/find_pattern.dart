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

/// [FindPattern] functionality
///
/// Takes in a [Logic] to find location of a fixed-width pattern.
/// Outputs pin `index` contains position.
class FindPattern extends Module {
  /// [index] is a getter for output of FindPattern
  Logic get index => output('index');

  /// [error] is a getter for error in FindPattern
  /// When your pattern is not found it will result in error `1`
  Logic? get error => tryOutput('error');

  /// If `true`, then the [error] output will be generated.
  final bool generateError;

  /// Find a position for a fixed-width pattern
  ///
  /// Takes in search pattern [pattern] and a boolean [start] to determine the
  ///  search direction.
  /// If [start] is `true`, the search starts from the beginning of the bus.
  /// If [start] is `false`, the search starts from the end of the bus.
  ///
  /// By default, [FindPattern] will look for the first occurrence
  /// of the pattern.
  /// If [n] is given, [FindPattern] will find the N'th occurrence
  /// of the pattern.
  /// [n] starts from `0` as the first occurrence.
  ///
  /// Outputs pin `index` contains the position. Position starts from `0` based.
  FindPattern(Logic bus, Logic pattern,
      {bool start = true, Logic? n, this.generateError = false})
      : super(definitionName: 'FindPattern_W${bus.width}_P${pattern.width}') {
    bus = addInput('bus', bus, width: bus.width);
    pattern = addInput('pattern', pattern, width: pattern.width);

    if (n != null) {
      n = addInput('n', n, width: n.width);
    }

    // Initialize counter pattern occurrence to 0
    Logic count = Const(0, width: bus.width);
    final nVal = (n ?? Const(0)) + 1;

    int minBit;
    int maxBit;

    for (var i = 0; i <= bus.width - pattern.width; i = i + 1) {
      if (start) {
        // Read from start of bus
        minBit = i;
        maxBit = i + pattern.width;
      } else {
        // Read from end of bus
        minBit = bus.width - i - pattern.width;
        maxBit = bus.width - i;
      }

      // Check if pattern matches
      final busVal = bus.getRange(minBit, maxBit);
      final valCheck = busVal.eq(pattern);

      // Check if pattern matches, count if found
      count += ((valCheck.value.toInt() == 1) ? 1 : 0);

      // If count matches n, break and return index
      if (nVal.value.toInt() == count.value.toInt()) {
        addOutput('index', width: bus.width);
        index <= Const(i, width: bus.width);
        break;
      }
    }

    if (generateError) {
      // If pattern is not found, return error
      final isError =
          (count.value.toInt() < nVal.value.toInt() || count.value.toInt() == 0)
              ? 1
              : 0;
      addOutput('error');
      error! <= Const(isError, width: 1);
    }
  }
}
