// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// adder.dart
// Implementation of Adder Module.
//
// 2023 June 1
// Author: Yao Jing Quek <yao.jing.quek@intel.com>
//

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An abstract class for all adder module.
abstract class Adder extends Module {
  /// The input to the adder pin [a].
  @protected
  late final Logic a;

  /// The input to the adder pin [b].
  @protected
  late final Logic b;

  /// The addition results [sum].
  Logic get sum => output('sum');

  /// Takes in input [a] and input [b] and return the [sum] of the addition
  /// result. The width of input [a] and [b] must be the same.
  Adder(Logic a, Logic b, {super.name}) {
    if (a.width != b.width) {
      throw RohdHclException('inputs of a and b should have same width.');
    }
    this.a = addInput('a', a, width: a.width);
    this.b = addInput('b', b, width: b.width);
    addOutput('sum', width: a.width + 1);
  }
}

/// A simple full-adder with inputs `a` and `b` to be added with a `carryIn`.
class FullAdder extends Module {
  /// The addition's result [sum].
  Logic get sum => output('sum');

  /// The carry bit's result [carryOut].
  Logic get carryOut => output('carry_out');

  /// Constructs a [FullAdder] with value [a], [b] and [carryIn] based on
  /// full adder truth table.
  FullAdder({
    required Logic a,
    required Logic b,
    required Logic carryIn,
    super.name = 'full_adder',
  }) {
    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);
    carryIn = addInput('carry_in', carryIn, width: carryIn.width);

    final carryOut = addOutput('carry_out');
    final sum = addOutput('sum');

    final and1 = carryIn & (a ^ b);
    final and2 = b & a;

    sum <= (a ^ b) ^ carryIn;
    carryOut <= and1 | and2;
  }
}
