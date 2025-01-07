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

  /// The [clk]:  if a valid clock signal is passed in, a pipestage is added to
  /// the adder to help optimize frequency.
  Logic? clk;

  /// Optional [reset], used only if a [clk] is not null to reset the pipeline
  /// flops.
  Logic? reset;

  /// Optional [enable], used only if a [clk] is not null to enable the pipeline
  /// flops.
  Logic? enable;

  /// The multiplicand [ia].
  @protected
  late final FloatingPoint ia;

  /// The multiplier [ib].
  @protected
  late final FloatingPoint ib;

  /// getter for the computed [FloatingPoint] output.
  late final FloatingPoint product =
      FloatingPoint(exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        ..gets(output('product'));

  /// Add two floating point numbers [a] and [b], returning result in [product].
  /// - [clk], [reset], [enable] are optional inputs to control a pipestage
  /// (only inserted if [clk] is provided).
  /// = [ppGen] is the type of [ParallelPrefix] used in internal adder
  /// generation.
  FloatingPointMultiplier(FloatingPoint a, FloatingPoint b,
      {this.clk,
      this.reset,
      this.enable,
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
      clk = addInput('clk', clk!);
    }
    if (reset != null) {
      reset = addInput('reset', reset!);
    }
    if (enable != null) {
      enable = addInput('enable', enable!);
    }
    ia = a.clone()..gets(addInput('a', a, width: a.width));
    ib = b.clone()..gets(addInput('b', b, width: b.width));
    // output 'product' must be constructed in the sub-class
  }
}
