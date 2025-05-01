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
    const inDouble = -2.0;
    fixed.put(FixedPointValue.ofDouble(inDouble,
        signed: fixed.signed, m: fixed.m, n: fixed.n));
    final fp = FloatingPoint(exponentWidth: 8, mantissaWidth: 23);
    final dut = FixedToFloat(fixed, fp);
    final fpv = dut.float.floatingPointValue;
    final fpvExpected = FloatingPointValue.populator(
            exponentWidth: fp.exponent.width, mantissaWidth: fp.mantissa.width)
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
      final dut = FixedToFloat(
          fixed,
          signed: signed,
          FloatingPoint(exponentWidth: 8, mantissaWidth: 16));
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
                exponentWidth: dut.float.exponent.width,
                mantissaWidth: dut.float.mantissa.width)
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

  test('FixedToFloat addition with Anticipate: signed singleton', () async {
    const width = 8;
    final val1 = LogicValue.ofInt(0, width);
    final val2 = LogicValue.ofInt(192, width);

    final a = Logic(width: width);
    final b = Logic(width: width);
    a.put(val1);
    b.put(val2);

    final fixed = FixedPoint(signed: true, m: width ~/ 2 - 1, n: width ~/ 2);
    final val = NativeAdder(a, b).sum.slice(width - 1, 0).value;
    final fixedValue =
        FixedPointValue(signed: true, value: val, m: fixed.m, n: fixed.n);
    fixed.put(fixedValue);
    final anticipator = LeadingDigitAnticipate(a, b);
    final dut = FixedToFloat(
      fixed,
      FloatingPoint(exponentWidth: 8, mantissaWidth: 16),
      leadingDigitPredict: anticipator.leadingDigit,
    );
    final fpv = dut.float.floatingPointValue;
    final roundTripFixed = FixedPointValue.ofDouble(fpv.toDouble(),
        signed: true, m: fixed.m, n: fixed.n);
    expect(roundTripFixed, equals(fixedValue), reason: '''
          val1=$val1\t ${a.value.bitString}
          val2=$val2\t ${b.value.bitString}
          val =$val\t${fixedValue.value.bitString}
          fpvdbl=${fpv.toDouble()} $fpv
          ${roundTripFixed.toDouble()} $roundTripFixed
          ${fixedValue.toDouble()} $fixedValue
          ${fixed.fixedPointValue.toDouble()}  ${fixed.fixedPointValue}
''');
  });

  test('FixedToFloat: Add with Anticipate: exhaustive', () async {
    const width = 8;
    final a = Logic(width: width)..put(0);
    final b = Logic(width: width)..put(0);
    final anticipator = LeadingDigitAnticipate(a, b);
    final val = NativeAdder(a, b).sum.slice(width - 1, 0).value;
    for (final signed in [false, true]) {
      final fixed = FixedPoint(
          signed: signed, m: width ~/ 2 - (signed ? 1 : 0), n: width ~/ 2);
      final fixedValue = FixedPointValue(
          value: LogicValue.zero.zeroExtend(fixed.width),
          signed: signed,
          m: fixed.m,
          n: fixed.n);
      fixed.put(fixedValue);

      final dut = FixedToFloat(
        fixed,
        signed: signed,
        FloatingPoint(exponentWidth: 8, mantissaWidth: 16),
        leadingDigitPredict: anticipator.leadingDigit.zeroExtend(9),
      );
      for (var val1 = 0; val1 < pow(2, fixed.width); val1++) {
        for (var val2 = 0; val2 < pow(2, fixed.width); val2++) {
          final lVal1 = LogicValue.ofInt(val1, width);
          final lVal2 = LogicValue.ofInt(val2, width);
          a.put(lVal1);
          b.put(lVal2);

          final fixedValue = FixedPointValue(
              value: val, signed: signed, m: fixed.m, n: fixed.n);
          fixed.put(fixedValue);
          final fpv = dut.float.floatingPointValue;
          final roundTripFixed = FixedPointValue.ofDouble(fpv.toDouble(),
              signed: signed, m: fixed.m, n: fixed.n);
          expect(roundTripFixed, equals(fixedValue), reason: '''
          signed = $signed
          val1  = $val1
          val2  = $val2
          fpvdbl=${fpv.toDouble()} $fpv
          ${roundTripFixed.toDouble()} $roundTripFixed
          ${fixedValue.toDouble()} $fixedValue
          ${fixed.fixedPointValue.toDouble()}  ${fixed.fixedPointValue}
''');
        }
      }
    }
  });

  test('FixedToFloat: leadingDigit smoke test', () async {
    const width = 68;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    final ba = BigInt.from(0xFFFFFFE800000000).toSigned(width);
    final bb = BigInt.from(0x0000000800000000).toSigned(width);
    final av = LogicValue.ofBigInt(ba, width);
    final bv = LogicValue.ofBigInt(bb, width);
    a.put(av);
    b.put(bv);
    final tsum = a + b;

    final fixed = FixedPoint(signed: true, m: 34, n: 33);
    final fixedValue = FixedPointValue(
        value: tsum.value, signed: true, m: fixed.m, n: fixed.n);
    fixed.put(fixedValue);
    final leadingDigit = Const(32, width: log2Ceil(68) + 2);
    final dut = FixedToFloat(
      fixed,
      FloatingPoint(exponentWidth: 8, mantissaWidth: 23),
    );
    final dut2 = FixedToFloat(
      fixed,
      FloatingPoint(exponentWidth: 8, mantissaWidth: 23),
      leadingDigitPredict: leadingDigit,
    );

    final fpv = dut.float.floatingPointValue;
    final fpv2 = dut2.float.floatingPointValue;
    expect(fpv2, equals(fpv));
  });

  test('FixedToFloat: leadingDigit exhaustive', () async {
    const width = 16;

    final leadPredictIn = Logic(width: width);
    // ignore: cascade_invocations
    leadPredictIn.put(0);
    final leadZeroCounter = RecursiveModulePriorityEncoder(
        leadPredictIn.reversed,
        generateValid: true);
    final leadZeroMin1Counter = RecursiveModulePriorityEncoder(
        leadPredictIn.reversed,
        generateValid: true);

    for (final signed in [true]) {
      final fixed = FixedPoint(signed: signed, m: 8, n: 8);
      final fixedValue = FixedPointValue(
          value: LogicValue.zero.zeroExtend(width + 1),
          signed: signed,
          m: fixed.m,
          n: fixed.n);
      fixed.put(fixedValue);
      final golden = FixedToFloat(
          fixed,
          signed: signed,
          FloatingPoint(exponentWidth: 8, mantissaWidth: 16));
      final dut = FixedToFloat(
          fixed,
          signed: signed,
          FloatingPoint(exponentWidth: 8, mantissaWidth: 16),
          leadingDigitPredict: leadZeroCounter.out.zeroExtend(9));
      final dutMin1 = FixedToFloat(
          fixed,
          signed: signed,
          FloatingPoint(exponentWidth: 8, mantissaWidth: 16),
          leadingDigitPredict: leadZeroMin1Counter.out.zeroExtend(9));
      for (var val = 0; val < pow(2, fixed.width); val++) {
        final lVal = LogicValue.ofInt(val, fixed.width);
        // Use a leading one detector on both positive and negative numbers
        leadPredictIn.put(signed & !lVal[-1].isZero ? ~val : val);

        final fixedValue = FixedPointValue(
            value: lVal, signed: signed, m: fixed.m, n: fixed.n);
        fixed.put(fixedValue);

        final fpvGolden = golden.float.floatingPointValue;
        final fpv = dut.float.floatingPointValue;
        final fpv2 = dutMin1.float.floatingPointValue;

        expect(fpv, equals(fpv2), reason: '''
          val:   $val
          lead:  ${leadZeroCounter.out.value.toInt()}
          leadV: ${leadZeroCounter.valid!.value.toBool()}
          leadM1:  ${leadZeroMin1Counter.out.value.toInt()}
          leadVM1: ${leadZeroMin1Counter.valid!.value.toBool()}
          fpv:   $fpv
          fpv2:  $fpv2
''');
        expect(fpv, equals(fpvGolden), reason: '''
          val:   $val
          lead:  ${leadZeroCounter.out.value.toInt()}
          leadV: ${leadZeroCounter.valid!.value.toBool()}
          golden:  $fpvGolden
          fpv:   $fpv
          fpv2:  $fpv2
''');
      }
    }
  });

  test('Q16.16 to E5M2 < pow(2,14)', () async {
    final fixed = FixedPoint(signed: true, m: 16, n: 16);
    final dut =
        FixedToFloat(fixed, FloatingPoint(exponentWidth: 5, mantissaWidth: 2));
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
              exponentWidth: dut.float.exponent.width,
              mantissaWidth: dut.float.mantissa.width)
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
    final dut =
        FixedToFloat(fixed, FloatingPoint(exponentWidth: 3, mantissaWidth: 2));
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
              exponentWidth: dut.float.exponent.width,
              mantissaWidth: dut.float.mantissa.width)
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
    final dut =
        FixedToFloat(fixed, FloatingPoint(exponentWidth: 3, mantissaWidth: 2));
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
              exponentWidth: dut.float.exponent.width,
              mantissaWidth: dut.float.mantissa.width)
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
    final dut =
        FixedToFloat(fixed, FloatingPoint(exponentWidth: 3, mantissaWidth: 2));
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
              exponentWidth: dut.float.exponent.width,
              mantissaWidth: dut.float.mantissa.width)
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
    final dut =
        FixedToFloat(fixed, FloatingPoint(exponentWidth: 5, mantissaWidth: 6));
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
              exponentWidth: dut.float.exponent.width,
              mantissaWidth: dut.float.mantissa.width)
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
    final dut =
        FixedToFloat(fixed, FloatingPoint(exponentWidth: 3, mantissaWidth: 2));
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
              exponentWidth: dut.float.exponent.width,
              mantissaWidth: dut.float.mantissa.width)
          .ofDouble(fixedValue.toDouble());
      expect(fpv.sign, fpvExpected.sign);
      expect(fpv.exponent.bitString, fpvExpected.exponent.bitString,
          reason: 'exponent mismatch');
      expect(fpv.mantissa.bitString, fpvExpected.mantissa.bitString,
          reason: 'mantissa mismatch');
    }
  }, skip: true);
}
