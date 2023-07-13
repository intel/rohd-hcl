// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// find.dart
// Implementation of Find Functionality.
//
// 2023 July 11
// Author: Rahul Gautham Putcha <rahul.gautham.putcha@intel.com>
//

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/utils.dart';

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
