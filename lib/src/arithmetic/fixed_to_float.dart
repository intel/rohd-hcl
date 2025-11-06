// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_to_float.dart
// Transform fixed point signals to floating point signals.
//
// 2024 October 24
// Author: Soner Yaldiz <soner.yaldiz@intel.com>

import 'dart:math';
import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// [FixedToFloat] converts a fixed point input to floating point with
/// rouding to nearest even. If the input exceeds the floating point range,
/// the output will be infinity. E4M3 is not supported as this format doesn't
/// support infinity.
class FixedToFloat extends Module {
  /// Output port [float]
  // Expose typed FloatingPoint output via addTypedOutput and wire internal
  // converted float into it. This avoids relying on plain output('float').
  late final FloatingPoint float;

  /// Internal representation of the output port.
  @protected
  late final FloatingPoint outFloat;

  /// The internal [FloatingPoint] logic to set
  late final FloatingPoint _convertedFloat;

  /// Constructor for fixed to floating-point conversion. This component takes
  /// a [fixed] point input number to convert, producing a floating-point output
  /// [float].  The number can be specified as [signed] (`true` by default). The
  /// [leadingDigitPredict] pposition can optionally be provided which avoids
  /// having to do a full leading-digit scan for conversion. This provided value
  /// must be within 1 of the actual final leading one (after absolute value) of
  /// the input fixed-point number. A [LeadingDigitAnticipate] module can be
  /// used to provide this value from two inputs to an adder producing the
  /// fixed-point value input to this converter.
  FixedToFloat(FixedPoint fixed, this.outFloat,
      {bool signed = true,
      Logic? leadingDigitPredict,
      super.name = 'FixedToFloat',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'Fixed${fixed.width}ToFloat_E${outFloat.exponent.width}'
                    'M${outFloat.mantissa.width}') {
    fixed = addTypedInput('fixed', fixed);

    final fixedAsLogic = fixed.packed;
    final exponentWidth = outFloat.exponent.width;
    final mantissaWidth = outFloat.mantissa.width;
    _convertedFloat = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    // Create a typed output and drive it from the internal converted float.
    final typedFloatOut = addTypedOutput('float', _convertedFloat.clone);
    typedFloatOut <= _convertedFloat;
    // Also set the public `float` handle to the typed output instance so
    // consumers that expect a FloatingPoint object can use `float` directly.
    float = typedFloatOut;

    leadingDigitPredict = (leadingDigitPredict != null)
        ? addInput('leadingDigitPredict', leadingDigitPredict,
            width: leadingDigitPredict.width)
        : null;

    final bias = float.floatingPointValue.bias;
    final eMax = pow(2, float.exponent.width) - 2;
    final iWidth = (1 +
            max(log2Ceil(fixed.fractionWidth),
                max(log2Ceil(fixed.width), float.exponent.width)))
        .toInt();

    // Special handling needed for E4M3 as it does not support inf
    if ((exponentWidth == 4) && (mantissaWidth == 3)) {
      UnimplementedError('E4M3 is not supported.');
    }

    final Logic absValue;
    if (signed) {
      // Extract sign bit
      _convertedFloat.sign <= (fixed.signed ? fixedAsLogic[-1] : Const(0));

      absValue = Logic(name: 'absValue', width: fixed.width)
        ..gets(mux(_convertedFloat.sign, ~(fixedAsLogic - 1), fixedAsLogic));
    } else {
      _convertedFloat.sign <= Const(0);
      absValue = fixedAsLogic;
    }

    final maxShift = fixed.width - fixed.fractionWidth + bias - 2;

    final jBit = Logic(name: 'jBit', width: iWidth);
    Logic estimatedJBit;
    Logic absValueShifted;
    if (leadingDigitPredict != null) {
      // 3 positions are possible:  The leadingDigitPredict can be one
      // ahead of, matching or one behindthe actual jBit after absolute value.
      final fSign = fixedAsLogic[-1]
          .zeroExtend(leadingDigitPredict.width)
          .named('fixedSign');

      // If the lead is 1 for a negative, start at leadingDigitPredict - 1
      estimatedJBit = mux(
              _convertedFloat.sign.eq(fixedAsLogic[-1]),
              mux(leadingDigitPredict.gte(fSign), leadingDigitPredict - fSign,
                  leadingDigitPredict),
              Const(0, width: leadingDigitPredict.width))
          .named('estimatedJBit');
      // Shift by current preJ to inspect leading bit
      if (absValue.width < float.mantissa.width + 2) {
        absValueShifted = ([
                  absValue,
                  Const(0, width: float.mantissa.width + 2 - absValue.width)
                ].swizzle() <<
                estimatedJBit)
            .named('absValueShifted');
      } else {
        absValueShifted = (absValue << estimatedJBit).named('absValueShifted');
      }
      // Second Shift by one if leading digit is not '1'.
      estimatedJBit = mux(absValueShifted[-1], estimatedJBit, estimatedJBit + 1)
          .named('estimatedJBit2');
      absValueShifted =
          mux(absValueShifted[-1], absValueShifted, absValueShifted << 1)
              .named('absValueShifted');

      // Third and final shift by one if leading digit is not '1'.
      jBit <=
          mux(absValueShifted[-1], estimatedJBit, estimatedJBit + 1)
              .zeroExtend(iWidth);
      absValueShifted =
          mux(absValueShifted[-1], absValueShifted, absValueShifted << 1)
              .named('absValueShifted');
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
      if (absValue.width < float.mantissa.width + 2) {
        absValueShifted = ([
                  absValue,
                  Const(0, width: float.mantissa.width + 2 - absValue.width)
                ].swizzle() <<
                jBit)
            .named('absValueShifted');
      } else {
        absValueShifted = (absValue << jBit).named('absValueShiftedJ');
      }
    }
    // TODO(desmonddak): refactor to use the roundRNE component.  Also:
    // https://github.com/intel/rohd-hcl/issues/191

    // Extract mantissa
    final mantissa = Logic(name: 'mantissa', width: float.mantissa.width);
    final guard = Logic(name: 'guardBit');
    final sticky = Logic(name: 'stickyBit');
    mantissa <= absValueShifted.getRange(-float.mantissa.width - 1, -1);
    guard <=
        absValueShifted.getRange(
            -float.mantissa.width - 2, -float.mantissa.width - 1);
    sticky <= absValueShifted.getRange(0, -float.mantissa.width - 2).or();

    /// Round to nearest even: mantissa | guard sticky
    final roundUp = (guard & (sticky | mantissa[0])).named('roundUp');
    final mantissaRounded =
        mux(roundUp, mantissa + 1, mantissa).named('roundedMantissa');

    // Calculate biased exponent
    final eRaw = mux(
            absValueShifted[-1],
            Const(bias + fixed.width - fixed.fractionWidth - 1, width: iWidth) -
                jBit,
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
          _convertedFloat.exponent < Const(0, width: exponentWidth),
          _convertedFloat.mantissa < Const(0, width: float.mantissa.width),
        ]),
        ElseIf(expoMoreThanMax, [
          // Infinity
          _convertedFloat.exponent <
              LogicValue.filled(exponentWidth, LogicValue.one),
          _convertedFloat.mantissa < Const(0, width: float.mantissa.width),
        ]),
        ElseIf(expoLessThanOne, [
          // Subnormal
          _convertedFloat.exponent < Const(0, width: exponentWidth),
          _convertedFloat.mantissa < mantissaRounded
        ]),
        Else([
          // Normal
          _convertedFloat.exponent < eRawRne.slice(exponentWidth - 1, 0),
          _convertedFloat.mantissa < mantissaRounded
        ])
      ])
    ]);
  }
}
