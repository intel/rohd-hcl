// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_to_float.dart
// Transform fixed point signals to floating point signals.
//
// 2024 October 24
// Author: Soner Yaldiz <soner.yaldiz@intel.com>

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// [FixedToFloatConverter] converts a fixed point input to floating point.
/// Normals are rounded to nearest even. Subnormals are truncated.
class FixedToFloatConverter extends Module {
  /// Width of exponent, must be greater than 0.
  final int exponentWidth;

  /// Width of mantissa, must be greater than 0.
  final int mantissaWidth;

  /// Output port [float]
  late final FloatingPoint float =
      FloatingPoint(exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        ..gets(output('float'));

  /// Internal representation of the output port
  late final FloatingPoint _float =
      FloatingPoint(exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// Constructor
  FixedToFloatConverter(FixedPoint fixed,
      {required this.exponentWidth,
      required this.mantissaWidth,
      super.name = 'FixedToFloatConverter'}) {
    fixed = fixed.clone()..gets(addInput('fixed', fixed, width: fixed.width));
    addOutput('float', width: _float.width) <= _float;

    final bias = FloatingPointValue.computeBias(exponentWidth);
    final eMax = pow(2, exponentWidth) - 2;
    final iWidth =
        (2 + max(fixed.n, max(log2Ceil(fixed.width), exponentWidth))).toInt();

    // Special handling needed for E4M3 as it does not support inf
    if ((exponentWidth == 4) && (mantissaWidth == 3)) {
      UnimplementedError('E4M3 is not supported.');
    }

    // Extract sign bit
    if (fixed.signed) {
      _float.sign <= fixed[-1];
    } else {
      _float.sign <= Const(0);
    }

    final absValue = Logic(name: 'absValue', width: fixed.width)
      ..gets(mux(_float.sign, ~(fixed - 1), fixed));

    final jBit = Const(absValue.width-1, width: iWidth) -
        ParallelPrefixPriorityEncoder(absValue.reversed).out.zeroExtend(iWidth);

    // Extract mantissa
    final mantissa = Logic(name: 'mantissa', width: mantissaWidth);
    final guard = Logic(name: 'guardBit');
    final sticky = Logic(name: 'stickBit');
    final j = Logic(name: 'j', width: iWidth);
    final minIndex = max(0, fixed.n - bias + 1);

    if (minIndex > 0) {
      j <= mux(jBit.lt(minIndex), Const(minIndex, width: iWidth), jBit);
    } else {
      j <= jBit;
    }

    Combinational([
      Case(j, conditionalType: ConditionalType.unique, [
        CaseItem(Const(0, width: iWidth), [
          mantissa < 0,
          guard < 0,
          sticky < 0,
        ]),
        for (var i = 1; i <= mantissaWidth; i++)
          CaseItem(Const(i, width: iWidth), [
            mantissa <
                [
                  absValue.slice(i - 1, 0),
                  Const(0, width: max(0, mantissaWidth - i))
                ].swizzle(),
            guard < 0,
            sticky < 0,
          ]),
        CaseItem(Const(mantissaWidth + 1, width: iWidth), [
          mantissa < absValue.slice(mantissaWidth, 1),
          guard < absValue[0],
          sticky < 0,
        ]),
        for (var i = mantissaWidth + 2; i < absValue.width; i++)
          CaseItem(Const(i, width: iWidth), [
            mantissa < absValue.slice(i - 1, max(0, i - mantissaWidth)),
            guard < absValue[i - mantissaWidth - 1],
            sticky < absValue.slice(i - mantissaWidth - 2, 0).or(),
          ]),
      ], defaultItem: [
        mantissa < 0,
        guard < 0,
        sticky < 0,
      ]),
    ]);

    /// Round to nearest even: mantissa | guard sticky
    final roundUp = guard & (sticky | mantissa[0]);
    final mantissaRounded = mux(roundUp, mantissa + 1, mantissa);

    // Extract exponent
    final expoRaw =
        jBit + Const(bias, width: iWidth) - Const(fixed.n, width: iWidth);
    final expoRawRne =
        mux(roundUp & ~mantissaRounded.or(), expoRaw + 1, expoRaw);

    // Select output with corner cases
    final expoLessThanOne = expoRawRne[-1] | ~expoRawRne.or();
    final expoMoreThanMax = ~expoRawRne[-1] & (expoRawRne.gt(eMax));
    Combinational([
      If.block([
        Iff(~absValue.or(), [
          // Zero
          _float.exponent < Const(0, width: exponentWidth),
          _float.mantissa < Const(0, width: mantissaWidth),
        ]),
        ElseIf(expoMoreThanMax, [
          // Infinity
          _float.exponent < LogicValue.filled(exponentWidth, LogicValue.one),
          _float.mantissa < Const(0, width: mantissaWidth),
        ]),
        ElseIf(expoLessThanOne, [
          // Subnormal
          _float.exponent < Const(0, width: exponentWidth),
          _float.mantissa < mantissaRounded
        ]),
        Else([
          // Normal
          _float.exponent < expoRawRne.slice(exponentWidth - 1, 0),
          _float.mantissa < mantissaRounded
        ])
      ])
    ]);
  }
}
