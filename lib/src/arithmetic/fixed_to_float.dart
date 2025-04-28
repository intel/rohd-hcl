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

  /// Constructor for fixed to floating-point conversion.
  /// - [fixed] point number to convert.
  /// - [exponentWidth] desired exponent width of output.
  /// - [mantissaWidth] desired mantissa width of output.
  /// - [signed]=true default, treat input as signed.
  /// - [leadingDigitPredict] This input can optionally be provided which
  /// avoids having to do a full leading-digit scan for conversion. This
  /// provided value must be within 1 of the actual final leading one
  /// (after absolute value) of the input fixed-point number.
  /// A [LeadingDigitAnticipate] can be used to provide this value from two
  /// inputs to an adder producing the fixed-point value input to this
  /// converter.
  FixedToFloat(FixedPoint fixed,
      {required this.exponentWidth,
      required this.mantissaWidth,
      bool signed = true,
      Logic? leadingDigitPredict,
      super.name = 'FixedToFloat'})
      : super(
            definitionName:
                'Fixed${fixed.width}ToFloatE${exponentWidth}M$mantissaWidth') {
    fixed = fixed.clone()..gets(addInput('fixed', fixed, width: fixed.width));
    addOutput('float', width: _float.width) <= _float;

    leadingDigitPredict = (leadingDigitPredict != null)
        ? addInput('leadingDigitPredict', leadingDigitPredict,
            width: leadingDigitPredict.width)
        : null;

    final bias = float.floatingPointValue.bias;
    final eMax = pow(2, exponentWidth) - 2;
    final iWidth =
        (1 + max(log2Ceil(fixed.n), max(log2Ceil(fixed.width), exponentWidth)))
            .toInt();

    // Special handling needed for E4M3 as it does not support inf
    if ((exponentWidth == 4) && (mantissaWidth == 3)) {
      UnimplementedError('E4M3 is not supported.');
    }

    final Logic absValue;
    if (signed) {
      // Extract sign bit
      _float.sign <= (fixed.signed ? fixed[-1] : Const(0));

      absValue = Logic(name: 'absValue', width: fixed.width)
        ..gets(mux(_float.sign, ~(fixed - 1), fixed));
    } else {
      _float.sign <= Const(0);
      absValue = Logic(name: 'absValue', width: fixed.width)
        ..gets(mux(_float.sign, fixed, fixed));
    }

    final maxShift = fixed.width - fixed.n + bias - 2;

    final jBit = Logic(name: 'jBit', width: iWidth);
    Logic estimatedJBit;
    Logic absValueShifted;
    if (leadingDigitPredict != null) {
      // 3 positions are possible:  The leadingDigitPredict can be one
      // ahead of, matching or one behindthe actual jBit after absolute value.
      final fSign = fixed[-1].zeroExtend(leadingDigitPredict.width);

      // If the lead is 1 for a negative, start at leadingDigitPredict - 1
      estimatedJBit = mux(
          _float.sign.eq(fixed[-1]),
          mux(leadingDigitPredict.gte(fSign), leadingDigitPredict - fSign,
              leadingDigitPredict),
          Const(0, width: leadingDigitPredict.width));
      // Shift by current preJ to inspect leading bit
      if (absValue.width < mantissaWidth + 2) {
        absValueShifted = [
              absValue,
              Const(0, width: mantissaWidth + 2 - absValue.width)
            ].swizzle() <<
            estimatedJBit;
      } else {
        absValueShifted = absValue << estimatedJBit;
      }
      // Second Shift by one if leading digit is not '1'.
      estimatedJBit =
          mux(absValueShifted[-1], estimatedJBit, estimatedJBit + 1);
      absValueShifted =
          mux(absValueShifted[-1], absValueShifted, absValueShifted << 1);

      // Third and final shift by one if leading digit is not '1'.
      jBit <=
          mux(absValueShifted[-1], estimatedJBit, estimatedJBit + 1)
              .zeroExtend(iWidth);
      absValueShifted =
          mux(absValueShifted[-1], absValueShifted, absValueShifted << 1);
    } else {
      // No prediction given:  go find the leading digit
      final exactJBit = RecursiveModulePriorityEncoder(absValue.reversed)
          .out
          .zeroExtend(iWidth)
          .named('predictedjBit');
      // Limit to minimum exponent
      if (maxShift > 0) {
        jBit <=
            mux(exactJBit.gt(maxShift), Const(maxShift, width: iWidth),
                exactJBit);
      } else {
        jBit <= exactJBit;
      }
      // Align mantissa
      if (absValue.width < mantissaWidth + 2) {
        absValueShifted = [
              absValue,
              Const(0, width: mantissaWidth + 2 - absValue.width)
            ].swizzle() <<
            jBit;
      } else {
        absValueShifted = absValue << jBit;
      }
    }
    // TODO(desmonddak): refactor to use the roundRNE component

    // Extract mantissa
    final mantissa = Logic(name: 'mantissa', width: mantissaWidth);
    final guard = Logic(name: 'guardBit');
    final sticky = Logic(name: 'stickBit');
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
            (Const(bias + fixed.width - fixed.n - 1, width: iWidth) - jBit)
                .named('eShift'),
            Const(0, width: iWidth))
        .named('eRaw');

    // TODO(desmonddak): potential optimization --
    //  we may be able to predict this from absValue instead of after
    //  mantissa increment.
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
