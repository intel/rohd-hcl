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
      FloatingPointAdderSinglePath(fp1, fp2),
      FloatingPointAdderDualPath(fp1, fp2)
    ]) {
      final testCases = [
        (
          fv.clonePopulator().positiveInfinity,
          fv.clonePopulator().positiveInfinity
        ),
        (
          fv.clonePopulator().negativeInfinity,
          fv.clonePopulator().negativeInfinity
        ),
        (
          fv.clonePopulator().positiveInfinity,
          fv.clonePopulator().negativeInfinity
        ),
        (
          fv.clonePopulator().positiveInfinity,
          fv.clonePopulator().positiveZero
        ),
        (
          fv.clonePopulator().negativeInfinity,
          fv.clonePopulator().positiveZero
        ),
        (fv.clonePopulator().positiveInfinity, fv.clonePopulator().one),
        (fv.clonePopulator().negativeInfinity, fv.clonePopulator().one),
        (fv.clonePopulator().one.negate(), fv.clonePopulator().one),
        (fv.clonePopulator().positiveZero, fv.clonePopulator().positiveZero),
        (
          fv.clonePopulator().positiveZero.negate(),
          fv.clonePopulator().positiveZero
        ),
      ];

      for (final test in testCases) {
        final fv1 = test.$1;
        final fv2 = test.$2;

        final doubleProduct = fv1.toDouble() + fv2.toDouble();
        final partWay = FloatingPointValue.populator(
                exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
            .ofDouble(doubleProduct);
        final roundTrip = partWay.toDouble();

        fp1.put(fv1.value);
        fp2.put(fv2.value);
        final fpOut = adder.sum;
        expect(fpOut.floatingPointValue.isNaN, equals(partWay.isNaN));
        if (!fpOut.floatingPointValue.isNaN) {
          expect(fpOut.floatingPointValue, equals(partWay),
              reason: '\t${fp1.floatingPointValue} '
                  '(${fp1.floatingPointValue.toDouble()})\n'
                  '\t${fp2.floatingPointValue} '
                  '(${fp2.floatingPointValue.toDouble()}) =\n'
                  '\t${fpOut.floatingPointValue} '
                  '(${fpOut.floatingPointValue.toDouble()}) actual\n'
                  '\t$partWay ($roundTrip) expected');
        }

        final partWayU = FloatingPointValue.populator(
                exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
            .ofDoubleUnrounded(doubleProduct);
        final roundTripU = partWay.toDouble();
        expect(fpOut.floatingPointValue.isNaN, equals(partWayU.isNaN));
        if (!fpOut.floatingPointValue.isNaN) {
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
    }
  });
}
