// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_adder_test.dart
// Basic tests for all floating-point adders.
//
// 2025 January 3
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });
  test('FP: adder basic interesting extreme corners', () {
    const exponentWidth = 4;
    const mantissaWidth = 4;

    final fv = FloatingPointValue(
        sign: LogicValue.zero,
        exponent: LogicValue.filled(exponentWidth, LogicValue.one),
        mantissa: LogicValue.filled(exponentWidth, LogicValue.zero));

    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    fp1.put(fv);
    fp2.put(fv);

    for (final adder in [
      FloatingPointAdderSimple(fp1, fp2),
      FloatingPointAdderRound(fp1, fp2)
    ]) {
      final testCases = [
        (fv.infinity, fv.infinity),
        (fv.negativeInfinity, fv.negativeInfinity),
        (fv.infinity, fv.negativeInfinity),
        (fv.infinity, fv.zero),
        (fv.negativeInfinity, fv.zero),
        (fv.infinity, fv.one),
        (fv.negativeInfinity, fv.one),
        (fv.one.negate(), fv.one),
        (fv.zero, fv.zero),
        (fv.zero.negate(), fv.zero),
      ];

      for (final test in testCases) {
        final fv1 = test.$1;
        final fv2 = test.$2;

        final doubleProduct = fv1.toDouble() + fv2.toDouble();
        final partWay = FloatingPointValue.ofDouble(doubleProduct,
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
        final roundTrip = partWay.toDouble();

        fp1.put(fv1.value);
        fp2.put(fv2.value);
        final fpOut = adder.sum;
        expect(fpOut.floatingPointValue, equals(partWay),
            reason: '\t${fp1.floatingPointValue} '
                '(${fp1.floatingPointValue.toDouble()})\n'
                '\t${fp2.floatingPointValue} '
                '(${fp2.floatingPointValue.toDouble()}) =\n'
                '\t${fpOut.floatingPointValue} '
                '(${fpOut.floatingPointValue.toDouble()}) actual\n'
                '\t$partWay ($roundTrip) expected');

        final partWayU = FloatingPointValue.ofDoubleUnrounded(doubleProduct,
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
        final roundTripU = partWay.toDouble();
        expect(fpOut.floatingPointValue, equals(partWayU),
            reason: '\t${fp1.floatingPointValue} '
                '(${fp1.floatingPointValue.toDouble()})\n'
                '\t${fp2.floatingPointValue} '
                '(${fp2.floatingPointValue.toDouble()}) =\n'
                '\t${fpOut.floatingPointValue} '
                '(${fpOut.floatingPointValue.toDouble()}) actual\n'
                '\t$partWayU ($roundTripU) expected');
      }
    }
  });
}
