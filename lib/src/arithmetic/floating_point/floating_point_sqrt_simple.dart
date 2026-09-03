// Copyright (C) 2025-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_sqrt.dart
// An abstract base class defining the API for floating-point square root.
//
// 2025 March 4
// Authors: James Farwell <james.c.farwell@intel.com>,
//          Stephen Weeks <stephen.weeks@intel.com>,
//          Curtis Anderson <curtis.anders@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A square root module for [FloatingPoint] logic signals.
class FloatingPointSqrtSimple<FpType extends FloatingPoint>
    extends FloatingPointSqrt<FpType> {
  /// Square root one floating point number [a], returning results
  /// [sqrt] and [error]
  FloatingPointSqrtSimple(super.a,
      {super.clk,
      super.reset,
      super.enable,
      super.roundingMode,
      super.name = 'floatingpoint_square_root_simple',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'FloatingPointSquareRootSimple_'
                    'E${a.exponent.width}M${a.mantissa.width}_'
                    'R${roundingMode.name}') {
    final outputSqrt = a.clone(name: 'sqrt') as FpType;
    output('sqrt') <= outputSqrt;
    late final error = output('error');

    // check to see if we do sqrt at all or just return a
    final isInf = a.isAnInfinity.named('isInf');
    final isNaN = a.isNaN.named('isNan');
    final isZero = a.isAZero.named('isZero');
    final rawSignificand =
        [a.isNormal, a.mantissa].swizzle().named('rawSignificand');
    final leadingOne = RecursiveModulePriorityEncoder(rawSignificand.reversed,
            generateValid: true, name: 'leading_one')
        .out
        .named('leadingOne');
    final normalizationShift =
        mux(a.isNormal, Const(0, width: leadingOne.width), leadingOne)
            .named('normalizationShift');
    final normalizedSignificand =
        (rawSignificand << normalizationShift).named('normalizedSignificand');

    final exponentCalcWidth = [exponentWidth + 2, normalizationShift.width + 2]
        .reduce((a, b) => a > b ? a : b);
    final bias = a.bias.zeroExtend(exponentCalcWidth);
    final effectiveExponent = mux(
            a.isNormal,
            a.exponent.zeroExtend(exponentCalcWidth),
            Const(1, width: exponentCalcWidth))
        .named('effectiveExponent');
    final deBiasExp = (effectiveExponent -
            bias -
            normalizationShift.zeroExtend(exponentCalcWidth))
        .named('deBiasExp');
    final shiftedExp = [deBiasExp[-1], deBiasExp.slice(deBiasExp.width - 1, 1)]
        .swizzle()
        .named('shiftedExp');
    final isExpOdd = deBiasExp[0];

    final extraPrecision = a.mantissa.width.isEven ? 5 : 4;
    final aFixed = FixedPoint(
        signed: false,
        integerWidth: 3,
        fractionWidth: a.mantissa.width + extraPrecision);
    aFixed <=
        [
          Const(0, width: 2),
          normalizedSignificand,
          Const(0, width: extraPrecision)
        ].swizzle().named('aFixed');

    final aFixedAdj = aFixed.clone(name: 'aFixedAdj')
      ..gets(mux(isExpOdd, [aFixed.slice(-2, 0), Const(0)].swizzle(), aFixed)
          .named('oddMantissaMux'));

    final fixedSqrt = FixedPointSqrt(aFixedAdj).sqrt;
    final retainedSignificand = fixedSqrt
        .getRange(extraPrecision, extraPrecision + a.mantissa.width + 1)
        .named('retainedSignificand');
    final adjustedSignificand = mux(
            isExpOdd,
            normalizedSignificand.zeroExtend(normalizedSignificand.width + 1) <<
                1,
            normalizedSignificand.zeroExtend(normalizedSignificand.width + 1))
        .named('adjustedSignificand');
    final comparisonWidth = 2 * (a.mantissa.width + 2);
    final exactScaled =
        (adjustedSignificand.zeroExtend(comparisonWidth) << a.mantissa.width)
            .named('exactScaled');
    final retainedForSquare = retainedSignificand.zeroExtend(comparisonWidth);
    final retainedSquared =
        (retainedForSquare * retainedForSquare).named('retainedSquared');
    final midpoint =
        ((retainedSignificand.zeroExtend(retainedSignificand.width + 1) << 1) |
                Const(1, width: retainedSignificand.width + 1))
            .named('midpoint');
    final midpointForSquare = midpoint.zeroExtend(comparisonWidth);
    final midpointSquared =
        (midpointForSquare * midpointForSquare).named('midpointSquared');
    final midpointScaled =
        (adjustedSignificand.zeroExtend(midpointSquared.width) <<
                (a.mantissa.width + 2))
            .named('midpointScaled');
    final inexact = exactScaled
        .neq(retainedSquared.zeroExtend(exactScaled.width))
        .named('inexact');
    final aboveMidpoint =
        midpointScaled.gt(midpointSquared).named('aboveMidpoint');
    final atMidpoint = midpointScaled.eq(midpointSquared).named('atMidpoint');
    final doRound = switch (roundingMode) {
      FloatingPointRoundingMode.truncate ||
      FloatingPointRoundingMode.roundTowardsZero ||
      FloatingPointRoundingMode.roundTowardsNegativeInfinity =>
        Const(0),
      FloatingPointRoundingMode.roundTowardsInfinity => inexact,
      FloatingPointRoundingMode.roundNearestTiesAway =>
        aboveMidpoint | atMidpoint,
      FloatingPointRoundingMode.roundNearestEven =>
        aboveMidpoint | (atMidpoint & retainedSignificand[0]),
    };
    final roundedSignificand =
        (retainedSignificand.zeroExtend(retainedSignificand.width + 1) +
                doRound.zeroExtend(retainedSignificand.width + 1))
            .named('roundedSignificand');
    final roundIncExp = roundedSignificand[-1].named('roundIncExp');
    final roundedMantissa = mux(roundIncExp, roundedSignificand.slice(-2, 1),
            roundedSignificand.slice(-3, 0))
        .named('roundedMantissa');
    final resultExponent =
        (shiftedExp + bias + roundIncExp.zeroExtend(exponentCalcWidth))
            .getRange(0, exponentWidth)
            .named('resultExponent');
    final invalidOperation = (a.isSignalingNaN | (a.sign & ~isZero & ~isNaN))
        .named('invalidOperation');
    internalStatus.invalid <= invalidOperation;
    internalStatus.divideByZero <= Const(0);
    internalStatus.overflow <= Const(0);
    internalStatus.underflow <= Const(0);
    internalStatus.inexact <= inexact & ~isInf & ~isNaN & ~a.sign;

    // final calculation results
    Combinational([
      error < Const(0),
      If.block([
        Iff(isInf & ~a.sign, [
          outputSqrt < outputSqrt.inf(),
        ]),
        ElseIf(isInf & a.sign, [
          outputSqrt < outputSqrt.nan,
          error < Const(1),
        ]),
        ElseIf(isNaN, [
          outputSqrt < outputSqrt.quietNaNFrom(a),
        ]),
        ElseIf(isZero, [
          outputSqrt.sign < a.sign,
          outputSqrt.exponent < a.exponent,
          outputSqrt.mantissa < a.mantissa,
        ]),
        ElseIf(a.sign, [
          outputSqrt < outputSqrt.nan,
          error < Const(1),
        ]),
        Else([
          outputSqrt.sign < a.sign,
          outputSqrt.exponent < resultExponent,
          outputSqrt.mantissa < roundedMantissa,
        ])
      ])
    ]);
  }
}
