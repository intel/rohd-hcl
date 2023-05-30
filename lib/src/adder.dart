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

/// An abstract class for all adder module.
abstract class Adder extends Module {
  /// The List of inputs to sum. Length of inputs must be two.
  List<Logic> toSum;

  /// The addition results [sum].
  List<Logic> get sum;

  /// Takes in list of inputs Logic [toSum] and return the [sum] of the addition
  /// result [sum].
  Adder({required this.toSum, super.name});
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
