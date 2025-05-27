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

// TODO(desmonddak): add variable width output as we did with fpmultiply
//  consider: this would mean we can't (easily?) use a parameter like FpType for
//  the output, since we aren't guaranteed to have something to `clone` from.

/// An abstract API for floating point adders.
abstract class FloatingPointAdder<FpType extends FloatingPoint> extends Module {
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
  late final FpType a;

  /// The second addend [b], named this way to allow for a local variable 'b'.
  @protected
  late final FpType b;

  /// getter for the computed [FloatingPoint] output.
  late final FloatingPoint sum = a.clone(name: 'sum')..gets(output('sum'));

  /// Add two floating point numbers [a] and [b], returning result in [sum].
  /// - [clk], [reset], [enable] are optional inputs to control a pipestage
  /// (only inserted if [clk] is provided).
  FloatingPointAdder(FpType a, FpType b,
      {Logic? clk,
      Logic? reset,
      Logic? enable,
      super.name = 'floating_point_adder',
      String? definitionName})
      : exponentWidth = a.exponent.width,
        mantissaWidth = a.mantissa.width,
        super(
            definitionName: definitionName ??
                'FloatingPointAdder_E${a.exponent.width}'
                    'M${a.mantissa.width}') {
    if (b.exponent.width != exponentWidth ||
        b.mantissa.width != mantissaWidth) {
      throw RohdHclException('FloatingPoint widths must match');
    }
    this.clk = (clk != null) ? addInput('clk', clk) : null;
    this.reset = (reset != null) ? addInput('reset', reset) : null;
    this.enable = (enable != null) ? addInput('enable', enable) : null;
    this.a = (a.clone(name: 'a', explicitJBit: a.explicitJBit) as FpType)
      ..gets(addInput('a', a, width: a.width));
    this.b = (b.clone(name: 'b', explicitJBit: b.explicitJBit) as FpType)
      ..gets(addInput('b', b, width: b.width));

    addOutput('sum', width: exponentWidth + mantissaWidth + 1);
  }

  /// Pipelining helper that uses the context for signals clk/enable/reset
  Logic localFlop(Logic input) =>
      condFlop(clk, input, en: enable, reset: reset);
}
