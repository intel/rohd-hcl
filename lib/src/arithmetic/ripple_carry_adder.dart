// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ripple_carry_adder.dart
// Implementation of ripple carry adder.
//
// 2023 May 29
// Author: Yao Jing Quek <yao.jing.quek@intel.com>
//

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An [RippleCarryAdder] is a digital circuit used for binary addition. It
/// consists of a series of full adders connected in a chain, with the carry
/// output of each adder linked to the carry input of the next one. Starting
/// from the least significant bit (LSB) to most significant bit (MSB), the
/// adder sequentially adds corresponding bits of two binary numbers.
class RippleCarryAdder extends Adder {
  @protected
  late final Logic _out;
  late final Logic _carry = Logic();

  /// Constructs an n-bit adder based on inputs List of inputs.
  RippleCarryAdder(super.a, super.b,
      {super.name = 'ripple_carry_adder', Logic? carry})
      : _out = Logic(width: a.width) {
    final sumList = <Logic>[];
    for (var i = 0; i < a.width; i++) {
      final fullAdder = FullAdder(a: a[i], b: b[i], carryIn: carry ?? Const(0));

      carry = fullAdder.carryOut;
      sumList.add(fullAdder.sum);
    }

    sumList.add(carry!);

    _out <= sumList.rswizzle().slice(_out.width - 1, 0);
    _carry <= sumList[sumList.rswizzle().width - 1];
  }

  @override
  @protected
  Logic calculateOut() => _out;

  @override
  @protected
  Logic calculateCarry() => _carry;

  @override
  @protected
  Logic calculateSum() => [_carry, _out].swizzle();
}
