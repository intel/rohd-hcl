// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_adder.dart
// An abstract base class defining the API for floating-point adders.
//
// 2025 January 3
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An abstract API for floating point adders.
abstract class FloatingPointAdder extends Module {
  /// Width of the output exponent field.
  final int exponentWidth;

  /// Width of the output mantissa field.
  final int mantissaWidth;

  /// The [clk] : if a non-null clock signal is passed in, a pipestage is added
  /// to the adder to help optimize frequency.
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

  /// The first addend [a], named this way to allow for a local variable 'a'.
  @protected
  late final FloatingPoint a;

  /// The second addend [b], named this way to allow for a local variable 'b'.
  @protected
  late final FloatingPoint b;

  /// getter for the computed [FloatingPoint] output.
  late final FloatingPoint sum =
      FloatingPoint(exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        ..gets(output('sum'));

  /// Add two floating point numbers [a] and [b], returning result in [sum].
  /// - [clk], [reset], [enable] are optional inputs to control a pipestage
  /// (only inserted if [clk] is provided).
  FloatingPointAdder(FloatingPoint a, FloatingPoint b,
      {Logic? clk,
      Logic? reset,
      Logic? enable,
      super.name = 'floating_point_adder'})
      : exponentWidth = a.exponent.width,
        mantissaWidth = a.mantissa.width,
        super() {
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
    addOutput('sum', width: exponentWidth + mantissaWidth + 1);
  }

  /// Swapping two FloatingPoint structures based on a conditional
  @protected
  (FloatingPoint, FloatingPoint) swap(
          Logic swap, (FloatingPoint, FloatingPoint) toSwap) =>
      (
        toSwap.$1.clone()..gets(mux(swap, toSwap.$2, toSwap.$1)),
        toSwap.$2.clone()..gets(mux(swap, toSwap.$1, toSwap.$2))
      );

  /// Pipelining helper that uses the context for signals clk/enable/reset
  Logic localFlop(Logic input) =>
      condFlop(clk, input, en: enable, reset: reset);
}
