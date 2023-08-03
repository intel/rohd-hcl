// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// find.dart
// Implementation of Find Functionality.
//
// 2023 July 11
// Author: Rahul Gautham Putcha <rahul.gautham.putcha@intel.com>
//

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Find functionality
///
/// Takes in a [Logic] to find location of `1`s or `0`s
class Find extends Module {
  /// [_output] is output of Find (use index for accessing from outside Module)
  late Logic _output;

  /// [index] is an getter for output of Find
  Logic get index => _output;

  /// Find `1`s or `0`s
  ///
  /// Takes in filter search parameter [countOne], default [Find] `1`.
  /// If [countOne] is `true` [Find] `1` else [Find] `0`.
  ///
  /// By default [Find] will look for first search parameter `1` or `0`.
  /// If [n] is given, [Find] an [n]th search from first
  /// occurance
  Find(Logic bus, {bool countOne = true, Logic? n}) {
    bus = addInput('bus', bus, width: bus.width);
    if (n != null) {
      n = addInput('n', n, width: n.width);
      final oneHotList = <Logic>[];
      for (var i = 0; i < bus.width; i++) {
        if (countOne && i == 0) {
          oneHotList.add(~bus[i] & n.eq(0));
        } else {
          final zeroCount = Count(bus.getRange(0, i + 1), countOne: countOne);

          var paddedNValue = n;
          var paddedCountValue = zeroCount.index;
          if (n.width < zeroCount.index.width) {
            paddedNValue = n.zeroExtend(zeroCount.index.width);
          } else {
            paddedCountValue = zeroCount.index.zeroExtend(n.width);
          }

          // If `bus[i]` is a `0` and the number of `0`'s from index 0 to `i`
          // is `n`
          oneHotList.add((countOne ? bus[i] : ~bus[i]) &
              paddedCountValue.eq(paddedNValue));
        }
      }

      final bin = OneHotToBinary(oneHotList.rswizzle()).binary;
      _output = addOutput('findNthOne', width: bin.width);
      _output <= bin;
    } else {
      final oneHotList = <Logic>[];
      for (var i = 0; i < bus.width; i++) {
        final busCheck = countOne ? bus[i] : ~bus[i];
        if (i == 0) {
          oneHotList.add(busCheck);
        } else {
          final rangeCheck =
              countOne ? ~bus.getRange(0, i).or() : bus.getRange(0, i).and();
          oneHotList.add(busCheck & rangeCheck);
        }
      }

      final bin = OneHotToBinary(oneHotList.rswizzle()).binary;
      _output = addOutput('findFirstOne', width: bin.width);
      _output <= bin;
    }
  }
}
