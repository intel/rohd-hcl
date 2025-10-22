// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_multiplier_simple.dart
// Implementation of non-rounding floating-point multiplier
//
// 2025 January 3
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An abstract API for floating-point multipliers.
abstract class FloatingPointMultiplier<FpTypeIn extends FloatingPoint,
    FpTypeOut extends FloatingPoint> extends Module {
  /// Width of the output exponent field.
  late final int exponentWidth;

  /// Width of the output mantissa field.
  late final int mantissaWidth;

  /// The [clk] : if a non-null clock signal is passed in, a pipestage is added
  ///  to the adder to help optimize frequency.
  @protected
  late final Logic? clk;

  /// Optional [reset], used only if a [clk] is not null to reset the pipeline
  /// flops.
  @protected
  late final Logic? reset;

  /// Optional [enable], used only if a [clk] is not null to enable the pipeline
  /// flops.
  @protected
  late final Logic? enable;

  /// The multiplicand [a].
  @protected
  late final FpTypeIn a;

  /// The multiplier [b].
  @protected
  late final FpTypeIn b;

  /// The computed [FpTypeOut] product of [a] * [b].
  late final FpTypeOut product;

  /// The rounding mode to use for the multiplier.
  late final FloatingPointRoundingMode roundingMode;

  /// The internal [FloatingPoint] logic in which to store the product of the
  /// multiplication.
  @protected
  late final FpTypeOut internalProduct;

  /// Multiply two floating point numbers [a] and [b], returning result in
  /// [product].
  ///
  /// If you specify the optional  [outProduct], the multiplier
  /// will output into the specified output allowing for a wider output.
  ///
  /// - [clk], [reset], [enable] are optional inputs to control a pipestage
  /// (only inserted if [clk] is provided).
  /// - [ppGen] is the type of [ParallelPrefix] used in internal adder
  /// generation.
  FloatingPointMultiplier(FpTypeIn a, FpTypeIn b,
      {Logic? clk,
      Logic? reset,
      Logic? enable,
      FpTypeOut? outProduct,
      this.roundingMode = FloatingPointRoundingMode.roundNearestEven,
      // ignore: avoid_unused_constructor_parameters
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic)) ppGen =
          KoggeStone.new,
      super.name = 'floating_point_multiplier',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'FloatingPointMultiplier_E${a.exponent.width}'
                    'M${a.mantissa.width}') {
    if (b.exponent.width != a.exponent.width ||
        b.mantissa.width != a.mantissa.width) {
      throw RohdHclException('FloatingPoint widths must match');
    }
    exponentWidth =
        (outProduct == null) ? a.exponent.width : outProduct.exponent.width;
    mantissaWidth =
        (outProduct == null) ? a.mantissa.width : outProduct.mantissa.width;

    internalProduct = (outProduct ?? a).clone(name: 'outSum') as FpTypeOut;

    // expose typed output and drive it from internalProduct
    product = addTypedOutput(
        'product', internalProduct.clone as FpTypeOut Function({String? name}));
    product <= internalProduct;

    if (outProduct != null) {
      outProduct <= product;
    }

    this.clk = (clk != null) ? addInput('clk', clk) : clk;
    this.enable = (enable != null) ? addInput('enable', enable) : enable;
    this.reset = (reset != null) ? addInput('reset', reset) : reset;

    this.a = (a.clone(name: 'a') as FpTypeIn)..gets(addTypedInput('a', a));
    this.b = (b.clone(name: 'b') as FpTypeIn)..gets(addTypedInput('b', b));
  }

  /// Pipelining helper that uses the context for signals clk/enable/reset
  Logic localFlop(Logic input) =>
      condFlop(clk, input, en: enable, reset: reset);
}
