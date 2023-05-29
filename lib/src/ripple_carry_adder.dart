// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// carry_save_multiplier.dart
// Implementation of pipeline multiplier module.
//
// 2023 May 29
// Author: Yao Jing Quek <yao.jing.quek@intel.com>
//

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An [RippleCarryAdder] that perform addition.
class RippleCarryAdder extends Adder {
  /// The List of results returned from the [FullAdder].
  final _sum = <Logic>[];

  /// The final result of the NBitAdder in a list of Logic.
  @override
  List<Logic> get sum => _sum;

  /// Constructs an n-bit adder based on inputs List of inputs.
  RippleCarryAdder({required super.toSum, super.name}) {
    Logic carry = Const(0);

    if (toSum.length != 2) {
      throw RohdHclException('Length of toSum must be two.');
    }

    final a = addInput('a', toSum[0], width: toSum[0].width);
    final b = addInput('b', toSum[1], width: toSum[1].width);
    carry = addInput('carry_in', carry, width: carry.width);

    if (a.width != b.width) {
      throw RohdHclException('a and b should have same width.');
    }

    for (var i = 0; i < a.width; i++) {
      FullAdder? fullAdder;
      fullAdder = FullAdder(a: a[i], b: b[i], carryIn: carry);

      carry = fullAdder.carryOut;
      _sum.add(fullAdder.sum);
    }

    _sum.add(carry);
  }
}
