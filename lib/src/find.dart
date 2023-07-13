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
import 'package:rohd_hcl/src/count.dart';

/// Doc coming soon...
class Find extends Module {
  /// Doc coming soon...
  late Logic _output;

  /// Doc coming soon...
  Logic get index => _output;

  /// Find `1` or `0` (redo)
  ///
  /// `one`: filter search parameter, if one is true find `1` else find `0`
  ///
  /// `n`: if n is given find nth else find first occurance
  /// filter search parameter
  ///
  ///
  /// TODO:
  /// Defines a flag.
  ///
  /// Throws an [ArgumentError] if there is already an option named [name] or
  /// there is already an option using abbreviation [abbr]. Returns the new flag.
  Find(Logic bus, {bool one = true, Logic? n}) {
    if (n != null) {
      if (one) {
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

          // If `bus[i]` is a `1` and the number of `1`'s from index 0 to `i`
          // is `n`
          oneHotList.add(bus[i] & paddedCountValue.eq(paddedNValue));
        }

        final bin = OneHotToBinary(oneHotList.rswizzle()).binary;
        _output = addOutput('findNthOne', width: bin.width);
        _output <= bin;
      } else {
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

            // If `bus[i]` is a `0` and the number of `0`'s from index 0 to `i`
            // is `n`
            oneHotList.add(~bus[i] & paddedZeroCountValue.eq(paddedNValue));
          }
        }

        final bin = OneHotToBinary(oneHotList.rswizzle()).binary;
        _output = addOutput('findNthOne', width: bin.width);
        _output <= bin;
      }
    } else {
      final oneHotList = <Logic>[];
      if (one) {
        for (var i = 0; i < bus.width; i++) {
          oneHotList.add(bus[i] & ~bus.getRange(0, i).or());
        }

        final bin = OneHotToBinary(oneHotList.rswizzle()).binary;
        _output = addOutput('findFirstOne', width: bin.width);
        _output <= bin;
        return;
      }

      for (var i = 0; i < bus.width; i++) {
        if (i == 0) {
          oneHotList.add(~bus[i]);
        } else {
          oneHotList.add(~bus[i] & bus.getRange(0, i).and());
        }
      }

      final bin = OneHotToBinary(oneHotList.rswizzle()).binary;
      _output = addOutput('findFirstZero', width: bin.width);
      _output <= bin;
    }
  }
}
