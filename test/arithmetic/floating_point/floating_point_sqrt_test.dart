// Copyright (C) 2025-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_sqrt.dart
// An abstract base class defining the API for floating-point square root.
//
// 2025 March 5
// Authors: James Farwell <james.c.farwell@intel.com>,
//          Stephen Weeks <stephen.weeks@intel.com>,
//          Curtis Anderson <curtis.anders@intel.com>

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });
  test('FP: square-root subnormal normalization', () {
    final significand = Logic(width: 5)..put(1);
    final leadingOne = RecursiveModulePriorityEncoder(significand.reversed).out;
    expect(leadingOne.value.toInt(), 4);
    final normalized = significand << leadingOne;
    expect(normalized.value.toInt(), 16);
    final fixed = FixedPoint(signed: false, integerWidth: 3, fractionWidth: 9)
      ..gets(Const(1 << 9, width: 12));
    expect(FixedPointSqrt(fixed).sqrt.value.toInt(), 1 << 9);
  });

  test('FP: square root with non-FP numbers', () {
    // building with 16-bit FP representation
    const exponentWidth = 3;
    const mantissaWidth = 7;

    final fv = FloatingPointValue(
        sign: LogicValue.zero,
        exponent: LogicValue.filled(exponentWidth, LogicValue.one),
        mantissa: LogicValue.filled(mantissaWidth, LogicValue.zero));

    final fp = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

    for (final sqrtT in [
      FloatingPointSqrtSimple(fp),
    ]) {
      final testCases = [
        fv.clonePopulator().nan,
        fv.clonePopulator().positiveInfinity,
        fv.clonePopulator().positiveZero,
        fv.clonePopulator().positiveZero.negate(),
      ];

      for (final test in testCases) {
        final fv = test;

        final dSqrt = sqrt(fv.toDouble());
        final expSqrt = fp.valuePopulator().ofDouble(dSqrt);
        final expSqrtd = expSqrt.toDouble();
        final Logic expError = Const(0);

        fp.put(fv);
        final fpOut = sqrtT.sqrt;
        final eOut = sqrtT.error;
        expect(fpOut.floatingPointValue.isNaN, equals(expSqrt.isNaN));
        if (!fpOut.floatingPointValue.isNaN) {
          expect(fpOut.floatingPointValue, equals(expSqrt), reason: '''
  ${fp.floatingPointValue} (${fp.floatingPointValue.toDouble()}) =
  ${fpOut.floatingPointValue}(${fpOut.floatingPointValue.toDouble()}) actual
  $expSqrtd ($expSqrt) expected''');

          expect(eOut.value, equals(expError.value), reason: '''
error =
  ${eOut.value} actual
  ${expError.value} expected''');
        }
      }
    }
  });

  test('FP: square root with error flag high', () {
    const exponentWidth = 8;
    const mantissaWidth = 23;

    final fv = FloatingPointValue(
        sign: LogicValue.zero,
        exponent: LogicValue.filled(exponentWidth, LogicValue.one),
        mantissa: LogicValue.filled(mantissaWidth, LogicValue.zero));

    final fp = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

    for (final sqrtDUT in [
      FloatingPointSqrtSimple(fp),
    ]) {
      final testCases = [
        fv.clonePopulator().positiveInfinity.negate(),
        fv.clonePopulator().one.negate(),
      ];

      for (final test in testCases) {
        final fv = test;
        final expError = Const(1);

        fp.put(fv);
        final eOut = sqrtDUT.error;

        expect(eOut.value, equals(expError.value), reason: '''
error =
  ${eOut.value} actual
  ${expError.value} expected''');
      }
    }
  });

  test('FP: targeted normalized sqrt', () {
    const exponentWidth = 8;
    const mantissaWidth = 23;

    final fp = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

    for (final sqrtDUT in [
      FloatingPointSqrtSimple(fp),
    ]) {
      final testCases = [
        144.0,
        288.0,
        3.567,
        1123.5,
        17.0,
        92.5,
        100.0,
        85.672,
      ];

      for (final test in testCases) {
        final fv = fp.valuePopulator().ofDouble(test);

        fp.put(fv);

        final compResult = sqrtDUT.sqrt;
        final compError = sqrtDUT.error;

        final expResult = fp.valuePopulator().ofDouble(sqrt(test));
        final expError = Const(0);
        expect(compResult.floatingPointValue.toDouble(),
            equals(expResult.toDouble()),
            reason: '''
  ${fp.floatingPointValue} (${fp.floatingPointValue.toDouble()}) =
  ${compResult.floatingPointValue}(${compResult.floatingPointValue.toDouble()}) actual
  $expResult (${expResult.toDouble()}) expected''');

        expect(compError.value, equals(expError.value), reason: '''
error =
${expError.value} actual
${expError.value} expected''');
      }
    }
  });

  test('FP: square root supports every rounding mode and subnormals', () {
    const exponentWidth = 4;
    const mantissaWidth = 4;
    FloatingPointValuePopulator populator() => FloatingPointValue.populator(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final random = Random(0x754);

    for (final mode in FloatingPointRoundingMode.values) {
      final fp = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final sqrtDut = FloatingPointSqrtSimple(fp, roundingMode: mode);
      final positiveZero =
          populator().ofConstant(FloatingPointConstants.positiveZero);
      final values = [
        for (final mantissa in [1, 2, 7, 15]) populator().ofInts(0, mantissa),
        for (var iteration = 0; iteration < 100; iteration++)
          populator().random(random, gte: positiveZero, excludeInfinity: true),
      ];

      for (final value in values) {
        fp.put(value);
        final expected = populator().squareRoot(value, roundingMode: mode);
        final actual = sqrtDut.sqrt.floatingPointValue;
        expect(actual.isNaN, expected.isNaN, reason: 'mode=$mode value=$value');
        if (!expected.isNaN) {
          expect(actual, expected, reason: 'mode=$mode value=$value');
        }
      }

      final negativeInfinity =
          populator().ofConstant(FloatingPointConstants.negativeInfinity);
      fp.put(negativeInfinity);
      expect(sqrtDut.sqrt.floatingPointValue.isNaN, isTrue,
          reason: 'mode=$mode');
      expect(sqrtDut.error.value.toBool(), isTrue, reason: 'mode=$mode');
    }
  });

  test('FP: square root preserves E3M5 subnormal output exponent', () {
    const exponentWidth = 3;
    const mantissaWidth = 5;
    final inputPopulator = FloatingPointValue.populator(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final input = inputPopulator.ofInts(0, 1);
    final expected = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .squareRoot(input);
    final fp = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final sqrtDut = FloatingPointSqrtSimple(fp);

    fp.put(input);
    expect(sqrtDut.sqrt.floatingPointValue, equals(expected));
    expect(sqrtDut.sqrt.exponent.value.toInt(), equals(0));
  });

  test('FP: random number sqrt', () {
    const exponentWidth = 3;
    const mantissaWidth = 5;
    final systemTestIter = pow(2, exponentWidth) * pow(2, mantissaWidth);

    final fp = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

    final sqrtDUT = FloatingPointSqrtSimple(fp);
    final rand = Random(513);
    for (var i = 0; i < systemTestIter; i++) {
      final fv = fp.valuePopulator().random(rand, genSubNormal: false);
      fp.put(fv);
      // only want to test on positive real values
      if (fp.isAnInfinity.value.toBool() ||
          fp.isNaN.value.toBool() ||
          fp.isAZero.value.toBool() ||
          fp.sign.value.toBool()) {
        continue;
      }
      final compResult = sqrtDUT.sqrt;
      final compError = sqrtDUT.error;

      final expResult = fp.valuePopulator().squareRoot(fv);
      final expError = Const(0);

      expect(compResult.floatingPointValue, expResult, reason: '''
  ${fp.floatingPointValue} (${fp.floatingPointValue.toDouble()}) =
  ${compResult.floatingPointValue} (${compResult.floatingPointValue.toDouble()}) actual
  $expResult (${expResult.toDouble()}) expected''');

      expect(compError.value, equals(expError.value), reason: '''
error =
${expError.value} actual
${expError.value} expected''');
    }
  });
}
