// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point.dart
// Implementation of Floating Point stuff
//
// 2024 August 30
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An multiplier module for FloatingPoint values
class FloatingPointMultiplier extends Module {
  /// Must be greater than 0.
  final int exponentWidth;

  /// Must be greater than 0.
  final int mantissaWidth;

  /// Output [FloatingPoint] computed
  late final FloatingPoint out =
      FloatingPoint(exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        ..gets(output('out'));

  /// The result of [FloatingPoint] multiplication
  @protected
  late final FloatingPoint _out =
      FloatingPoint(exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// Multiply two floating point numbers [a] and [b], returning result in [out]
  FloatingPointMultiplier(FloatingPoint a, FloatingPoint b, int radix,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic)) ppTree,
      {super.name})
      : exponentWidth = a.exponent.width,
        mantissaWidth = a.mantissa.width {
    if (b.exponent.width != exponentWidth ||
        b.mantissa.width != mantissaWidth) {
      throw RohdHclException('FloatingPoint widths must match');
    }
    a = a.clone()..gets(addInput('a', a, width: a.width));
    b = b.clone()..gets(addInput('b', b, width: b.width));
    addOutput('out', width: _out.width) <= _out;
    final aExp =
        a.exponent + mux(a.isNormal(), a.zeroExponent(), a.oneExponent());
    final bExp =
        b.exponent + mux(b.isNormal(), b.zeroExponent(), b.oneExponent());

    final aMantissa = [a.isNormal(), a.mantissa].swizzle();
    final bMantissa = [b.isNormal(), b.mantissa].swizzle();

    // print('am = ${bitString(aMantissa.value)}');
    // print('bm = ${bitString(bMantissa.value)}');

    final pp = PartialProductGeneratorCompactRectSignExtension(
        aMantissa, bMantissa, RadixEncoder(radix),
        signed: false);
    final compressor = ColumnCompressor(pp)..compress();
    final r0 = compressor.extractRow(0);
    final r1 = compressor.extractRow(1);
    final adder = ParallelPrefixAdder(r0, r1, ppGen: ppTree);

    final rawMantissa = adder.sum.slice((exponentWidth + 1) * 2 - 1, 0);

    // Find the leading '1' in the mantissa
    final pos =
        ParallelPrefixPriorityEncoder(rawMantissa.reversed, ppGen: ppTree)
            .out
            .zeroExtend(exponentWidth);

    final expAdd =
        aExp - FloatingPointValue.computeBias(aExp.width) + bExp - pos + 1;

    // stdout.write('aExp=${aExp.value}, bExp=${bExp.value}, '
    //     'pos=${pos.value}, bias=${FloatingPointValue.bias(aExp.width)} '
    //     'expAdd=${expAdd.value}\n');

    final mantissa = rawMantissa << (pos + 1);
    final normMantissa = mantissa.reversed.slice(mantissaWidth - 1, 0).reversed;

    // stdout
    //   ..write('aMant:  ${bitString(aMantissa.value)}\n')
    //   ..write('bMant:  ${bitString(bMantissa.value)}\n')
    //   ..write('out:  ${bitString(adder.out.value)}\n')
    //   ..write('lenOut:  ${adder.out.width} ')
    //   ..write('rawMantissa:  ${bitString(rawMantissa.value)} ')
    //   ..write('normMantissa: ${bitString(normMantissa.value)}')
    //   ..write('\n')
    //   ..write(
    //       'e=${bitString(expAdd.value)} m=${bitString(normMantissa.value)}\n');

    _out.sign <= a.sign ^ b.sign;
    _out.exponent <= expAdd;
    // _out.exponent <= Const(8, width: exponentWidth);
    _out.mantissa <= normMantissa;
  }
}
