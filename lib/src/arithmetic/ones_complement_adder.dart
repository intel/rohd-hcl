// Copyright (C) 2024-2026 Intel Corporation
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

  /// Configuration for static or runtime subtraction.
  @protected
  late final StaticOrRuntimeParameter subtractParameter;

  /// The deprecated runtime subtraction input, if configured.
  @protected
  @Deprecated('Use subtractParameter instead.')
  Logic? get subtractIn => subtractParameter.tryRuntimeInput(this);

  /// Generate an endAroundCarry signal instead of adding it to the
  /// [sum].
  final bool generateEndAroundCarry;

  /// [OnesComplementAdder] constructor with an adder functor [adderGen].
  /// - [subtract] configures subtraction statically with a `bool` or at runtime
  /// with a 1-bit [Logic]. It defaults to addition.
  /// - [subtractIn] is a deprecated runtime subtraction control. It may be
  ///   provided with an explicit `subtract: false` for compatibility.
  /// - If [generateEndAroundCarry] is `true`, then the end-around
  /// carry is not performed and is provided as output [endAroundCarry]. If
  ///   [generateEndAroundCarry] is `false`, extra hardware takes care of adding
  ///   the
  /// end-around carry to [sum].
  /// - [carryIn] allows for another adder to chain into this one.
  /// - [chainable] tells this adder to not store the [endAroundCarry] in the
  /// sign bit as well, but to zero that to allow adders to be chained such as
  /// for use in the [CarrySelectCompoundAdder].
  OnesComplementAdder(super.a, super.b,
      {Adder Function(Logic, Logic, {Logic? carryIn}) adderGen =
          NativeAdder.new,
      @Deprecated('Use subtract with a 1-bit Logic instead.') Logic? subtractIn,
      this.generateEndAroundCarry = false,
      super.carryIn,
      dynamic subtract,
      bool chainable = false,
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName,
      super.name = 'ones_complement_adder'})
      : super(
            definitionName:
                definitionName ?? 'OnesComplementAdder_W${a.width}') {
    if (generateEndAroundCarry) {
      addOutput('endAroundCarry');
    }
    final subtractIsActive =
        subtract != null && (subtract is! bool || subtract);
    if (subtractIn != null && subtractIsActive) {
      throw RohdHclException(
          "Provide either deprecated 'subtractIn' or 'subtract', "
          'but not both.');
    }
    subtractParameter = subtractIn != null
        ? StaticOrRuntimeParameter(
            name: 'subtractIn', runtimeConfig: subtractIn)
        : StaticOrRuntimeParameter.ofDynamic(subtract);
    _sign = addOutput('sign');

    final doSubtract = subtractParameter
        .getLogic(this)
        .named('dosubtract', naming: Naming.mergeable);

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
