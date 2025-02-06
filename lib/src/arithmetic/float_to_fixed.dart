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

  /// Return true if the conversion overflowed.
  Logic? get overflow => tryOutput('overflow');

  /// Internal representation of the output port
  late final FixedPoint _fixed = FixedPoint(signed: true, m: m, n: n);

  /// Output fixed point port
  late final FixedPoint fixed = _fixed.clone()..gets(output('fixed'));

  /// Build a [FloatingPoint] to [FixedPoint] converter.
  /// - if [m] and [n] are supplied, an m.n fixed-point output will be produced.
  /// Otherwise, the converter will compute a lossless size for [m] and [n] for
  /// outputing the floating-point value into a fixed-point value.
  /// - [checkOverflow] set to true will cause overflow detection to happen in
  /// case that loss can occur and an optional output [overflow] will be
  ///  produced that returns true when overflow occurs.
  FloatToFixed(FloatingPoint float,
      {super.name = 'FloatToFixed', int? m, int? n, bool checkOverflow = false})
      : super(
            definitionName: 'FloatE${float.exponent.width}'
                'M${float.mantissa.width}ToFixed') {
    float = float.clone()..gets(addInput('float', float, width: float.width));

    final bias = FloatingPointValue.computeBias(float.exponent.width);
    // E4M3 expands the max exponent by 1.
    final noLossM = ((float.exponent.width == 4) & (float.mantissa.width == 3))
        ? bias + 2
        : bias + 1; // accomodate the jbit
    final noLossN = bias + float.mantissa.width - 1;

    this.m = m ?? noLossM;
    this.n = n ?? noLossN;
    final outputWidth = this.m + this.n + 1;

    final jBit = Logic(name: 'jBit')..gets(float.isNormal);
    final fullMantissa = [jBit, float.mantissa].swizzle().named('fullMantissa');
    print('fullMantissa: ${fullMantissa.value.bitString}');

    final eWidth = max(log2Ceil(this.n + this.m), float.exponent.width) + 1;
    final shift = Logic(name: 'shift', width: eWidth);
    final exp = (float.exponent - 1).zeroExtend(eWidth);

    if (this.n > noLossN) {
      shift <=
          mux(jBit, exp, Const(0, width: eWidth)) +
              Const(this.n - noLossN, width: eWidth);
    } else if (this.n == noLossN) {
      shift <= mux(jBit, exp, Const(0, width: eWidth));
    } else {
      shift <=
          mux(jBit, exp, Const(0, width: eWidth)) -
              Const(noLossN - this.n, width: eWidth);
    }

    print('shift=${shift.value.toInt()}');

    if (checkOverflow & ((this.m < noLossM) | (this.n < noLossN))) {
      final overFlow = Logic(name: 'overflow');
      final leadDetect = ParallelPrefixPriorityEncoder(fullMantissa.reversed);

      final sWidth = max(eWidth, leadDetect.out.width);
      final fShift = shift.zeroExtend(sWidth);
      final leadOne = leadDetect.out.zeroExtend(sWidth);

      Combinational([
        If(jBit, then: [
          overFlow < shift.gte(outputWidth - float.mantissa.width - 1),
        ], orElse: [
          If(fShift.gt(leadOne), then: [
            overFlow <
                (fShift - leadOne).gte(outputWidth - float.mantissa.width - 1),
          ], orElse: [
            overFlow < Const(0),
          ]),
        ]),
      ]);
      addOutput('overflow') <= overFlow;
    }
    final preNumber = (outputWidth >= fullMantissa.width)
        ? fullMantissa.zeroExtend(outputWidth)
        : fullMantissa.slice(-1, fullMantissa.width - outputWidth);
    // TODO(desmonddak): Rounder is needed when shift is negative,
    // LSB(fullMantissa) = shiftRight
    final shiftRight = ((fullMantissa.width > outputWidth)
        ? (~shift + 1) - (fullMantissa.width - outputWidth)
        : (~shift + 1));

    final number = mux(shift[-1], preNumber >>> shiftRight, preNumber << shift);

    _fixed <= mux(float.sign, ~number + 1, number);
    addOutput('fixed', width: outputWidth) <= _fixed;
  }
}

/// [Float8ToFixed] converts an 8-bit floating point (FP8) input
/// to a signed fixed-point output following Q notation (Qm.n) as introduced by
/// (Texas Instruments)[https://www.ti.com/lit/ug/spru565b/spru565b.pdf].
/// FP8 input must follow E4M3 or E5M2 as described in
/// (FP8 formats for deep learning)[https://arxiv.org/pdf/2209.05433].
/// This component offers re-using the same hardware for both FP8 formats.
/// Infinities and NaN's are not supported.
/// The output is of type [Logic] and in two's complement.
/// It can be cast to a [FixedPoint] by the consumer based on the mode.
/// if `mode` is true:
///   Input is treated as E4M3 and converted to Q9.9
///   `fixed[17:9] contains integer part
///   `fixed[8:0] contains fractional part
/// else:
///    Input is treated as E5M2 and converted to Q16.16
///   `fixed[31:16] contains integer part
///   `fixed[15:0] contains fractional part
class Float8ToFixed extends Module {
  /// Output port [fixed]
  Logic get fixed => output('fixed');

  /// Getter for Q23.9
  FixedPoint get q23p9 => FixedPoint.of(fixed, signed: true, m: 23, n: 9);

  /// Getter for Q16.16
  FixedPoint get q16p16 => FixedPoint.of(fixed, signed: true, m: 16, n: 16);

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
