// Copyright (C) 2025 Intel Corporation
// SPDX-License-Indentifier: BSD-3-Clause
//
// fixed_point_sqrt.dart
// An abstract base class defining the API for floating-point square root.
//
// 2025 March 3
// Authors: James Farwell <james.c.farwell@intel.com>,
//          Stephen Weeks <stephen.weeks@intel.com>

// An abstract API for fixed point square root.
import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Base class for fixed-point square root
abstract class FixedPointSqrtBase extends Module {
  /// Width of the input and output fields.
  final int width;

  /// The value [a], named this way to allow for a local variable 'a'.
  @protected
  late final FixedPoint a;

  /// getter for the computed output.
  late final FixedPoint sqrt;

  /// Square root a fixed point number [a], returning result in [sqrt].
  FixedPointSqrtBase(FixedPoint a,
      {super.name = 'fixed_point_square_root',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : width = a.width,
        super(
            definitionName:
                definitionName ?? 'FixedPointSquareRoot${a.width}') {
    this.a = a.clone(name: 'a')..gets(addTypedInput('a', a));

    sqrt = addTypedOutput('sqrt', a.clone);
  }
}

/// Implementation
/// Algorithm explained here;
/// https://projectf.io/posts/square-root-in-verilog/
class FixedPointSqrt extends FixedPointSqrtBase {
  /// Constructor
  FixedPointSqrt(super.a) {
    if (a.signed) {
      throw RohdHclException('Signed values not supported');
    }

    Logic solution = FixedPoint(
        signed: a.signed,
        name: 'solution',
        integerWidth: a.integerWidth + 1,
        fractionWidth: a.fractionWidth + 1);
    Logic remainder = FixedPoint(
        signed: a.signed,
        name: 'remainder',
        integerWidth: a.integerWidth + 1,
        fractionWidth: a.fractionWidth + 1);
    Logic subtractionValue = FixedPoint(
        signed: a.signed,
        name: 'subValue',
        integerWidth: a.integerWidth + 1,
        fractionWidth: a.fractionWidth + 1);
    Logic aLoc = FixedPoint(
        signed: a.signed,
        name: 'aLoc',
        integerWidth: a.integerWidth + 1,
        fractionWidth: a.fractionWidth + 1);

    solution = Const(0, width: aLoc.width).named('solution');
    remainder = Const(0, width: aLoc.width).named('remainder');
    subtractionValue = Const(0, width: aLoc.width).named('subtraction');
    aLoc = [Const(0), a, Const(0)].swizzle().named('a_loc');

    final outputSqrt = a.clone(name: 'sqrt');
    output('sqrt') <= outputSqrt;

    // loop once through input value
    for (var i = 0; i < ((width + 2) >> 1); i++) {
      // append bits from a, two at a time
      remainder = [
        remainder.slice(width + 2 - 3, 0),
        aLoc.slice(aLoc.width - 1 - (i * 2), aLoc.width - 2 - (i * 2))
      ].swizzle().named('remainder_iter$i');
      subtractionValue = [solution.slice(width + 2 - 3, 0), Const(1, width: 2)]
          .swizzle()
          .named('subtraction_value_iter$i');
      solution = [
        solution.slice(width + 2 - 2, 0),
        subtractionValue.lte(remainder)
      ].swizzle().named('solution_iter$i');
      remainder = mux(subtractionValue.lte(remainder),
              remainder - subtractionValue, remainder)
          .named('remainder_mux_iter$i');
    }

    // loop again to finish remainder
    for (var i = 0; i < ((width + 2) >> 1) - 1; i++) {
      // don't try to append bits from a, they are done
      remainder = [remainder.slice(width + 2 - 3, 0), Const(0, width: 2)]
          .swizzle()
          .named('remainder_final_iter$i');
      subtractionValue = [solution.slice(width + 2 - 3, 0), Const(1, width: 2)]
          .swizzle()
          .named('subtraction_value_final_iter$i');
      solution = [
        solution.slice(width + 2 - 2, 0),
        subtractionValue.lte(remainder)
      ].swizzle().named('solution_final_iter$i');
      remainder = mux(subtractionValue.lte(remainder),
              remainder - subtractionValue, remainder)
          .named('remainder_finalmux_iter$i');
    }
    solution = (solution + 1).named('solutionPlusOne');
    outputSqrt <=
        solution.slice(aLoc.width - 1, aLoc.width - a.width).named('solutionF');
  }
}
