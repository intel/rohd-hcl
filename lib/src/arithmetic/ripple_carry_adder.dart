// Copyright (C) 2023-2024 Intel Corporation
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
  /// Constructs an n-bit adder based on inputs List of inputs.
  RippleCarryAdder(super.a, super.b,
      {super.carryIn, super.name = 'ripple_carry_adder_carry_in'})
      : super(definitionName: 'RippleCarryAdder_W${a.width}') {
    Logic? carry;
    final sumList = <Logic>[];
    for (var i = 0; i < a.width; i++) {
      final fullAdder =
          FullAdder(a[i], b[i], carryIn: carry ?? (carryIn ?? Const(0)));

      carry = fullAdder.sum[1];
      sumList.add(fullAdder.sum[0]);
    }

    sumList.add(carry!);
    sum <= sumList.rswizzle();
  }
}
