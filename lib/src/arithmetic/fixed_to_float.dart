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

  /// Helper method for finding jBit
  Logic _generateCaseItem(int i, int width) {
    final items = <Logic>[];
    if (i > 0) {
      items.add(Const(LogicValue.filled(i, LogicValue.zero)));
    }
    items.add(Const(LogicValue.one));
    if (i < width - 1) {
      items.add(Const(LogicValue.filled(width - i - 1, LogicValue.z)));
    }
    return items.swizzle();
  }

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

    // Find jBit position. TODO: Re-use ParallelPrefixPriorityEncoder()?
    final jBit = Logic(name: 'jBit', width: iWidth);
    Combinational([
      CaseZ(absValue, conditionalType: ConditionalType.priority, [
        for (var i = 0; i < absValue.width; i++)
          CaseItem(_generateCaseItem(i, absValue.width), [
            jBit < Const(absValue.width - 1 - i, width: iWidth),
          ])
      ], defaultItem: [
        jBit < 0,
      ]),
    ]);

    // Extract mantissa
    final mantissa = Logic(name: 'mantissa', width: mantissaWidth);
    final guard = Logic(name: 'guardBit');
    final sticky = Logic(name: 'stickBit');
    Combinational([
      Case(jBit, conditionalType: ConditionalType.unique, [
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

    // For subnormal, prefix mantissa 0.000 1 mantissa
    final padAmount = Const(1, width: iWidth) - expoRawRne;
    final mantissaSub = Logic(name: 'mantissaSub', width: mantissaWidth);
    Combinational([
      Case(padAmount, conditionalType: ConditionalType.unique, [
        for (var i = 1; i < mantissaWidth; i++)
          CaseItem(
            Const(i, width: iWidth),
            [
              mantissaSub <
                  [
                    Const(0, width: i - 1),
                    Const(1),
                    mantissaRounded.slice(mantissaWidth - 1, i)
                  ].swizzle()
            ],
          ),
        CaseItem(Const(mantissaWidth, width: iWidth),
            [mantissaSub < Const(1).zeroExtend(mantissaWidth)]),
      ], defaultItem: [
        mantissaSub < Const(0, width: mantissaWidth)
      ])
    ]);

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
          _float.mantissa < mantissaSub
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
