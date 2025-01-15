// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ones_complement_adder.dart
// Implementation of a One's Complement Adder
//
// 2024 August 31
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An adder (and subtractor) [OnesComplementAdder] that operates on
/// ones-complement values.
class OnesComplementAdder extends Adder {
  /// The sign of the result
  Logic get sign => output('sign');

  /// The end-around carry which should be added to the resulting [sum]
  /// If the input [carryOut] is not null, this value is stored there.
  ///  Otherwise, the end-around carry is internally added to [sum]
  Logic? get carryOut => tryOutput('carryOut');

  @protected
  Logic _sign = Logic();

  /// [OnesComplementAdder] constructor with an adder functor [adderGen].
  /// - Either an optional Logic [subtractIn] or a boolean [subtract] can enable
  /// subtraction, but providing both non-null will result in an exception.
  /// - If Logic [carryOut] is provided as not null, then the end-around carry
  ///  is not performed and is provided as value on [carryOut].
  /// - [carryIn] allows for another adder to chain into this one.
  OnesComplementAdder(super.a, super.b,
      {Adder Function(Logic, Logic, {Logic? carryIn}) adderGen =
          ParallelPrefixAdder.new,
      Logic? subtractIn,
      Logic? carryOut,
      Logic? carryIn,
      bool? subtract,
      super.name = 'ones_complement_adder'}) {
    if (subtractIn != null) {
      subtractIn = addInput('subtractIn', subtractIn);
    }
    _sign = addOutput('sign');
    if (carryOut != null) {
      addOutput('carryOut');
      carryOut <= this.carryOut!;
    }
    if ((subtractIn != null) & (subtract != null)) {
      throw RohdHclException(
          "either provide a Logic signal 'subtractIn' for runtime "
          " configuration, or a boolean parameter 'subtract' for "
          'generation time configuration, but not both.');
    }
    final doSubtract = nameLogic('dosubtract',
        subtractIn ?? (subtract != null ? Const(subtract) : Const(0)));

    final adder =
        adderGen(a, mux(doSubtract, ~b, b), carryIn: carryIn ?? Const(0));

    if (this.carryOut != null) {
      this.carryOut! <= adder.sum[-1];
    }
    final endAround = nameLogic('endaround', adder.sum[-1]);
    final magnitude = nameLogic('magnitude', adder.sum.slice(a.width - 1, 0));

    final incrementer = ParallelPrefixIncr(magnitude);
    final magnitudep1 = nameLogic('magnitude_p1', incrementer.out);

    sum <=
        mux(
            doSubtract,
            mux(
                    endAround,
                    [if (this.carryOut != null) magnitude else magnitudep1]
                        .first,
                    ~magnitude)
                .zeroExtend(sum.width),
            adder.sum);
    _sign <= mux(doSubtract, ~endAround, Const(0));
  }
}
