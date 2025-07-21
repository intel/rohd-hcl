// Copyright (C) 2025 Intel Corporation
// SPDX-License-Indentifier: BSD-3-Clause
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
      super.name = 'floatingpoint_square_root_simple'})
      : super(
            definitionName: 'FloatingPointSquareRootSimple_'
                'E${a.exponent.width}M${a.mantissa.width}') {
    final outputSqrt = FloatingPoint(
        exponentWidth: exponentWidth,
        mantissaWidth: mantissaWidth,
        name: 'sqrt');
    output('sqrt') <= outputSqrt;
    late final error = output('error');

    // check to see if we do sqrt at all or just return a
    final isInf = a.isAnInfinity.named('isInf');
    final isNaN = a.isNaN.named('isNan');
    final isZero = a.isAZero.named('isZero');
    final isDeNormal = (~a.isNormal).named('isDenorm');
    final enableSqrt =
        ~((isInf | isNaN | isZero | isDeNormal) | a.sign).named('enableSqrt');

    // debias the exponent
    final deBiasAmt = (1 << a.exponent.width - 1) - 1;

    // deBias math
    final deBiasExp = (a.exponent - deBiasAmt).named('deBiasExp');

    // shift exponent
    final shiftedExp = [deBiasExp[-1], deBiasExp.slice(a.exponent.width - 1, 1)]
        .swizzle()
        .named('deBiasExp');

    // check if exponent was odd
    final isExpOdd = deBiasExp[0];

    // use fixed sqrt unit
    final aFixed = FixedPoint(
        signed: false, integerWidth: 3, fractionWidth: a.mantissa.width);
    aFixed <=
        [Const(1, width: 3), a.mantissa.getRange(0)].swizzle().named('aFixed');

    // mux if we shift left by 1 if exponent was odd
    final aFixedAdj = aFixed.clone(name: 'aFixedAdj')
      ..gets(mux(isExpOdd, [aFixed.slice(-2, 0), Const(0)].swizzle(), aFixed)
          .named('oddMantissaMux'));

    // mux to choose if we do square root or not
    final fixedSqrt = aFixedAdj.clone(name: 'fixedSqrt')
      ..gets(mux(enableSqrt, FixedPointSqrt(aFixedAdj).sqrt, aFixedAdj)
          .named('sqrtMux'));

    // convert back to floating point representation
    final fpSqrt = FixedToFloat(
        fixedSqrt,
        FloatingPoint(
            exponentWidth: a.exponent.width, mantissaWidth: a.mantissa.width));

    // final calculation results
    Combinational([
      error < Const(0),
      If.block([
        Iff(isInf & ~a.sign, [
          outputSqrt < outputSqrt.inf(),
        ]),
        ElseIf(isInf & a.sign, [
          outputSqrt < outputSqrt.inf(negative: true),
          error < Const(1),
        ]),
        ElseIf(isNaN, [
          outputSqrt < outputSqrt.nan,
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
        ElseIf(isDeNormal, [
          outputSqrt.sign < a.sign,
          outputSqrt.exponent < a.exponent,
          outputSqrt.mantissa < a.mantissa,
          error < Const(1),
        ]),
        Else([
          outputSqrt.sign < a.sign,
          outputSqrt.exponent < (shiftedExp + deBiasAmt),
          outputSqrt.mantissa < fpSqrt.float.mantissa,
        ])
      ])
    ]);
  }
}
