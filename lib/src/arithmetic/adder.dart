// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// adder.dart
// Implementation of Adder Module.
//
// 2023 June 1
// Author: Yao Jing Quek <yao.jing.quek@intel.com>,
// Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An abstract class for adders..
abstract class Adder extends Module {
  /// The input to the adder pin [a].
  @protected
  Logic get a => input('a');

  /// The input to the adder pin [b].
  @protected
  Logic get b => input('b');

  /// The addition results in 2s complement form as [sum]
  Logic get sum => output('sum');

  /// The input to the carry in pin [carryIn]
  @protected
  Logic? get carryIn => tryInput('carryIn');

  /// Check if this adder has a carryIn input
  bool get hasCarryIn => carryIn != null;

  /// Takes in input [a] and input [b] and return the [sum] of the addition
  /// result. The width of input [a] and [b] must be the same.
  Adder(Logic a, Logic b,
      {Logic? carryIn,
      super.name = 'adder',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(definitionName: definitionName ?? 'Adder_W${a.width}') {
    if (a.width != b.width) {
      throw RohdHclException('inputs of a and b should have same width.');
    }
    addInput('a', a, width: a.width);
    addInput('b', b, width: b.width);
    addOutput('sum', width: a.width + 1);
    if (carryIn != null) {
      addInput('carryIn', carryIn);
    }
  }
}

/// A simple full-adder with single-bit inputs `a` and `b` to be added
/// with a `carryIn`.
class FullAdder extends Adder {
  /// Constructs a [FullAdder] with value [a], [b] and [carryIn] based on
  /// full adder truth table.
  FullAdder(super.a, super.b,
      {required super.carryIn,
      super.name = 'full_adder',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(definitionName: definitionName ?? 'FullAdder_W${a.width}') {
    if ((a.width != 1) | (b.width != 1) | ((carryIn ?? Const(0)).width != 1)) {
      throw RohdHclException('widths must all be one');
    }
    if (carryIn == null) {
      throw RohdHclException('FullAdder must have a carryIn input');
    }
    sum <= [carryIn! & (a ^ b) | a & b, (a ^ b) ^ carryIn!].swizzle();
  }
}

/// A class which wraps the native '+' operator so that it can be passed
/// into other modules as a parameter for using the native operation.
/// Note that [NativeAdder] is unsigned.
class NativeAdder extends Adder {
  /// The width of input [a] and [b] must be the same.
  NativeAdder(super.a, super.b,
      {super.carryIn,
      super.name = 'native_adder',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(definitionName: definitionName ?? 'NativeAdder_W${a.width}') {
    if (a.width != b.width) {
      throw RohdHclException('inputs of a and b should have same width.');
    }
    final aExtended =
        a.zeroExtend(a.width + 1).named('aExtended', naming: Naming.mergeable);
    final bExtended =
        b.zeroExtend(a.width + 1).named('bExtended', naming: Naming.mergeable);

    final aPlusb = (aExtended + bExtended)
        .named('aExtended_plus_bExtended', naming: Naming.mergeable);
    if (carryIn == null) {
      sum <= aPlusb;
    } else {
      final cinExtendend = carryIn!
          .zeroExtend(a.width + 1)
          .named('carryInExtended', naming: Naming.mergeable);
      sum <=
          (aPlusb + cinExtendend)
              .named('sumWithCarryIn', naming: Naming.mergeable);
    }
  }
}
