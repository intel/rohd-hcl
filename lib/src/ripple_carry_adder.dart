// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ripple_carry_adder.dart
// Implementation of ripple carry adder.
//
// 2023 May 29
// Author: Yao Jing Quek <yao.jing.quek@intel.com>
//

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An [RippleCarryAdder] is a digital circuit used for binary addition. It
/// consists of a series of full adders connected in a chain, with the carry
/// output of each adder linked to the carry input of the next one. Starting
/// from the least significant bit (LSB) to most significant bit (MSB), the
/// adder sequentially adds corresponding bits of two binary numbers.
class RippleCarryAdder extends Adder {
  /// The List of results returned from the [FullAdder].
  final _sum = <Logic>[];

  /// The final result of the NBitAdder in a list of Logic.
  @override
  Logic get sum => _sum.rswizzle();

  /// Constructs an n-bit adder based on inputs List of inputs.
  RippleCarryAdder(super.a, super.b, {super.name = 'ripple_carry_adder'}) {
    Logic carry = Const(0);

    final portA = addInput('a', a, width: a.width);
    final portB = addInput('b', b, width: b.width);

    if (portA.width != portB.width) {
      throw RohdHclException('inputs of a and b should have same width.');
    }

    for (var i = 0; i < portA.width; i++) {
      final fullAdder = FullAdder(a: portA[i], b: portB[i], carryIn: carry);

      carry = fullAdder.carryOut;
      _sum.add(fullAdder.sum);
    }

    _sum.add(carry);
  }
}
