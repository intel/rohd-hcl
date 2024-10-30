// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_to_float_test.dart
// Test fixed point to floating point converters.
//
// 2024 October 24
// Author: Soner Yaldiz <soner.yaldiz@intel.com>

import 'dart:io';
import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() async {
  test('Smoke', () async {
    final fixed = FixedPoint(signed: true, m: 34, n: 33);
    final dut =
        FixedToFloatConverter(fixed, exponentWidth: 8, mantissaWidth: 3);
    await dut.build();
    File('${dut.name}.sv').writeAsStringSync(dut.generateSynth());
    fixed.put(FixedPointValue.ofDouble(1.25,
        signed: fixed.signed, m: fixed.m, n: fixed.n));
    final fpv = dut.float.floatingPointValue;
    final fpvExpected = FloatingPointValue.ofDouble(1.25,
        exponentWidth: dut.exponentWidth, mantissaWidth: dut.mantissaWidth);
    expect(fpv.sign, fpvExpected.sign);
    expect(fpv.exponent.bitString, fpvExpected.exponent.bitString,
        reason: 'exponent mismatch');
    expect(fpv.mantissa.bitString, fpvExpected.mantissa.bitString,
        reason: 'mantissa mismatch');
  });

  test('Q16.16 to E5M2 < pow(2,14)', () async {
    final fixed = FixedPoint(signed: true, m: 16, n: 16);
    final dut =
        FixedToFloatConverter(fixed, exponentWidth: 5, mantissaWidth: 2);
    await dut.build();
    for (var val = 0; val < pow(2, 14); val++) {
      final fixedValue = FixedPointValue(
          value: LogicValue.ofInt(val, fixed.width),
          signed: true,
          m: fixed.m,
          n: fixed.n);
      fixed.put(fixedValue);
      final fpv = dut.float.floatingPointValue;
      final fpvExpected = FloatingPointValue.ofDouble(fixedValue.toDouble(),
          exponentWidth: dut.exponentWidth, mantissaWidth: dut.mantissaWidth);
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
        FixedToFloatConverter(fixed, exponentWidth: 3, mantissaWidth: 2);
    await dut.build();
    for (var val = 0; val < pow(2, fixed.width); val++) {
      final fixedValue = FixedPointValue(
          value: LogicValue.ofInt(val, fixed.width),
          signed: fixed.signed,
          m: fixed.m,
          n: fixed.n);
      fixed.put(fixedValue);
      final fpv = dut.float.floatingPointValue;
      final fpvExpected = FloatingPointValue.ofDouble(fixedValue.toDouble(),
          exponentWidth: dut.exponentWidth, mantissaWidth: dut.mantissaWidth);
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
        FixedToFloatConverter(fixed, exponentWidth: 3, mantissaWidth: 2);
    await dut.build();
    for (var val = 0; val < pow(2, fixed.width); val++) {
      final fixedValue = FixedPointValue(
          value: LogicValue.ofInt(val, fixed.width),
          signed: fixed.signed,
          m: fixed.m,
          n: fixed.n);
      fixed.put(fixedValue);
      final fpv = dut.float.floatingPointValue;
      final fpvExpected = FloatingPointValue.ofDouble(fixedValue.toDouble(),
          exponentWidth: dut.exponentWidth, mantissaWidth: dut.mantissaWidth);
      expect(fpv.sign, fpvExpected.sign);
      expect(fpv.exponent.bitString, fpvExpected.exponent.bitString,
          reason: 'exponent mismatch');
      expect(fpv.mantissa.bitString, fpvExpected.mantissa.bitString,
          reason: 'mantissa mismatch');
    }
  });

  // Test is skipped as FloatingPointValue.ofDouble does not handle infinities.
  test('Signed Q7.0 to E3M2', () async {
    final fixed = FixedPoint(signed: true, m: 7, n: 0);
    final dut =
        FixedToFloatConverter(fixed, exponentWidth: 3, mantissaWidth: 2);
    await dut.build();
    for (var val = 0; val < pow(2, fixed.width); val++) {
      final fixedValue = FixedPointValue(
          value: LogicValue.ofInt(val, fixed.width),
          signed: fixed.signed,
          m: fixed.m,
          n: fixed.n);
      fixed.put(fixedValue);
      final fpv = dut.float.floatingPointValue;
      final fpvExpected = FloatingPointValue.ofDouble(fixedValue.toDouble(),
          exponentWidth: dut.exponentWidth, mantissaWidth: dut.mantissaWidth);
      expect(fpv.sign, fpvExpected.sign);
      expect(fpv.exponent.bitString, fpvExpected.exponent.bitString,
          reason: 'exponent mismatch');
      expect(fpv.mantissa.bitString, fpvExpected.mantissa.bitString,
          reason: 'mantissa mismatch');
    }
  }, skip: true);

  test('Signed Q0.8 to E3M2 shrink', () async {
    final fixed = FixedPoint(signed: true, m: 0, n: 7);
    final dut =
        FixedToFloatConverter(fixed, exponentWidth: 3, mantissaWidth: 2);
    await dut.build();
    for (var val = 0; val < pow(2, fixed.width); val++) {
      final fixedValue = FixedPointValue(
          value: LogicValue.ofInt(val, fixed.width),
          signed: fixed.signed,
          m: fixed.m,
          n: fixed.n);
      fixed.put(fixedValue);
      final fpv = dut.float.floatingPointValue;
      final fpvExpected = FloatingPointValue.ofDouble(fixedValue.toDouble(),
          exponentWidth: dut.exponentWidth, mantissaWidth: dut.mantissaWidth);
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
        FixedToFloatConverter(fixed, exponentWidth: 5, mantissaWidth: 6);
    await dut.build();
    for (var val = 0; val < pow(2, fixed.width); val++) {
      final fixedValue = FixedPointValue(
          value: LogicValue.ofInt(val, fixed.width),
          signed: fixed.signed,
          m: fixed.m,
          n: fixed.n);
      fixed.put(fixedValue);
      final fpv = dut.float.floatingPointValue;
      final fpvExpected = FloatingPointValue.ofDouble(fixedValue.toDouble(),
          exponentWidth: dut.exponentWidth, mantissaWidth: dut.mantissaWidth);
      expect(fpv.sign, fpvExpected.sign);
      expect(fpv.exponent.bitString, fpvExpected.exponent.bitString,
          reason: 'exponent mismatch');
      expect(fpv.mantissa.bitString, fpvExpected.mantissa.bitString,
          reason: 'mantissa mismatch');
    }
  });

}
