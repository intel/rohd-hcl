// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// float_to_fixed.dart
// Transform floating point input signals to fixed point signals.
//
// 2024 November 1
// Author: Soner Yaldiz <soner.yaldiz@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// [FloatToFixed] converts a floating point input to a signed
/// fixed-point output following Q notation (Qm.n format) as introduced by
/// (Texas Instruments)[https://www.ti.com/lit/ug/spru565b/spru565b.pdf].
/// Infinities and NaN's are not supported. Conversion is lossless.
/// The output is in two's complement and in Qm.n format where:
/// m = e_max - bias + 1
/// n = mantissa + bias - 1
class FloatToFixed extends Module {
  /// Width of output integer part.
  late final int m;

  /// Width of output fractional part.
  late final int n;

  /// Internal representation of the output port
  late final FixedPoint _fixed = FixedPoint(signed: true, m: m, n: n);

  /// Output fixed point port
  late final FixedPoint fixed = _fixed.clone()..gets(output('fixed'));

  /// Constructor
  FloatToFixed(FloatingPoint float, {super.name = 'FloatToFixed'}) {
    float = float.clone()..gets(addInput('float', float, width: float.width));

    final bias = FloatingPointValue.computeBias(float.exponent.width);
    // E4M3 expands the max exponent by 1.
    m = ((float.exponent.width == 4) & (float.mantissa.width == 3))
        ? bias + 1
        : bias;
    n = bias + float.mantissa.width - 1;
    final outputWidth = m + n + 1;

    final jBit = Logic(name: 'jBit')..gets(float.isNormal());
    final shift = Logic(name: 'shift', width: float.exponent.width)
      ..gets(
          mux(jBit, float.exponent - 1, Const(0, width: float.exponent.width)));

    final number = Logic(name: 'number', width: outputWidth)
      ..gets([
            Const(0, width: outputWidth - float.mantissa.width - 1),
            jBit,
            float.mantissa
          ].swizzle() <<
          shift);

    _fixed <= mux(float.sign, ~number + 1, number);
    addOutput('fixed', width: outputWidth) <= _fixed;
  }
}
