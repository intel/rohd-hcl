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

/// Compares two's-complement signed [a] against a compile-time constant
/// [threshold] (which may itself be negative), returning whether `a >=
/// threshold`. [Logic.gte] alone is unsigned and gives incorrect results
/// whenever either operand is negative.
Logic _signedGteConst(Logic a, int threshold) {
  final thresholdBits = Const(threshold, width: a.width);
  // A same-width two's-complement bit pattern comparison via unsigned
  // [Logic.gte] gives the correct signed result whenever both operands share
  // the same sign; the only remaining cases are when [a]'s sign differs from
  // [threshold]'s known (compile-time) sign, which can be resolved directly.
  return threshold >= 0
      ? mux(a[-1], Const(0), a.gte(thresholdBits))
      : mux(a[-1], a.gte(thresholdBits), Const(1));
}

/// As [_signedGteConst], but strictly greater than (`a > threshold`).
Logic _signedGtConst(Logic a, int threshold) {
  final thresholdBits = Const(threshold, width: a.width);
  return threshold >= 0
      ? mux(a[-1], Const(0), a.gt(thresholdBits))
      : mux(a[-1], a.gt(thresholdBits), Const(1));
}

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
  /// - [roundingMode] selects how a fraction narrower than the incoming
  ///   mantissa is rounded. Defaults to [FloatingPointRoundingMode.truncate],
  ///   matching prior (rounding-free) behavior.
  FloatToFixed(FloatingPoint float,
      {super.name = 'FloatToFixed',
      int? integerWidth,
      int? fractionWidth,
      this.checkOverflow = false,
      FloatingPointRoundingMode roundingMode =
          FloatingPointRoundingMode.truncate,
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'FloatE${float.exponent.width}'
                    'M${float.mantissa.width}ToFixed') {
    float = addTypedInput('float', float);

    final bias = float.floatingPointValue.bias;

    // [float.mantissa] includes the explicit j-bit as its top bit when
    // [FloatingPoint.explicitJBit] is set; separate it out here so the rest
    // of this component can work uniformly with just the fraction bits and
    // its own independently-computed [jBit], matching the implicit-j-bit
    // convention used throughout.
    final fractionBitsWidth =
        float.mantissa.width - (float.explicitJBit ? 1 : 0);
    final mantissaFractionBits = float.explicitJBit
        ? float.mantissa.slice(fractionBitsWidth - 1, 0)
        : float.mantissa;

    // E4M3 expands the max exponent by 1.
    final noLossM = ((float.exponent.width == 4) & (fractionBitsWidth == 3))
        ? bias + 2
        : bias + 1; // accomodate the jbit
    final noLossN = bias + fractionBitsWidth - 1;

    this.integerWidth = integerWidth ?? noLossM;
    this.fractionWidth = fractionWidth ?? noLossN;
    final outputWidth = this.integerWidth + this.fractionWidth + 1;

    final jBit = Logic(name: 'jBit')..gets(float.isNormal);
    final fullMantissa =
        [jBit, mantissaFractionBits].swizzle().named('fullMantissa');

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
    // Note: this cannot simply be replaced with the reusable [SignedShifter]
    // (`mux(shift[-1], preNumber >>> shift.abs(), preNumber << shift)`),
    // because [preNumber] below is only the top `outputWidth` bits of
    // [fullMantissa] whenever [fullMantissa] is wider than the output
    // (dropping its low `fullMantissa.width - outputWidth` bits before any
    // shifting happens, as a hardware-cost optimization so the shifter only
    // needs to be `outputWidth` bits wide instead of
    // `fullMantissa.width` bits wide). That pre-truncation is itself
    // equivalent to an implicit right-shift-and-discard of
    // `fullMantissa.width - outputWidth` positions, so the *remaining*
    // right-shift actually needed on [preNumber] is the true magnitude
    // shift minus that already-applied amount -- double-counting it (as a
    // naive [SignedShifter] swap would) was verified empirically to corrupt
    // results (e.g. silently shifting a correct 0.25 result down to 0.0) in
    // exactly the scenario this adjustment exists for, which had no
    // existing regression test until one was added alongside this comment.
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

      // At the exact overflow threshold, a negative value that rounds down
      // to an exact power of two still fits, since two's-complement negative
      // range extends one step further than positive range (e.g. -4 fits in
      // a signed format whose maximum positive value is only 3.5). Since
      // truncation always discards the low `discardedBits` bits regardless
      // of their value, whether the result is an exact power of two depends
      // only on the *retained* higher bits being all zero; the number of
      // discarded bits is a compile-time constant at this exact threshold.
      final threshold = outputWidth - fractionBitsWidth - 1;
      final discardedBits = (-threshold).clamp(0, fractionBitsWidth);
      final atThresholdIsExactPowerOfTwo = discardedBits < fractionBitsWidth
          ? ~mantissaFractionBits
              .getRange(discardedBits, fractionBitsWidth)
              .or()
          : Const(1);

      Combinational([
        If(jBit, then: [
          overflow <
              (_signedGtConst(shift, threshold) |
                  (shift.eq(Const(threshold, width: shift.width)) &
                      ~(float.sign & atThresholdIsExactPowerOfTwo))),
        ], orElse: [
          If(fShift.gt(leadOne), then: [
            overflow < _signedGteConst(fShift - leadOne, threshold),
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

    final unroundedNumber =
        mux(shift[-1], preNumber >>> shiftRight, preNumber << shift)
            .named('unroundedNumber');

    // Rounding support for the right-shift (fraction-truncating) path: a
    // left shift never discards bits, so only the right-shifted magnitude
    // can lose precision. A single extra zero bit is appended below
    // [fullMantissa] so that shifting the buffered value reveals the guard
    // bit that [preNumber] alone would otherwise silently discard; any bits
    // shifted below that position (including a shift wide enough to empty
    // the buffer entirely) are captured as sticky via a complementary left
    // shift of the pre-shift buffered value.
    final bufferedFullMantissa =
        [fullMantissa, Const(0)].swizzle().named('bufferedFullMantissa');
    final bufferedOutputWidth = outputWidth + 1;
    final bufferedPreNumber =
        ((bufferedOutputWidth >= bufferedFullMantissa.width)
                ? bufferedFullMantissa.zeroExtend(bufferedOutputWidth)
                : bufferedFullMantissa.slice(
                    -1, bufferedFullMantissa.width - bufferedOutputWidth))
            .named('bufferedPreNumber');
    final guard =
        (bufferedPreNumber >>> shiftRight)[0].named('rightShiftGuard');
    final safeShiftRight = mux(shiftRight.gte(bufferedPreNumber.width),
            Const(bufferedPreNumber.width, width: shiftRight.width), shiftRight)
        .named('safeShiftRight');
    final sticky = (bufferedPreNumber <<
            (Const(bufferedPreNumber.width, width: safeShiftRight.width) -
                safeShiftRight))
        .or()
        .named('rightShiftSticky');
    final rounder = FloatingPointRounder.fromGRS(
        retainedLsb: unroundedNumber[0],
        guard: guard,
        sticky: sticky,
        roundingMode: roundingMode,
        sign: float.sign);

    final number = (unroundedNumber +
            (shift[-1] & rounder.doRound).zeroExtend(unroundedNumber.width))
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
