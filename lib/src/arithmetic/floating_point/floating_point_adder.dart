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
abstract class FloatingPointAdder<FpTypeIn extends FloatingPoint,
    FpTypeOut extends FloatingPoint> extends Module {
  /// Width of the output exponent field.
  late final int exponentWidth;

  /// Width of the output mantissa field.
  late final int mantissaWidth;

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
  late final FpTypeIn a;

  /// The second addend [b], named this way to allow for a local variable 'b'.
  @protected
  late final FpTypeIn b;

  /// getter for the computed [FpTypeOut] output.
  late final FpTypeOut sum = (internalSum.clone(name: 'int_sum') as FpTypeOut)
    ..gets(output('sum'));

  /// The conditional output FloatingPoint Logic to set
  @protected
  late final FpTypeOut internalSum;

  /// The rounding mode to use for the adder.
  final FloatingPointRoundingMode roundingMode;

  /// Add two floating point numbers [a] and [b], returning result in [sum].
  /// If a different output type is needed, you can provide that in [outSum].
  /// - [clk], [reset], [enable] are optional inputs to control a pipestage
  /// (only inserted if [clk] is provided).
  FloatingPointAdder(FpTypeIn a, FpTypeIn b,
      {Logic? clk,
      Logic? reset,
      Logic? enable,
      FpTypeOut? outSum,
      this.roundingMode = FloatingPointRoundingMode.roundNearestEven,
      super.name = 'floating_point_adder',
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'FloatingPointAdder_E${a.exponent.width}'
                    'M${a.mantissa.width}') {
    if (b.exponent.width != a.exponent.width ||
        b.mantissa.width != a.mantissa.width) {
      throw RohdHclException('FloatingPoint input widths must match');
    }
    this.clk = (clk != null) ? addInput('clk', clk) : null;
    this.reset = (reset != null) ? addInput('reset', reset) : null;
    this.enable = (enable != null) ? addInput('enable', enable) : null;
    this.a = (a.clone(name: 'a') as FpTypeIn)
      ..gets(addInput('a', a, width: a.width));
    this.b = (b.clone(name: 'b') as FpTypeIn)
      ..gets(addInput('b', b, width: b.width));

    internalSum =
        (outSum ?? (a.explicitJBit ? b : a)).clone(name: 'outSum') as FpTypeOut;

    exponentWidth = (outSum == null) ? a.exponent.width : outSum.exponent.width;
    mantissaWidth = (outSum == null) ? a.mantissa.width : outSum.mantissa.width;

    addOutput('sum', width: internalSum.width);

    if (outSum != null) {
      outSum <= output('sum');
    }
    output('sum') <= internalSum;
  }

  /// Pipelining helper that uses the context for signals clk/enable/reset
  Logic localFlop(Logic input) =>
      condFlop(clk, input, en: enable, reset: reset);
}
