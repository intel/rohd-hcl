// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// compound_adder.dart
// Implementation of Compund Integer Adder Module 
// (Output Sum and Sum1 which is Sum + 1). 
//
// 2023 June 1
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An abstract class for all compound adder module.
abstract class CompoundAdder extends Module {
  /// The input to the adder pin [a].
  @protected
  Logic get a => input('a');

  /// The input to the adder pin [b].
  @protected
  Logic get b => input('b');

  /// The addition results in 2s complement form as [sum]
  Logic get sum => output('sum');

  /// The addition results (+1) in 2s complement form as [sum1]
  Logic get sum1 => output('sum1');

  /// Takes in input [a] and input [b] and return the [sum] of the addition
  /// result and [sum1] sum + 1. 
  /// The width of input [a] and [b] must be the same.
  CompoundAdder(Logic a, Logic b, {super.name}) {
    if (a.width != b.width) {
      throw RohdHclException('inputs of a and b should have same width.');
    }
    addInput('a', a, width: a.width);
    addInput('b', b, width: b.width);
    addOutput('sum', width: a.width + 1);
    addOutput('sum1', width: a.width + 1);
  }
}

/// A trivial compound adder.
class MockCompoundAdder extends CompoundAdder {

  /// Constructs a [CompoundAdder].
  MockCompoundAdder(
    super.a,
    super.b,
    {super.name = 'mock_compound_adder'}
  ) {
    sum <= a.zeroExtend(a.width + 1) + b.zeroExtend(b.width + 1);
    sum1 <= sum + 1;
  }
}
