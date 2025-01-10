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
abstract class FloatingPointMultiplier extends Module {
  /// Width of the output exponent field.
  final int exponentWidth;

  /// Width of the output mantissa field.
  final int mantissaWidth;

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
  late final FloatingPoint a;

  /// The multiplier [b].
  @protected
  late final FloatingPoint b;

  /// The computed [FloatingPoint] product of [a] * [b].
  late final FloatingPoint product =
      FloatingPoint(exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        ..gets(output('product'));

  /// Multiply two floating point numbers [a] and [b], returning result in
  /// [product].
  ///
  /// - [clk], [reset], [enable] are optional inputs to control a pipestage
  /// (only inserted if [clk] is provided).
  /// - [ppGen] is the type of [ParallelPrefix] used in internal adder
  /// generation.
  FloatingPointMultiplier(FloatingPoint a, FloatingPoint b,
      {Logic? clk,
      Logic? reset,
      Logic? enable,
      // ignore: avoid_unused_constructor_parameters
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic)) ppGen =
          KoggeStone.new,
      super.name = 'floating_point_multiplier'})
      : exponentWidth = a.exponent.width,
        mantissaWidth = a.mantissa.width {
    if (b.exponent.width != exponentWidth ||
        b.mantissa.width != mantissaWidth) {
      throw RohdHclException('FloatingPoint widths must match');
    }
    if (clk != null) {
      this.clk = addInput('clk', clk);
    } else {
      this.clk = clk;
    }
    if (reset != null) {
      this.reset = addInput('reset', reset);
    } else {
      this.reset = reset;
    }
    if (enable != null) {
      this.enable = addInput('enable', enable);
    } else {
      this.enable = enable;
    }
    this.a = a.clone()..gets(addInput('a', a, width: a.width));
    this.b = b.clone()..gets(addInput('b', b, width: b.width));
    addOutput('product', width: a.exponent.width + a.mantissa.width + 1);
  }

  /// Pipelining helper that uses the context for signals clk/enable/reset
  Logic localFlop(Logic input) =>
      condFlop(clk, input, en: enable, reset: reset);
}
