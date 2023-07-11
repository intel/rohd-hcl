// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fifo.dart
// Implementation of FIFOs.
//
// 2023 March 13
// Author: Rahul Gautham Putcha <rahul.gautham.putcha@intel.com>
//

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/utils.dart';

/// Doc coming soon...
class FindFirstOne extends Module {
  /// Doc coming soon...
  late Logic _output;

  /// Doc coming soon...
  Logic get index => _output;

  /// Doc coming soon...  First 1 from the least significan (right)
  FindFirstOne(Logic bus) {
    final oneHotList = <Logic>[];
    for (var i = 0; i < bus.width; i++) {
      oneHotList.add(bus[i] & ~bus.getRange(0, i).or());
    }

    final bin = OneHotToBinary(oneHotList.rswizzle()).binary;
    _output = addOutput('findFirstOne', width: bin.width);
    _output <= bin;
  }
}

/// Doc coming soon...
class FindFirstZero extends Module {
  /// Doc coming soon...
  late Logic _output;

  /// Doc coming soon...
  Logic get index => _output;

  /// Doc coming soon...  First 1 from the least significan (right)
  FindFirstZero(Logic bus) {
    final oneHotList = <Logic>[];
    for (var i = 0; i < bus.width; i++) {
      if (i == 0)
        oneHotList.add(~bus[i]);
      else
        oneHotList.add(~bus[i] & bus.getRange(0, i).and());
    }

    final bin = OneHotToBinary(oneHotList.rswizzle()).binary;
    _output = addOutput('findFirstZero', width: bin.width);
    _output <= bin;
  }
}

/// Doc coming soon...
class FindNthOne extends Module {
  /// Doc coming soon...
  late Logic _output;

  /// Doc coming soon...
  Logic get index => _output;

  /// Doc coming soon...  First 1 from the least significan (right)
  FindNthOne(Logic bus, Logic n) {
    final oneHotList = <Logic>[];
    for (var i = 0; i < bus.width; i++) {
      final oneCount = Count(bus.getRange(0, i + 1));

      var paddedNValue = n;
      var paddedCountValue = oneCount.index;
      if (n.width < oneCount.index.width) {
        paddedNValue = n.zeroExtend(oneCount.index.width);
      } else {
        paddedCountValue = oneCount.index.zeroExtend(n.width);
      }

      // If `bus[i]` is a `1` and the number of `1`'s from index 0 to `i` is `n`
      oneHotList.add(bus[i] & paddedCountValue.eq(paddedNValue));
    }

    final bin = OneHotToBinary(oneHotList.rswizzle()).binary;
    _output = addOutput('findNthOne', width: bin.width);
    _output <= bin;
  }
}

/// Doc coming soon...
class FindNthZero extends Module {
  /// Doc coming soon...
  late Logic _output;

  /// Doc coming soon...
  Logic get index => _output;

  /// Doc coming soon...  First 1 from the least significan (right)
  FindNthZero(Logic bus, Logic n) {
    final oneHotList = <Logic>[];
    for (var i = 0; i < bus.width; i++) {
      if (i == 0) {
        oneHotList.add(~bus[i] & n.eq(0));
      } else {
        final zeroCount = Count(bus.getRange(0, i), countOne: false);

        var paddedNValue = n;
        var paddedZeroCountValue = zeroCount.index;
        if (n.width < zeroCount.index.width) {
          paddedNValue = n.zeroExtend(zeroCount.index.width);
        } else {
          paddedZeroCountValue = zeroCount.index.zeroExtend(n.width);
        }

        // If `bus[i]` is a `0` and the number of `0`'s from index 0 to `i` is `n`
        oneHotList.add(~bus[i] & paddedZeroCountValue.eq(paddedNValue));
      }
    }

    final bin = OneHotToBinary(oneHotList.rswizzle()).binary;
    _output = addOutput('findNthOne', width: bin.width);
    _output <= bin;
  }
}

/// Doc coming soon...
class Count extends Module {
  /// Doc coming soon...
  late Logic _output;

  /// Doc coming soon...
  Logic get index => _output;

  /// Doc coming soon...  First 1 from the least significan (right)
  Count(Logic bus, {bool countOne = true}) {
    Logic count = Const(0, width: max(1, log2Ceil(bus.width)));
    for (var i = 0; i < bus.width; i++) {
      count += bus[i].zeroExtend(count.width);
    }
    _output =
        addOutput('count${countOne ? "One" : "Zero"}', width: count.width);

    _output <=
        (countOne
            // count one
            ? count
            // Count zero by removing one's from bus width
            : Const(bus.width, width: count.width) - count);
  }
}
