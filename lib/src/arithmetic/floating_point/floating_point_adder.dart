// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_test.dart
// Tests of Floating Point stuff
//
// 2024 August 30
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An adder module for FloatingPoint values
class FloatingPointAdder extends Module {
  /// Must be greater than 0.
  final int exponentWidth;

  /// Must be greater than 0.
  final int mantissaWidth;

  /// Output [FloatingPoint] computed
  late final FloatingPoint sum =
      FloatingPoint(exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        ..gets(output('sum'));

  /// The result of [FloatingPoint] addition
  @protected
  late final FloatingPoint _sum =
      FloatingPoint(exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// Swapping two FloatingPoint structures based on a conditional
  static (FloatingPoint, FloatingPoint) _swap(
          Logic swap, (FloatingPoint, FloatingPoint) toSwap) =>
      (
        toSwap.$1.clone()..gets(mux(swap, toSwap.$2, toSwap.$1)),
        toSwap.$2.clone()..gets(mux(swap, toSwap.$1, toSwap.$2))
      );

  /// Add two floating point numbers [a] and [b], returning result in [sum]
  FloatingPointAdder(FloatingPoint a, FloatingPoint b,
      {ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))
          ppGen = KoggeStone.new,
      super.name})
      : exponentWidth = a.exponent.width,
        mantissaWidth = a.mantissa.width {
    if (b.exponent.width != exponentWidth ||
        b.mantissa.width != mantissaWidth) {
      throw RohdHclException('FloatingPoint widths must match');
    }
    a = a.clone()..gets(addInput('a', a, width: a.width));
    b = b.clone()..gets(addInput('b', b, width: b.width));
    addOutput('sum', width: _sum.width) <= _sum;

    // Ensure that the larger number is wired as 'a'
    final doSwap = a.exponent.lt(b.exponent) |
        (a.exponent.eq(b.exponent) & a.mantissa.lt(b.mantissa)) |
        ((a.exponent.eq(b.exponent) & a.mantissa.eq(b.mantissa)) & b.sign);

    (a, b) = _swap(doSwap, (a, b));

    final aExp =
        a.exponent + mux(a.isNormal(), a.zeroExponent(), a.oneExponent());
    final bExp =
        b.exponent + mux(b.isNormal(), b.zeroExponent(), b.oneExponent());

    // Align and add mantissas
    final expDiff = aExp - bExp;
    // print('${expDiff.value.toInt()} exponent diff');
    final adder = SignMagnitudeAdder(
        a.sign,
        [a.isNormal(), a.mantissa].swizzle(),
        b.sign,
        [b.isNormal(), b.mantissa].swizzle() >>> expDiff,
        (a, b) => ParallelPrefixAdder(a, b, ppGen: ppGen));

    final sum = adder.sum.slice(adder.sum.width - 2, 0);
    final leadOneE =
        ParallelPrefixPriorityEncoder(sum.reversed, ppGen: ppGen).out;
    final leadOne = leadOneE.zeroExtend(exponentWidth);

    // Assemble the output FloatingPoint
    _sum.sign <= adder.sign;
    Combinational([
      If.block([
        Iff(adder.sum[-1] & a.sign.eq(b.sign), [
          _sum.mantissa < (sum >> 1).slice(mantissaWidth - 1, 0),
          _sum.exponent < a.exponent + 1
        ]),
        ElseIf(a.exponent.gt(leadOne) & sum.or(), [
          _sum.mantissa < (sum << leadOne).slice(mantissaWidth - 1, 0),
          _sum.exponent < a.exponent - leadOne
        ]),
        ElseIf(leadOne.eq(0) & sum.or(), [
          _sum.mantissa < (sum << leadOne).slice(mantissaWidth - 1, 0),
          _sum.exponent < a.exponent - leadOne + 1
        ]),
        Else([
          // subnormal result
          _sum.mantissa < sum.slice(mantissaWidth - 1, 0),
          _sum.exponent < _sum.zeroExponent()
        ])
      ])
    ]);
    // print('final sum: ${_sum.value.bitString}');
  }
}
