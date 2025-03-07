// Copyright (C) 2025 Intel Corporation
// SPDX-License-Indentifier: BSD-3-Clause
//
// floating_point_sqrt.dart
// An abstract base class defining the API for floating-point square root.
//
// 2025 March 4
// Authors: James Farwell <james.c.farwell@intel.com>,
//Stephen Weeks <stephen.weeks@intel.com>,
//Curtis Anderson <curtis.anders@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An square root module for FloatingPoint values
class FloatingPointSqrtSimple<FpType extends FloatingPoint>
    extends FloatingPointSqrt<FpType> {
  /// Square root one floating point number [a], returning results
  /// [sqrtR] and [error]
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
        name: 'sqrtR');
    output('sqrtR') <= outputSqrt;

    // check to see if we do sqrt at all or just return a
    final isInf = a.isAnInfinity.named('isInf');
    final isNaN = a.isNaN.named('isNan');
    final isZero = a.isAZero.named('isZero');
    final enableSqrt = ~((isInf | isNaN | isZero) | a.sign).named('enableSqrt');

    // debias the exponent
    final deBiasAmt = (1 << a.exponent.width - 1) - 1;

    // deBias math
    final deBiasExp = a.exponent - deBiasAmt;

    // shift exponent
    final shiftedExp =
        [deBiasExp[-1], deBiasExp.slice(a.exponent.width - 1, 1)].swizzle();

    // check if exponent was odd
    final isExpOdd = deBiasExp[0];

    // use fixed sqrt unit
    final aFixed = FixedPoint(signed: false, m: 3, n: a.mantissa.width);
    aFixed <= [Const(1, width: 3), a.mantissa.getRange(0)].swizzle();

    // mux if we shift left by 1 if exponent was odd
    final aFixedAdj = aFixed.clone()
      ..gets(mux(isExpOdd, [aFixed.slice(-2, 0), Const(0)].swizzle(), aFixed)
          .named('oddMantissaMux'));

    // mux to choose if we do square root or not
    final fixedSqrt = aFixedAdj.clone()
      ..gets(mux(enableSqrt, FixedPointSqrt(aFixedAdj).sqrtF, aFixedAdj)
          .named('sqrtMux'));

    // convert back to floating point representation
    final fpSqrt = FixedToFloat(fixedSqrt,
        exponentWidth: a.exponent.width, mantissaWidth: a.mantissa.width);

    // final calculation results
    Combinational([
      errorSig < Const(0),
      If.block([
        Iff(isInf & ~a.sign, [
          outputSqrt < outputSqrt.inf(),
        ]),
        ElseIf(isInf & a.sign, [
          outputSqrt < outputSqrt.inf(negative: true),
          errorSig < Const(1),
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
          errorSig < Const(1),
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
