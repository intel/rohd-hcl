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

  late final FloatingPoint sum = FloatingPoint(
      exponentWidth: exponentWidth, mantissaWidth: mantissaWidth, name: 'sum')
    ..gets(output('sum'));

  /// Add two floating point numbers [a] and [b], returning result in [sum].
  /// - [clk], [reset], [enable] are optional inputs to control a pipestage
  /// (only inserted if [clk] is provided).
  FloatingPointAdder(FloatingPoint a, FloatingPoint b,
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
    this.a = a.clone(name: 'a')..gets(addInput('a', a, width: a.width));
    this.b = b.clone(name: 'b')..gets(addInput('b', b, width: b.width));

    addOutput('sum', width: exponentWidth + mantissaWidth + 1);
  }

  /// Swapping two FloatingPoint structures based on a conditional
  @protected
  (FloatingPoint, FloatingPoint) swap(
      Logic swap, (FloatingPoint, FloatingPoint) toSwap) {
    final in1 = toSwap.$1.named('swapIn_${toSwap.$1.name}');
    final in2 = toSwap.$2.named('swapIn_${toSwap.$2.name}');

    final out1 = mux(swap, in2, in1).named('swapOut_larger');
    final out2 = mux(swap, in1, in2).named('swapOut_smaller');
    final first = a.clone(name: 'larger')..gets(out1);
    final second = a.clone(name: 'smaller')..gets(out2);
    return (first, second);
  }

  /// Sort two FloatingPointNumbers and swap
  @protected
  (FloatingPoint larger, FloatingPoint smaller) sortFp(
      (FloatingPoint, FloatingPoint) toSort) {
    final ae = toSort.$1.exponent;
    final be = toSort.$2.exponent;
    final am = toSort.$1.mantissa;
    final bm = toSort.$2.mantissa;
    final doSwap = (ae.lt(be) |
            (ae.eq(be) & am.lt(bm)) |
            ((ae.eq(be) & am.eq(bm)) & toSort.$1.sign))
        .named('doSwap');

    final swapped = swap(doSwap, toSort);

    final larger = swapped.$1.clone(name: 'larger')..gets(swapped.$1);
    final smaller = swapped.$2.clone(name: 'smaller')..gets(swapped.$2);

    return (larger, smaller);
  }

  /// Pipelining helper that uses the context for signals clk/enable/reset
  Logic localFlop(Logic input) =>
      condFlop(clk, input, en: enable, reset: reset);
}
