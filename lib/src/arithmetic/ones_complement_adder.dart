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
  /// If the input [generateEndAroundCarry] is `true`, this value is stored as
  /// the output [endAroundCarry].
  /// Otherwise, the end-around carry is internally added to [sum]. This
  /// happens when subtracting a smaller number from a larger one using
  /// ones complement arithmetic.
  Logic? get endAroundCarry => tryOutput('endAroundCarry');

  @protected
  Logic _sign = Logic();

  /// Subtraction is happening
  @protected
  late final StaticOrDynamicParameter subtractIn;

  /// Generate an endAroundCarry signal instead of adding it to the
  /// [sum].
  final bool generateEndAroundCarry;

  /// [OnesComplementAdder] constructor with an adder functor [adderGen].
  /// - A subtractor is created if [subtract] is set to true.  Alternatively,
  /// if [subtract] configuration is false, and a Lgic control signal
  /// [subtractIn] is provided, then subtraction can be dynamically selected.
  /// Otherwise an adder is constructed.
  ///
  /// - The optional [subtract] parameter configures the adder to subtract [b]
  ///   from [a] statically using a bool to indicate a ssubtraction (default is
  ///   false, or addition) or dynamically with a 1-bit [Logic] input. Passing
  ///   something other null, bool, or [Logic] will result in a throw.
  /// - If [generateEndAroundCarry] is true, then the end-around carry is not
  ///   performed and is provided as output [endAroundCarry]. If
  ///   [generateEndAroundCarry] is false, extra hardware takes care of adding
  ///   the end-around carry to [sum].
  /// - [carryIn] allows for another adder to chain into this one.
  /// - [chainable] tells this adder to not store the [endAroundCarry] in the
  ///   sign bit as well, but to zero that to allow adders to be chained such as
  ///   for use in the [CarrySelectCompoundAdder].
  OnesComplementAdder(super.a, super.b,
      {Adder Function(Logic, Logic, {Logic? carryIn}) adderGen =
          NativeAdder.new,
      this.generateEndAroundCarry = false,
      super.carryIn,
      dynamic subtract,
      bool chainable = false,
      String? definitionName,
      super.name = 'ones_complement_adder'})
      : super(
            definitionName:
                definitionName ?? 'OnesComplementAdder_W${a.width}') {
    if (generateEndAroundCarry) {
      addOutput('endAroundCarry');
    }
    subtractIn = StaticOrDynamicParameter.ofDynamic(subtract).clone(this);
    _sign = addOutput('sign');

    final doSubtract = subtractIn.getLogic(this);

    final adderSum =
        adderGen(a, mux(doSubtract, ~b, b), carryIn: carryIn ?? Const(0))
            .sum
            .named('adderSum', naming: Naming.mergeable);

    if (generateEndAroundCarry) {
      endAroundCarry! <= adderSum[-1];
    }
    final endAround = adderSum[-1].named('endaround');
    final magnitude = adderSum.slice(a.width - 1, 0).named('magnitude');
    final Logic magnitudep1;
    if (!generateEndAroundCarry) {
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
                  [if (generateEndAroundCarry) magnitude else magnitudep1]
                      .first,
                  ~magnitude)
            ].swizzle(),
            adderSum);
    _sign <= mux(doSubtract, ~endAround, Const(0));
  }
}
