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
class RippleCarryAdder extends Module {
  /// The List of results returned from the [FullAdder].
  final _sum = <Logic>[];

  /// The final result of the NBitAdder in a list of Logic.
  List<Logic> get sum => _sum;

  /// Constructs an n-bit adder based on inputs [a] and [b].
  RippleCarryAdder(Logic a, Logic b) : super(name: 'ripple_carry_adder') {
    Logic carry = Const(0);

    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);
    carry = addInput('carry_in', carry, width: carry.width);

    final n = a.width;
    FullAdder? res;

    assert(a.width == b.width, 'a and b should have same width.');

    for (var i = 0; i < n; i++) {
      res = FullAdder(a: a[i], b: b[i], carryIn: carry);

      carry = res.cOut;
      _sum.add(res.sum);
    }

    _sum.add(carry);
  }
}
