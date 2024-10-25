// Copyright (C) 2023-2024 Intel Corporation
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

/// [FixedToFloatConverter] converts a fixed point input to
/// a floating point by rounding to nearest even.
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

    final indexWidth = max(fixed.n, max(log2Ceil(fixed.width), exponentWidth));

    // Extract sign bit
    if (fixed.signed) {
      _float.sign <= fixed[-1];
    } else {
      _float.sign <= Const(0);
    }

    final absValue = Logic(name: 'absValue', width: fixed.width)
      ..gets(mux(_float.sign, ~(fixed - 1), fixed));

    // Find jBit position
    final jBit = Logic(name: 'jBit', width: indexWidth);
    Combinational([
      CaseZ(absValue, conditionalType: ConditionalType.priority, [
        for (var i = 0; i < absValue.width; i++)
          CaseItem(_generateCaseItem(i, absValue.width), [
            jBit < Const(absValue.width - 1 - i, width: indexWidth),
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
        CaseItem(Const(0, width: indexWidth), [
          mantissa < 0,
          guard < 0,
          sticky < 0,
        ]),
        for (var i = 1; i < mantissaWidth + 2; i++)
          CaseItem(Const(i, width: indexWidth), [
            mantissa <
                [
                  absValue.slice(i - 1, max(0, i - mantissaWidth)),
                  Const(0, width: max(0, mantissaWidth - i))
                ].swizzle(),
            guard < 0,
            sticky < 0,
          ]),
        for (var i = mantissaWidth + 2; i < absValue.width; i++)
          CaseItem(Const(i, width: indexWidth), [
            mantissa <
                [
                  absValue.slice(i - 1, max(0, i - mantissaWidth)),
                  Const(0, width: max(0, mantissaWidth - i))
                ].swizzle(),
            guard < absValue[i - mantissaWidth - 1],
            sticky < absValue.slice(i - mantissaWidth - 2, 0).or(),
          ]),
      ], defaultItem: [
        mantissa < 0,
        guard < 0,
        sticky < 0,
      ]),
    ]);

    /// Round to nearest even: mantissa | guard sticky)
    final mantissaRounded =
        mux(guard & (sticky | mantissa[0]), mantissa + 1, mantissa);

    // Extract exponent
    final exponent = Logic(name: 'exponent', width: exponentWidth)
      ..gets((jBit + Const(bias - fixed.n, width: indexWidth))
          .slice(exponentWidth - 1, 0));
    final exponentRounded = mux(mantissaRounded.or(), exponent, exponent + 1);

    _float.exponent <= exponentRounded;
    _float.mantissa <= mantissaRounded;

    // TODO: what if RNE causes overflow in exponent?
    // TODO: handle subnormals
    // TODO: handle all zeros
    // TODO: handle infinities
  }
}
