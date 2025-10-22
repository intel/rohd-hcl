// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// float_to_fixed.dart
// Transform floating point input signals to fixed point signals.
//
// 2024 November 1
// Author: Soner Yaldiz <soner.yaldiz@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// [FloatToFixed] converts a floating point input to a signed
/// fixed-point output following Q notation (Qm.n format) as introduced by
/// (Texas Instruments): (https://www.ti.com/lit/ug/spru565b/spru565b.pdf).
/// Infinities and NaN's are not supported. Conversion is lossless.
/// The output is in two's complement and in Qm.n format where:
/// ```dart
/// m = e_max - bias + 1
/// n = mantissa + bias - 1
/// ```
class FloatToFixed extends Module {
  /// Width of output integer part.
  late final int integerWidth;

  /// Width of output fractional part.
  late final int fractionWidth;

  /// Add overflow checking logic.
  final bool checkOverflow;

  /// Return `true` if the conversion overflowed.
  Logic? get overflow => tryOutput('overflow');

  /// Internal representation of the output port
  late final FixedPoint _fixed =
      FixedPoint(integerWidth: integerWidth, fractionWidth: fractionWidth);

  /// Output fixed point port (exposed as a typed output)
  late final FixedPoint fixed;

  /// Build a [FloatingPoint] to [FixedPoint] converter.
  /// - if [integerWidth] and [fractionWidth] are supplied, an m.n fixed-point
  ///   output will be produced. Otherwise, the converter will compute a
  ///   lossless size for [integerWidth] and [fractionWidth] for outputing the
  ///   floating-point value into a fixed-point value.
  /// - [checkOverflow] set to `true` will cause overflow detection to happen in
  ///   case that loss can occur and an optional output [overflow] will be
  ///   produced that returns `true` when overflow occurs.
  FloatToFixed(FloatingPoint float,
      {super.name = 'FloatToFixed',
      int? integerWidth,
      int? fractionWidth,
      this.checkOverflow = false,
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'FloatE${float.exponent.width}'
                    'M${float.mantissa.width}ToFixed') {
    float = float.clone()..gets(addTypedInput('float', float));

    final bias = float.floatingPointValue.bias;
    // E4M3 expands the max exponent by 1.
    final noLossM = ((float.exponent.width == 4) & (float.mantissa.width == 3))
        ? bias + 2
        : bias + 1; // accomodate the jbit
    final noLossN = bias + float.mantissa.width - 1;

    // TODO(desmonddak): Check what happens with an explicitJBit FP

    this.integerWidth = integerWidth ?? noLossM;
    this.fractionWidth = fractionWidth ?? noLossN;
    final outputWidth = this.integerWidth + this.fractionWidth + 1;

    final jBit = Logic(name: 'jBit')..gets(float.isNormal);
    final fullMantissa = [jBit, float.mantissa].swizzle().named('fullMantissa');

    final eWidth = max(log2Ceil(this.fractionWidth + this.integerWidth),
            float.exponent.width) +
        2;
    final shift = Logic(name: 'shift', width: eWidth);
    final exp = (float.exponent - 1).zeroExtend(eWidth).named('expMinus1');

    if (this.fractionWidth > noLossN) {
      shift <=
          mux(jBit, exp, Const(0, width: eWidth)) +
              Const(this.fractionWidth - noLossN, width: eWidth)
                  .named('deltaN');
    } else if (this.fractionWidth == noLossN) {
      shift <= mux(jBit, exp, Const(0, width: eWidth));
    } else {
      shift <=
          mux(jBit, exp, Const(0, width: eWidth)) -
              Const(noLossN - this.fractionWidth, width: eWidth)
                  .named('deltaN');
    }
    // TODO(desmonddak): Could use signed shifter if we unified shift math
    final shiftRight = ((fullMantissa.width > outputWidth)
            ? (~shift + 1) - (fullMantissa.width - outputWidth)
            : (~shift + 1))
        .named('shiftRight');

    if (checkOverflow &
        ((this.integerWidth < noLossM) | (this.fractionWidth < noLossN))) {
      final overflow = Logic(name: 'overflow');
      final leadDetect = RecursiveModulePriorityEncoder(fullMantissa.reversed,
          name: 'leadone_detector');

      final sWidth = max(eWidth, leadDetect.out.width);
      final fShift = shift.zeroExtend(sWidth).named('wideShift');
      final leadOne = leadDetect.out.zeroExtend(sWidth).named('leadOne');

      Combinational([
        If(jBit, then: [
          overflow < shift.gte(outputWidth - float.mantissa.width - 1),
        ], orElse: [
          If(fShift.gt(leadOne), then: [
            overflow <
                (fShift - leadOne).gte(outputWidth - float.mantissa.width - 1),
          ], orElse: [
            overflow < Const(0),
          ]),
        ]),
      ]);
      addOutput('overflow') <= overflow;
    }
    final preNumber = ((outputWidth >= fullMantissa.width)
            ? fullMantissa.zeroExtend(outputWidth)
            : fullMantissa.slice(-1, fullMantissa.width - outputWidth))
        .named('newMantissaPreShift');
    // TODO(desmonddak): Rounder is needed when shifting right

    final number = mux(shift[-1], preNumber >>> shiftRight, preNumber << shift)
        .named('number');

    _fixed <= mux(float.sign, ~number + 1, number).named('signedNumber');
    final typedFixedOut = addTypedOutput('fixed', _fixed.clone);
    typedFixedOut <= _fixed;
    fixed = typedFixedOut;
  }
}

/// [Float8ToFixed] converts an 8-bit floating point (FP8) input
/// to a signed fixed-point output following Q notation (Qm.n) as introduced by
/// (Texas Instruments): (https://www.ti.com/lit/ug/spru565b/spru565b.pdf).
/// FP8 input must follow E4M3 or E5M2 as described in
/// (FP8 formats for deep learning): (https://arxiv.org/pdf/2209.05433).
/// This component offers re-using the same hardware for both FP8 formats.
/// Infinities and NaN's are not supported.
/// The output is of type [Logic] and in two's complement.
/// It can be cast to a [FixedPoint] by the consumer based on the mode.
/// if `mode` is `true`:
///   Input is treated as E4M3 and converted to Q9.9
///   - `fixed[17:9]` contains integer part
///   - `fixed[8:0]` contains fractional part
/// else:
///    Input is treated as E5M2 and converted to Q16.16
///   - `fixed[31:16]` contains integer part
///   - `fixed[15:0]` contains fractional part
class Float8ToFixed extends Module {
  /// Output port [fixed]
  Logic get fixed => output('fixed');

  /// Getter for Q23.9
  FixedPoint get q23p9 =>
      FixedPoint.of(fixed, integerWidth: 23, fractionWidth: 9);

  /// Getter for Q16.16
  FixedPoint get q16p16 =>
      FixedPoint.of(fixed, integerWidth: 16, fractionWidth: 16);

  /// Constructor
  Float8ToFixed(Logic float, Logic mode, {super.name = 'Float8ToFixed'}) {
    float = addInput('float', float, width: float.width);
    mode = addInput('mode', mode);
    addOutput('fixed', width: 33);

    if (float.width != 8) {
      throw RohdHclException('Input width must be 8.');
    }

    final exponent = Logic(name: 'exponent', width: 5)
      ..gets(mux(
          mode, [Const(0), float.slice(6, 3)].swizzle(), float.slice(6, 2)));

    final jBit = Logic(name: 'jBit')..gets(exponent.or());

    final mantissa = Logic(name: 'mantissa', width: 4)
      ..gets(mux(mode, [jBit, float.slice(2, 0)].swizzle(),
          [Const(0), jBit, float.slice(1, 0)].swizzle()));

    final shift = Logic(name: 'shift', width: exponent.width)
      ..gets(mux(jBit, exponent - 1, Const(0, width: exponent.width)));

    final number = Logic(name: 'number', width: 33)
      ..gets([Const(0, width: 29), mantissa].swizzle() << shift);

    fixed <= mux(float[float.width - 1], ~number + 1, number);
  }
}
