// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_to_float_test.dart
// Test fixed point to floating point converters.
//
// 2024 October 24
// Author: Soner Yaldiz <soner.yaldiz@intel.com>

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() async {
  test('FixedToFloat: singleton', () async {
    final fixed = FixedPoint(signed: true, m: 34, n: 33);
    const inDouble = 1.5;
    fixed.put(FixedPointValue.ofDouble(inDouble,
        signed: fixed.signed, m: fixed.m, n: fixed.n));
    final dut = FixedToFloat(fixed, exponentWidth: 8, mantissaWidth: 23);
    final fpv = dut.float.floatingPointValue;
    final fpvExpected = FloatingPointValue.populator(
            exponentWidth: dut.exponentWidth, mantissaWidth: dut.mantissaWidth)
        .ofDoubleUnrounded(inDouble);
    expect(fpv.sign, fpvExpected.sign);
    expect(fpv.exponent.bitString, fpvExpected.exponent.bitString,
        reason: 'exponent mismatch');
    expect(fpv.mantissa.bitString, fpvExpected.mantissa.bitString,
        reason: 'mantissa mismatch');
  });

  test('FixedToFloat: exhaustive', () async {
    for (final signed in [false, true]) {
      final fixed = FixedPoint(signed: signed, m: 8, n: 8);
      final dut = FixedToFloat(fixed,
          signed: signed, exponentWidth: 8, mantissaWidth: 16);
      await dut.build();
      for (var val = 0; val < pow(2, fixed.width); val++) {
        final fixedValue = FixedPointValue(
            value: LogicValue.ofInt(val, fixed.width),
            signed: signed,
            m: fixed.m,
            n: fixed.n);
        fixed.put(fixedValue);
        final fpv = dut.float.floatingPointValue;
        final fpvExpected = FloatingPointValue.populator(
                exponentWidth: dut.exponentWidth,
                mantissaWidth: dut.mantissaWidth)
            .ofDouble(fixedValue.toDouble());
        final newFixed = FixedPointValue.ofDouble(fpv.toDouble(),
            signed: true, m: fixed.m, n: fixed.n);
        expect(newFixed, equals(fixedValue), reason: '''
          fpvdbl=${fpv.toDouble()} $fpv
          ${newFixed.toDouble()} $newFixed
          ${fixedValue.toDouble()} $fixedValue
          ${fixed.fixedPointValue.toDouble()}  ${fixed.fixedPointValue}
''');
        expect(fpv.sign, fpvExpected.sign);
        expect(fpv.exponent, fpvExpected.exponent, reason: 'exponent');
        expect(fpv.mantissa, fpvExpected.mantissa, reason: 'mantissa');
      }
    }
  });

  test('FixedToFloat: leadingDigit smoke test', () async {
    final fixed = FixedPoint(signed: true, m: 34, n: 33);
    const inDouble = 1.5;
    fixed.put(FixedPointValue.ofDouble(inDouble,
        signed: fixed.signed, m: fixed.m, n: fixed.n));
    final leadingDigit = Const(33, width: log2Ceil(68) + 2);
    final dut = FixedToFloat(fixed,
        exponentWidth: 8, mantissaWidth: 23, leadingDigitPredict: leadingDigit);

    final fpv = dut.float.floatingPointValue;
    final fpvExpected = FloatingPointValue.populator(
            exponentWidth: dut.exponentWidth, mantissaWidth: dut.mantissaWidth)
        .ofDoubleUnrounded(inDouble);
    expect(fpv.sign, fpvExpected.sign);
    expect(fpv.exponent.bitString, fpvExpected.exponent.bitString,
        reason: 'exponent mismatch');
    expect(fpv.mantissa.bitString, fpvExpected.mantissa.bitString,
        reason: 'mantissa mismatch');
  });

  test('FixedToFloat: leadingDigit exhaustive', () async {
    const width = 16;

    final fixedIn = Logic(width: width);
    // ignore: cascade_invocations
    fixedIn.put(0);
    final leadZeroCounter = RecursiveModulePriorityEncoder(fixedIn.reversed);
    final leadZeroMin1Counter =
        RecursiveModulePriorityEncoder(fixedIn.reversed);

    for (final signed in [true]) {
      final fixed = FixedPoint(signed: signed, m: 8, n: 8);
      final dut = FixedToFloat(fixed,
          signed: signed,
          exponentWidth: 8,
          mantissaWidth: 16,
          leadingDigitPredict: leadZeroCounter.out.zeroExtend(9));
      final dutMin1 = FixedToFloat(fixed,
          signed: signed,
          exponentWidth: 8,
          mantissaWidth: 16,
          leadingDigitPredict: leadZeroMin1Counter.out.zeroExtend(9));
      for (var val = 0; val < pow(2, fixed.width); val++) {
        final lVal = LogicValue.ofInt(val, fixed.width);
        // Use a leading one detector on both positive and negative numbers
        fixedIn.put(signed & !lVal[-1].isZero ? ~val : val);
        final fixedValue = FixedPointValue(
            value: lVal, signed: signed, m: fixed.m, n: fixed.n);
        fixed.put(fixedValue);
        final fpv = dut.float.floatingPointValue;
        final fpvExpected = FloatingPointValue.populator(
                exponentWidth: dut.exponentWidth,
                mantissaWidth: dut.mantissaWidth)
            .ofDouble(fixedValue.toDouble());
        final fpv2 = dutMin1.float.floatingPointValue;
        final newFixed = FixedPointValue.ofDouble(fpv.toDouble(),
            signed: true, m: fixed.m, n: fixed.n);
        final newFixed2 = FixedPointValue.ofDouble(fpv2.toDouble(),
            signed: true, m: fixed.m, n: fixed.n);
        expect(newFixed, equals(fixedValue), reason: '''
          fpvdbl=${fpv.toDouble()} $fpv
          ${newFixed.toDouble()} $newFixed
          ${fixedValue.toDouble()} $fixedValue
          ${fixed.fixedPointValue.toDouble()}  ${fixed.fixedPointValue}
''');
        expect(fpv.sign, fpvExpected.sign);
        expect(fpv.exponent, fpvExpected.exponent, reason: 'exponent');
        expect(fpv.mantissa, fpvExpected.mantissa, reason: 'mantissa');
        expect(newFixed2, equals(fixedValue), reason: '''
          fpvdbl=${fpv.toDouble()} $fpv
          ${newFixed.toDouble()} $newFixed
          ${fixedValue.toDouble()} $fixedValue
          ${fixed.fixedPointValue.toDouble()}  ${fixed.fixedPointValue}
''');
        expect(fpv2.sign, fpvExpected.sign);
        expect(fpv2.exponent, fpvExpected.exponent, reason: 'exponent');
        expect(fpv2.mantissa, fpvExpected.mantissa, reason: 'mantissa');
      }
    }
  });

  test('Q16.16 to E5M2 < pow(2,14)', () async {
    final fixed = FixedPoint(signed: true, m: 16, n: 16);
    final dut = FixedToFloat(fixed, exponentWidth: 5, mantissaWidth: 2);
    await dut.build();
    for (var val = 0; val < pow(2, 14); val++) {
      final fixedValue = FixedPointValue(
          value: LogicValue.ofInt(val, fixed.width),
          signed: true,
          m: fixed.m,
          n: fixed.n);
      fixed.put(fixedValue);
      final fpv = dut.float.floatingPointValue;
      final fpvExpected = FloatingPointValue.populator(
              exponentWidth: dut.exponentWidth,
              mantissaWidth: dut.mantissaWidth)
          .ofDouble(fixedValue.toDouble());
      expect(fpv.sign, fpvExpected.sign);
      expect(fpv.exponent.bitString, fpvExpected.exponent.bitString,
          reason: 'exponent');
      expect(fpv.mantissa.bitString, fpvExpected.mantissa.bitString,
          reason: 'mantissa');
    }
  });

  test('Signed Q4.4 to E3M2', () async {
    final fixed = FixedPoint(signed: true, m: 4, n: 4);
    final dut = FixedToFloat(fixed, exponentWidth: 3, mantissaWidth: 2);
    await dut.build();
    for (var val = 0; val < pow(2, fixed.width); val++) {
      final fixedValue = FixedPointValue(
          value: LogicValue.ofInt(val, fixed.width),
          signed: fixed.signed,
          m: fixed.m,
          n: fixed.n);
      fixed.put(fixedValue);
      final fpv = dut.float.floatingPointValue;
      final fpvExpected = FloatingPointValue.populator(
              exponentWidth: dut.exponentWidth,
              mantissaWidth: dut.mantissaWidth)
          .ofDouble(fixedValue.toDouble());
      expect(fpv.sign, fpvExpected.sign);
      expect(fpv.exponent.bitString, fpvExpected.exponent.bitString,
          reason: 'exponent mismatch');
      expect(fpv.mantissa.bitString, fpvExpected.mantissa.bitString,
          reason: 'mantissa mismatch');
    }
  });

  test('Unsigned Q4.4 to E3M2', () async {
    final fixed = FixedPoint(signed: false, m: 4, n: 4);
    final dut = FixedToFloat(fixed, exponentWidth: 3, mantissaWidth: 2);
    await dut.build();
    for (var val = 0; val < pow(2, fixed.width); val++) {
      final fixedValue = FixedPointValue(
          value: LogicValue.ofInt(val, fixed.width),
          signed: fixed.signed,
          m: fixed.m,
          n: fixed.n);
      fixed.put(fixedValue);
      final fpv = dut.float.floatingPointValue;
      final fpvExpected = FloatingPointValue.populator(
              exponentWidth: dut.exponentWidth,
              mantissaWidth: dut.mantissaWidth)
          .ofDouble(fixedValue.toDouble());
      expect(fpv.sign, fpvExpected.sign);
      expect(fpv.exponent.bitString, fpvExpected.exponent.bitString,
          reason: 'exponent mismatch');
      expect(fpv.mantissa.bitString, fpvExpected.mantissa.bitString,
          reason: 'mantissa mismatch');
    }
  });

  test('Signed Q0.8 to E3M2 shrink', () async {
    final fixed = FixedPoint(signed: true, m: 0, n: 7);
    final dut = FixedToFloat(fixed, exponentWidth: 3, mantissaWidth: 2);
    await dut.build();
    for (var val = 0; val < pow(2, fixed.width); val++) {
      final fixedValue = FixedPointValue(
          value: LogicValue.ofInt(val, fixed.width),
          signed: fixed.signed,
          m: fixed.m,
          n: fixed.n);
      fixed.put(fixedValue);
      final fpv = dut.float.floatingPointValue;
      final fpvExpected = FloatingPointValue.populator(
              exponentWidth: dut.exponentWidth,
              mantissaWidth: dut.mantissaWidth)
          .ofDouble(fixedValue.toDouble());
      expect(fpv.sign, fpvExpected.sign);
      expect(fpv.exponent.bitString, fpvExpected.exponent.bitString,
          reason: 'exponent mismatch');
      expect(fpv.mantissa.bitString, fpvExpected.mantissa.bitString,
          reason: 'mantissa mismatch');
    }
  });

  test('Signed Q0.3 to E5M6 expand', () async {
    final fixed = FixedPoint(signed: true, m: 0, n: 3);
    final dut = FixedToFloat(fixed, exponentWidth: 5, mantissaWidth: 6);
    await dut.build();
    for (var val = 0; val < pow(2, fixed.width); val++) {
      final fixedValue = FixedPointValue(
          value: LogicValue.ofInt(val, fixed.width),
          signed: fixed.signed,
          m: fixed.m,
          n: fixed.n);
      fixed.put(fixedValue);
      final fpv = dut.float.floatingPointValue;
      final fpvExpected = FloatingPointValue.populator(
              exponentWidth: dut.exponentWidth,
              mantissaWidth: dut.mantissaWidth)
          .ofDouble(fixedValue.toDouble());
      expect(fpv.sign, fpvExpected.sign);
      expect(fpv.exponent.bitString, fpvExpected.exponent.bitString,
          reason: 'exponent mismatch');
      expect(fpv.mantissa.bitString, fpvExpected.mantissa.bitString,
          reason: 'mantissa mismatch');
    }
  });

  test('Signed Q7.0 to E3M2', () async {
    final fixed = FixedPoint(signed: true, m: 7, n: 0);
    final dut = FixedToFloat(fixed, exponentWidth: 3, mantissaWidth: 2);
    await dut.build();
    for (var val = 0; val < pow(2, fixed.width); val++) {
      final fixedValue = FixedPointValue(
          value: LogicValue.ofInt(val, fixed.width),
          signed: fixed.signed,
          m: fixed.m,
          n: fixed.n);
      fixed.put(fixedValue);
      final fpv = dut.float.floatingPointValue;
      final fpvExpected = FloatingPointValue.populator(
              exponentWidth: dut.exponentWidth,
              mantissaWidth: dut.mantissaWidth)
          .ofDouble(fixedValue.toDouble());
      expect(fpv.sign, fpvExpected.sign);
      expect(fpv.exponent.bitString, fpvExpected.exponent.bitString,
          reason: 'exponent mismatch');
      expect(fpv.mantissa.bitString, fpvExpected.mantissa.bitString,
          reason: 'mantissa mismatch');
    }
  }, skip: true);
}
