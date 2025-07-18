// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// count.dart
// Implementation of Count Functionality.
//
// 2023 July 11
// Author: Rahul Gautham Putcha <rahul.gautham.putcha@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/utils.dart';

/// [Count] `1` or `0`.
class Count extends Module {
  /// [_output] is output of [Count] (use index for accessing from outside
  /// Module).
  late Logic _output;

  /// [index] is an getter for output of [Count].
  @Deprecated('Use `count` instead')
  Logic get index => _output;

  /// The resulting count.
  Logic get count => _output;

  /// [Count] `1` or `0`.
  ///
  /// Takes in [bus] of type [Logic]. by default performs [countOne] (`1`)
  /// if [countOne] is `false` will count `0`
  Count(Logic bus,
      {bool countOne = true, super.name = 'count', String? definitionName})
      : super(definitionName: definitionName ?? 'Count_W${bus.width}') {
    bus = addInput('bus', bus, width: bus.width);
    Logic count = Const(0, width: max(1, log2Ceil(bus.width + 1)));
    for (var i = 0; i < bus.width; i++) {
      count += (countOne ? bus[i] : ~bus[i]).zeroExtend(count.width);
    }
    _output =
        addOutput('count${countOne ? "One" : "Zero"}', width: count.width);

    _output <= count;
  }
}
