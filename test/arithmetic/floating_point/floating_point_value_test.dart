// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_test.dart
// Tests of Floating Point value stuff
//
// 2024 April 1
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com
//

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  test('FPV: exhaustive round-trip', () {
    const exponentWidth = 4;
    const mantissaWidth = 4;
    for (final signStr in ['0', '1']) {
      var exponent = LogicValue.zero.zeroExtend(exponentWidth);
      var mantissa = LogicValue.zero.zeroExtend(mantissaWidth);
      for (var k = 0; k < pow(2.0, exponentWidth).toInt() - 1; k++) {
        final expStr = exponent.bitString;
        for (var i = 0; i < pow(2.0, mantissaWidth).toInt(); i++) {
          final mantStr = mantissa.bitString;
          final fp =
              FloatingPointValue.ofBinaryStrings(signStr, expStr, mantStr);
          final dbl = fp.toDouble();
          final fp2 = FloatingPointValue.ofDouble(dbl,
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
          if (fp != fp2) {
            if (fp.isNaN() != fp2.isNaN()) {
              expect(fp, equals(fp2));
            }
          }
          mantissa = mantissa + 1;
        }
        exponent = exponent + 1;
      }
    }
  });

  test('FPV: direct subnormal conversion', () {
    const signStr = '0';
    for (final (exponentWidth, mantissaWidth) in [(8, 23), (11, 52)]) {
      final expStr = '0' * exponentWidth;
      final mantissa = LogicValue.one.zeroExtend(mantissaWidth);
      for (var i = 0; i < mantissaWidth; i++) {
        final mantStr = (mantissa << i).bitString;
        final fp = FloatingPointValue.ofBinaryStrings(signStr, expStr, mantStr);
        expect(fp.toString(), '$signStr $expStr $mantStr');
        final fp2 = FloatingPointValue.ofDouble(fp.toDouble(),
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
        expect(fp2, equals(fp));
      }
    }
  });

  test('FPV: indirect subnormal conversion no rounding', () {
    const signStr = '0';
    for (var exponentWidth = 2; exponentWidth < 12; exponentWidth++) {
      for (var mantissaWidth = 2; mantissaWidth < 53; mantissaWidth++) {
        final expStr = '0' * exponentWidth;
        final mantissa = LogicValue.one.zeroExtend(mantissaWidth);
        for (var i = 0; i < mantissaWidth; i++) {
          final mantStr = (mantissa << i).bitString;
          final fp =
              FloatingPointValue.ofBinaryStrings(signStr, expStr, mantStr);
          expect(fp.toString(), '$signStr $expStr $mantStr');
          final fp2 = FloatingPointValue.ofDoubleUnrounded(fp.toDouble(),
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
          expect(fp2, equals(fp));
        }
      }
    }
  });

  test('FPV: round trip 32', () {
    final values = [
      FloatingPoint32Value.getFloatingPointConstant(
          FloatingPointConstants.largestPositiveSubnormal),
      FloatingPoint32Value.getFloatingPointConstant(
          FloatingPointConstants.smallestPositiveSubnormal),
      FloatingPoint32Value.getFloatingPointConstant(
          FloatingPointConstants.smallestPositiveNormal),
      FloatingPoint32Value.getFloatingPointConstant(
          FloatingPointConstants.largestLessThanOne),
      FloatingPoint32Value.getFloatingPointConstant(FloatingPointConstants.one),
      FloatingPoint32Value.getFloatingPointConstant(
          FloatingPointConstants.smallestLargerThanOne),
      FloatingPoint32Value.getFloatingPointConstant(
          FloatingPointConstants.largestNormal)
    ];
    for (final fp in values) {
      final fp2 = FloatingPoint32Value.ofDouble(fp.toDouble());
      expect(fp2, equals(fp));
    }
  });

  test('FPV: round trip 64', () {
    final values = [
      FloatingPoint64Value.getFloatingPointConstant(
          FloatingPointConstants.largestPositiveSubnormal),
      FloatingPoint64Value.getFloatingPointConstant(
          FloatingPointConstants.smallestPositiveSubnormal),
      FloatingPoint64Value.getFloatingPointConstant(
          FloatingPointConstants.smallestPositiveNormal),
      FloatingPoint64Value.getFloatingPointConstant(
          FloatingPointConstants.largestLessThanOne),
      FloatingPoint64Value.getFloatingPointConstant(FloatingPointConstants.one),
      FloatingPoint64Value.getFloatingPointConstant(
          FloatingPointConstants.smallestLargerThanOne),
      FloatingPoint64Value.getFloatingPointConstant(
          FloatingPointConstants.largestNormal)
    ];
    for (final fp in values) {
      final fp2 = FloatingPoint64Value.ofDouble(fp.toDouble());
      expect(fp2, equals(fp));
    }
  });

  test('FloatingPointValue string conversion', () {
    const str = '0 10000001 01000100000000000000000'; // 5.0625
    final fp = FloatingPoint32Value.ofSpacedBinaryString(str);
    expect(fp.toString(), str);
    expect(fp.toDouble(), 5.0625);
  });

  test('FPV: simple 32', () {
    final values = [0.15625, 12.375, -1.0, 0.25, 0.375];
    for (final val in values) {
      final fp = FloatingPoint32Value.ofDouble(val);
      assert(val == fp.toDouble(), 'mismatch');
      expect(fp.toDouble(), val);
      final fpSuper =
          FloatingPointValue.ofDouble(val, exponentWidth: 8, mantissaWidth: 23);
      assert(val == fpSuper.toDouble(), 'mismatch');
      expect(fpSuper.toDouble(), val);
    }
  });

  test('FPV: simple 64', () {
    final values = [0.15625, 12.375, -1.0, 0.25, 0.375];
    for (final val in values) {
      final fp = FloatingPoint64Value.ofDouble(val);
      assert(val == fp.toDouble(), 'mismatch');
      expect(fp.toDouble(), val);
      final fpSuper = FloatingPointValue.ofDouble(val,
          exponentWidth: 11, mantissaWidth: 52);
      assert(val == fpSuper.toDouble(), 'mismatch');
      expect(fpSuper.toDouble(), val);
    }
  });

  test('FPV: E4M3', () {
    final corners = [
      ['0 0000 000', 0.toDouble()],
      ['0 1111 110', 448.toDouble()],
      ['0 0001 000', pow(2, -6).toDouble()],
      ['0 0000 111', 0.875 * pow(2, -6).toDouble()],
      ['0 0000 001', pow(2, -9).toDouble()],
    ];
    for (var c = 0; c < corners.length; c++) {
      final val = corners[c][1] as double;
      final str = corners[c][0] as String;

      final fp8 = FloatingPoint8E4M3Value.ofDouble(val);
      expect(val, fp8.toDouble());
      expect(str, fp8.toString());
    }
  });

  test('FPV8: E5M2', () {
    final corners = [
      ['0 00000 00', 0.toDouble()],
      ['0 11110 11', 57344.toDouble()],
      ['0 00001 00', pow(2, -14).toDouble()],
      ['0 00000 11', 0.75 * pow(2, -14).toDouble()],
      ['0 00000 01', pow(2, -16).toDouble()],
    ];
    for (var c = 0; c < corners.length; c++) {
      final val = corners[c][1] as double;
      final str = corners[c][0] as String;
      final fp =
          FloatingPointValue.ofDouble(val, exponentWidth: 5, mantissaWidth: 2);
      expect(val, fp.toDouble());
      expect(str, fp.toString());
      final fp8 = FloatingPoint8E5M2Value.ofDouble(val);
      expect(val, fp8.toDouble());
      expect(str, fp8.toString());
    }
  });

  test('FPV: setting and getting from a signal', () {
    final fp = FloatingPoint32()..put(FloatingPoint32Value.ofDouble(1.5).value);
    expect(fp.floatingPointValue.toDouble(), 1.5);
    final fp2 = FloatingPoint64()
      ..put(FloatingPoint64Value.ofDouble(1.5).value);
    expect(fp2.floatingPointValue.toDouble(), 1.5);
    final fp8e4m3 = FloatingPoint8E4M3()
      ..put(FloatingPoint8E4M3Value.ofDouble(1.5).value);
    expect(fp8e4m3.floatingPointValue.toDouble(), 1.5);
    final fp8e5m2 = FloatingPoint8E5M2()
      ..put(FloatingPoint8E5M2Value.ofDouble(1.5).value);
    expect(fp8e5m2.floatingPointValue.toDouble(), 1.5);
  });

  test('FPV: round nearest even Guard and Sticky', () {
    final fp64 = FloatingPoint64Value.ofBinaryStrings('0', '10000000000',
        '0000100000000000000000000000000000000000000000000001');

    final fpRound = FloatingPointValue.ofBinaryStrings('0', '1000', '0001');
    final val = fp64.toDouble();
    final fpConvert =
        FloatingPointValue.ofDouble(val, exponentWidth: 4, mantissaWidth: 4);
    expect(fpConvert, equals(fpRound));
  });

  test('FPV: round nearest even Guard and Round', () {
    final fp64 = FloatingPoint64Value.ofBinaryStrings('0', '10000000000',
        '0000110000000000000000000000000000000000000000000000');

    final fpRound = FloatingPointValue.ofBinaryStrings('0', '1000', '0001');
    final val = fp64.toDouble();

    final fpConvert =
        FloatingPointValue.ofDouble(val, exponentWidth: 4, mantissaWidth: 4);
    expect(fpConvert, equals(fpRound));
  });

  test('FPV: rounding nearest even increment', () {
    final fp64 = FloatingPoint64Value.ofBinaryStrings('0', '10000000000',
        '0001100000000000000000000000000000000000000000000000');

    final fpRound = FloatingPointValue.ofBinaryStrings('0', '1000', '0010');
    final val = fp64.toDouble();
    final fpConvert =
        FloatingPointValue.ofDouble(val, exponentWidth: 4, mantissaWidth: 4);
    expect(fpConvert, equals(fpRound));
  });

  test('FPV: rounding nearest even increment carry into exponent', () {
    final fp64 = FloatingPoint64Value.ofBinaryStrings('0', '10000000000',
        '1111100000000000000000000000000000000000000000000000');

    final fpRound = FloatingPointValue.ofBinaryStrings('0', '1001', '0000');
    final val = fp64.toDouble();
    final fpConvert =
        FloatingPointValue.ofDouble(val, exponentWidth: 4, mantissaWidth: 4);
    expect(fpConvert, equals(fpRound));
  });

  test('FPV: rounding nearest even truncate', () {
    final fp64 = FloatingPoint64Value.ofBinaryStrings('0', '10000000000',
        '0010100000000000000000000000000000000000000000000000');

    final fpTrunc = FloatingPointValue.ofBinaryStrings('0', '1000', '0010');
    final val = fp64.toDouble();
    final fpConvert =
        FloatingPointValue.ofDouble(val, exponentWidth: 4, mantissaWidth: 4);
    expect(fpConvert, equals(fpTrunc));
  });

  test('mapped subtype constructor', () {
    final fp = FloatingPointValue.withMappedSubtype(
      sign: LogicValue.zero,
      exponent: LogicValue.ofString('10101'),
      mantissa: LogicValue.ofString('10'),
    );

    expect(fp, isA<FloatingPoint8E5M2Value>());
  });

  test('mapped subtype conversion', () {
    final fp = FloatingPointValue(
      sign: LogicValue.zero,
      exponent: LogicValue.ofString('10101'),
      mantissa: LogicValue.ofString('10'),
    );

    expect(fp, isNot(isA<FloatingPoint8E5M2Value>()));
    expect(fp.toMappedSubtype(), isA<FloatingPoint8E5M2Value>());
  });

  test('Initializing derived type', () {
    final fp = FloatingPoint16Value.ofInts(15, 0);
    final s = fp.toString();
    final fp2 = FloatingPoint16Value.ofSpacedBinaryString(s);
    expect(fp, equals(fp2));
  });

  test('Initializing derived type', () {
    final fp = FloatingPoint16Value.ofInts(15, 0);
    final s = fp.toString();
    final fp2 = FloatingPoint16Value.ofSpacedBinaryString(s);
    expect(fp, equals(fp2));
  });
  test('FPV Value comparison', () {
    final fp = FloatingPointValue.ofSpacedBinaryString('1 0101 0101');
    expect(fp.compareTo(FloatingPointValue.ofSpacedBinaryString('1 0101 0101')),
        0);
    expect(fp.compareTo(FloatingPointValue.ofSpacedBinaryString('1 0100 0101')),
        lessThan(0));
    expect(fp.compareTo(FloatingPointValue.ofSpacedBinaryString('1 0101 0100')),
        lessThan(0));

    final fp2 = FloatingPointValue.ofSpacedBinaryString('1 0000 0000');
    expect(
        fp2.compareTo(FloatingPointValue.ofSpacedBinaryString('0 0000 0000')),
        equals(0));
  });
  test('FPV: infinity/NaN conversion tests', () async {
    const exponentWidth = 4;
    const mantissaWidth = 4;
    final infinity = FloatingPointValue.getFloatingPointConstant(
        FloatingPointConstants.infinity, exponentWidth, mantissaWidth);
    final negativeInfinity = FloatingPointValue.getFloatingPointConstant(
        FloatingPointConstants.negativeInfinity, exponentWidth, mantissaWidth);

    final tooLargeNumber = FloatingPointValue.ofDouble(257,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

    expect(infinity.toDouble(), equals(double.infinity));
    expect(negativeInfinity.toDouble(), equals(double.negativeInfinity));

    expect(tooLargeNumber.toDouble(), equals(double.infinity));

    expect(tooLargeNumber.negate().toDouble(), equals(double.negativeInfinity));

    expect(
        FloatingPointValue.getFloatingPointConstant(
                FloatingPointConstants.nan, exponentWidth, mantissaWidth)
            .toDouble()
            .isNaN,
        equals(true));
  });
  test('FPV: infinity/NaN unrounded conversion tests', () async {
    const exponentWidth = 4;
    const mantissaWidth = 4;
    final infinity = FloatingPointValue.ofDoubleUnrounded(double.infinity,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final negativeInfinity = FloatingPointValue.ofDoubleUnrounded(
        double.negativeInfinity,
        exponentWidth: exponentWidth,
        mantissaWidth: mantissaWidth);
    final tooLargeNumber = FloatingPointValue.ofDoubleUnrounded(257,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    expect(tooLargeNumber.toDouble(), equals(double.infinity));
    expect(infinity.toDouble(), equals(double.infinity));
    expect(tooLargeNumber.negate().toDouble(), equals(double.negativeInfinity));
    expect(negativeInfinity.toDouble(), equals(double.negativeInfinity));
  });

  test('FPV: infinity operation tests', () {
    const exponentWidth = 4;
    const mantissaWidth = 4;
    final one = FloatingPointValue.getFloatingPointConstant(
        FloatingPointConstants.one, exponentWidth, mantissaWidth);
    final zero = FloatingPointValue.getFloatingPointConstant(
        FloatingPointConstants.positiveZero, exponentWidth, mantissaWidth);
    final infinity = FloatingPointValue.getFloatingPointConstant(
        FloatingPointConstants.infinity, exponentWidth, mantissaWidth);
    final negativeInfinity = FloatingPointValue.getFloatingPointConstant(
        FloatingPointConstants.negativeInfinity, exponentWidth, mantissaWidth);

    for (final f in [infinity, negativeInfinity]) {
      for (final s in [infinity, negativeInfinity]) {
        // Addition
        if (f == s) {
          expect((f + s).toDouble(), equals(f.toDouble() + s.toDouble()));
        } else {
          expect((f + s).toDouble().isNaN,
              equals((f.toDouble() + s.toDouble()).isNaN));
        }
        // Subtraction
        if (f != s) {
          expect((f - s).toDouble(), equals(f.toDouble()));
        } else {
          expect((f - s).toDouble().isNaN,
              equals((f.toDouble() - s.toDouble()).isNaN));
        }
        // Multiplication
        expect((f * s).toDouble(), equals(f.toDouble() * s.toDouble()));
        // Division
        expect((f / s).toDouble().isNaN,
            equals((f.toDouble() / s.toDouble()).isNaN));
      }
    }
    for (final f in [infinity, negativeInfinity]) {
      for (final s in [zero, one]) {
        // Addition
        expect((f + s).toDouble(), equals(f.toDouble() + s.toDouble()));
        // Subtraction
        expect((f - s).toDouble(), equals(f.toDouble()));
        expect((s - f).toDouble(), equals(-f.toDouble()));
        // Multiplication
        if (s == zero) {
          expect((f * s).toDouble().isNaN,
              equals((f.toDouble() * s.toDouble()).isNaN));
        } else {
          expect((f * s).toDouble(), equals(f.toDouble()));
        }
        // Division
        if (s == zero) {
          expect((f / s).toDouble().isNaN,
              equals((f.toDouble() * s.toDouble()).isNaN));
        } else {
          expect((f / s).toDouble(), equals(f.toDouble()));
        }
      }
    }
  });
}
