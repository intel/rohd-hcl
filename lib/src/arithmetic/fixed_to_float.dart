// Copyright (C) 2024-2025 Intel Corporation
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

/// [FixedToFloat] converts a fixed point input to floating point with
/// rouding to nearest even. If the input exceeds the floating point range,
/// the output will be infinity. E4M3 is not supported as this format doesn't
/// support infinity.
class FixedToFloat extends Module {
  /// Width of exponent, must be greater than 0.
  final int exponentWidth;

  /// Width of mantissa, must be greater than 0.
  final int mantissaWidth;

  /// Internal representation of the output port.
  late final FloatingPoint _float =
      FloatingPoint(exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// Output port [float]
  late final FloatingPoint float = _float.clone()..gets(output('float'));

  /// Constructor
  FixedToFloat(FixedPoint fixed,
      {required this.exponentWidth,
      required this.mantissaWidth,
      super.name = 'FixedToFloat'})
      : super(
            definitionName:
                'Fixed${fixed.width}ToFloatE${exponentWidth}M$mantissaWidth') {
    fixed = fixed.clone()..gets(addInput('fixed', fixed, width: fixed.width));
    addOutput('float', width: _float.width) <= _float;

    final bias = float.floatingPointValue.bias;
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

    final jBit = ParallelPrefixPriorityEncoder(absValue.reversed)
        .out
        .zeroExtend(iWidth)
        .named('jBit');

    // TODO(desmonddak): refactor to use the roundRNE component

    // Extract mantissa
    final mantissa = Logic(name: 'mantissa', width: mantissaWidth);
    final guard = Logic(name: 'guardBit');
    final sticky = Logic(name: 'stickBit');
    final j = Logic(name: 'j', width: iWidth);
    final maxShift = fixed.width - fixed.n + bias - 2;

    // Limit to minimum exponent
    if (maxShift > 0) {
      j <= mux(jBit.gt(maxShift), Const(maxShift, width: iWidth), jBit);
    } else {
      j <= jBit;
    }

    // Align mantissa
    final absValueShifted = Logic(
        width: max(absValue.width, mantissaWidth + 2), name: 'absValueShifted');
    if (absValue.width < mantissaWidth + 2) {
      final zeros = Const(0, width: mantissaWidth + 2 - absValue.width);
      absValueShifted <= [absValue, zeros].swizzle() << j;
    } else {
      absValueShifted <= absValue << j;
    }

    mantissa <= absValueShifted.getRange(-mantissaWidth - 1, -1);
    guard <= absValueShifted.getRange(-mantissaWidth - 2, -mantissaWidth - 1);
    sticky <= absValueShifted.getRange(0, -mantissaWidth - 2).or();

    /// Round to nearest even: mantissa | guard sticky
    final roundUp = (guard & (sticky | mantissa[0])).named('roundUp');
    final mantissaRounded =
        mux(roundUp, mantissa + 1, mantissa).named('roundedMantissa');

    // Calculate biased exponent
    final eRaw = mux(
            absValueShifted[-1],
            (Const(bias + fixed.width - fixed.n - 1, width: iWidth) - j)
                .named('eShift'),
            Const(0, width: iWidth))
        .named('eRaw');
    final eRawRne =
        mux(roundUp & ~mantissaRounded.or(), eRaw + 1, eRaw).named('eRawRNE');

    // Select output handling corner cases
    final expoLessThanOne =
        (eRawRne[-1] | ~eRawRne.or()).named('expLessThanOne');
    final expoMoreThanMax =
        (~eRawRne[-1] & (eRawRne.gt(eMax))).named('expMoreThanMax');
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
          _float.exponent < eRawRne.slice(exponentWidth - 1, 0),
          _float.mantissa < mantissaRounded
        ])
      ])
    ]);
  }
}
