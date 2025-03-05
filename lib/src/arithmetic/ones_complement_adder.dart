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
/// ones-complement values, producing a magnitude and sign.
class OnesComplementAdder extends Adder {
  /// The sign of the result
  Logic get sign => output('sign');

  /// The end-around carry which should be added to the resulting [sum].
  /// If the input [endAroundCarry] is not null, this value is stored there.
  /// Otherwise, the end-around carry is internally added to [sum]. This
  /// happens when subtracting a smaller number from a larger oneusing
  /// ones complement arithmetic.
  Logic? get endAroundCarry => tryOutput('endAroundCarry');

  @protected
  Logic _sign = Logic();

  /// Subtraction is happening
  @protected
  late final Logic? subtractIn;

  /// [OnesComplementAdder] constructor with an adder functor [adderGen].
  /// - Either an optional Logic [subtractIn] or a boolean [subtract] can enable
  /// subtraction, but providing both non-null will result in an exception.
  /// - If Logic [endAroundCarry] is provided as not null, then the end-around
  /// carry is not performed and is provided as value on [endAroundCarry]. If
  /// [endAroundCarry] is null, extra hardware takes care of adding the
  /// end-around carry to [sum].
  /// - [carryIn] allows for another adder to chain into this one.
  /// - [chainable] tells this adder to not store the [endAroundCarry] in the
  /// sign bit as well, but to zero that to allow adders to be chained such as
  /// for use in the [CarrySelectCompoundAdder].
  OnesComplementAdder(super.a, super.b,
      {Adder Function(Logic, Logic, {Logic? carryIn}) adderGen =
          ParallelPrefixAdder.new,
      Logic? subtractIn,
      Logic? endAroundCarry,
      super.carryIn,
      bool subtract = false,
      bool chainable = false,
      String? definitionName,
      super.name = 'ones_complement_adder'})
      : super(
            definitionName:
                definitionName ?? 'OnesComplementAdder_W${a.width}') {
    if (endAroundCarry != null) {
      addOutput('endAroundCarry');
      endAroundCarry <= this.endAroundCarry!;
    }
    if ((subtractIn != null) & subtract) {
      throw RohdHclException(
          "either provide a Logic signal 'subtractIn' for runtime "
          " configuration, or a boolean parameter 'subtract' for "
          'generation time configuration, but not both.');
    }
    this.subtractIn =
        (subtractIn != null) ? addInput('subtractIn', subtractIn) : null;
    _sign = addOutput('sign');

    final doSubtract =
        (this.subtractIn ?? (subtract ? Const(subtract) : Const(0)))
            .named('dosubtract', naming: Naming.mergeable);

    final adderSum =
        adderGen(a, mux(doSubtract, ~b, b), carryIn: carryIn ?? Const(0))
            .sum
            .named('adderSum', naming: Naming.mergeable);

    if (this.endAroundCarry != null) {
      this.endAroundCarry! <= adderSum[-1];
    }
    final endAround = adderSum[-1].named('endaround');
    final magnitude = adderSum.slice(a.width - 1, 0).named('magnitude');
    final Logic magnitudep1;
    if (this.endAroundCarry == null) {
      final incrementer = ParallelPrefixIncr(magnitude);
      magnitudep1 = incrementer.out.named('magnitude_plus1');
    } else {
      magnitudep1 = Const(0);
    }
    sum <=
        mux(
            doSubtract,
            [
              if (chainable) endAround else Const(0),
              mux(
                  [if (chainable) Const(0) else endAround].first,
                  [if (this.endAroundCarry != null) magnitude else magnitudep1]
                      .first,
                  ~magnitude)
            ].swizzle(),
            adderSum);
    _sign <= mux(doSubtract, ~endAround, Const(0));
  }
}
