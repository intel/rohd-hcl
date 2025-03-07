// Copyright (C) 2025 Intel Corporation
// SPDX-License-Indentifier: BSD-3-Clause
//
// fixed_point_sqrt.dart
// An abstract base class defining the API for floating-point square root.
//
// 2025 March 3
// Authors: James Farwell <james.c.farwell@intel.com>, Stephen
// Weeks <stephen.weeks@intel.com>

/// An abstract API for fixed point square root.
library;

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Abstract base class
abstract class FixedPointSqrtBase extends Module {
  /// Width of the input and output fields.
  final int numWidth;

  /// The value [a], named this way to allow for a local variable 'a'.
  @protected
  late final FixedPoint a;

  /// getter for the computed output.
  late final FixedPoint sqrtF = a.clone(name: 'sqrtF')..gets(output('sqrtF'));

  /// Square root a fixed point number [a], returning result in [sqrtF].
  FixedPointSqrtBase(FixedPoint a,
      {super.name = 'fixed_point_square_root', String? definitionName})
      : numWidth = a.width,
        super(
            definitionName:
                definitionName ?? 'FixedPointSquareRoot${a.width}') {
    this.a = a.clone(name: 'a')..gets(addInput('a', a, width: a.width));

    addOutput('sqrtF', width: numWidth);
  }
}

/// Implementation
/// Algorithm explained here;
/// https://projectf.io/posts/square-root-in-verilog/
class FixedPointSqrt extends FixedPointSqrtBase {
  /// Constructor
  FixedPointSqrt(super.a) {
    Logic solution =
        FixedPoint(signed: a.signed, name: 'solution', m: a.m + 1, n: a.n + 1);
    Logic remainder =
        FixedPoint(signed: a.signed, name: 'remainder', m: a.m + 1, n: a.n + 1);
    Logic subtractionValue =
        FixedPoint(signed: a.signed, name: 'subValue', m: a.m + 1, n: a.n + 1);
    Logic aLoc =
        FixedPoint(signed: a.signed, name: 'aLoc', m: a.m + 1, n: a.n + 1);

    solution = Const(0, width: aLoc.width);
    remainder = Const(0, width: aLoc.width);
    subtractionValue = Const(0, width: aLoc.width);
    aLoc = [Const(0), a, Const(0)].swizzle();

    final outputSqrt = a.clone(name: 'sqrtF');
    output('sqrtF') <= outputSqrt;

    // loop once through input value
    for (var i = 0; i < ((numWidth + 2) >> 1); i++) {
      // append bits from a, two at a time
      remainder = [
        remainder.slice(numWidth + 2 - 3, 0),
        aLoc.slice(aLoc.width - 1 - (i * 2), aLoc.width - 2 - (i * 2))
      ].swizzle();
      subtractionValue =
          [solution.slice(numWidth + 2 - 3, 0), Const(1, width: 2)].swizzle();
      solution = [
        solution.slice(numWidth + 2 - 2, 0),
        subtractionValue.lte(remainder)
      ].swizzle();
      remainder = mux(subtractionValue.lte(remainder),
          remainder - subtractionValue, remainder);
    }

    // loop again to finish remainder
    for (var i = 0; i < ((numWidth + 2) >> 1) - 1; i++) {
      // don't try to append bits from a, they are done
      remainder =
          [remainder.slice(numWidth + 2 - 3, 0), Const(0, width: 2)].swizzle();
      subtractionValue =
          [solution.slice(numWidth + 2 - 3, 0), Const(1, width: 2)].swizzle();
      solution = [
        solution.slice(numWidth + 2 - 2, 0),
        subtractionValue.lte(remainder)
      ].swizzle();
      remainder = mux(subtractionValue.lte(remainder),
          remainder - subtractionValue, remainder);
    }
    solution = solution + 1;
    outputSqrt <= solution.slice(aLoc.width - 1, aLoc.width - a.width);
  }
}
