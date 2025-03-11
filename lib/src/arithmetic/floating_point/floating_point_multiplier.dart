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
abstract class FloatingPointMultiplier<FpInType extends FloatingPoint>
    extends Module {
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
  late final FpInType a;

  /// The multiplier [b].
  @protected
  late final FpInType b;

  /// The computed [FloatingPoint] product of [a] * [b].
  late final FloatingPoint product =
      FloatingPoint(exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        ..gets(output('product'));

  /// The internal FloatingPoint logic to set
  late final FloatingPoint internalProduct;

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
  FloatingPointMultiplier(FpInType a, FpInType b,
      {Logic? clk,
      Logic? reset,
      Logic? enable,
      FloatingPoint? outProduct,
      // ignore: avoid_unused_constructor_parameters
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic)) ppGen =
          KoggeStone.new,
      super.name = 'floating_point_multiplier',
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

    internalProduct = FloatingPoint(
        exponentWidth: exponentWidth,
        mantissaWidth: mantissaWidth,
        name: 'product');
    addOutput('product', width: exponentWidth + mantissaWidth + 1);
    output('product') <= internalProduct;

    if (outProduct != null) {
      outProduct <= output('product');
    }

    this.clk = (clk != null) ? addInput('clk', clk) : clk;
    this.enable = (enable != null) ? addInput('enable', enable) : enable;
    this.reset = (reset != null) ? addInput('clk', reset) : reset;

    this.a = (a.clone(name: 'a') as FpInType)
      ..gets(addInput('a', a, width: a.width));
    this.b = (b.clone(name: 'b') as FpInType)
      ..gets(addInput('b', b, width: b.width));
  }

  /// Pipelining helper that uses the context for signals clk/enable/reset
  Logic localFlop(Logic input) =>
      condFlop(clk, input, en: enable, reset: reset);
}
