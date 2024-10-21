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
    const signStr = '0';
    const exponentWidth = 4;
    const mantissaWidth = 4;
    var exponent = LogicValue.zero.zeroExtend(exponentWidth);
    var mantissa = LogicValue.zero.zeroExtend(mantissaWidth);
    for (var k = 0; k < pow(2.0, exponentWidth).toInt() - 1; k++) {
      final expStr = exponent.bitString;
      for (var i = 0; i < pow(2.0, mantissaWidth).toInt(); i++) {
        final mantStr = mantissa.bitString;
        final fp = FloatingPointValue.ofBinaryStrings(signStr, expStr, mantStr);
        final dbl = fp.toDouble();
        final fp2 = FloatingPointValue.fromDouble(dbl,
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
        final fp2 = FloatingPointValue.fromDouble(fp.toDouble(),
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
          final fp2 = FloatingPointValue.fromDoubleIter(fp.toDouble(),
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
      final fp2 = FloatingPoint32Value.fromDouble(fp.toDouble());
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
      final fp2 = FloatingPoint64Value.fromDouble(fp.toDouble());
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
      final fp = FloatingPoint32Value.fromDouble(val);
      assert(val == fp.toDouble(), 'mismatch');
      expect(fp.toDouble(), val);
      final fpSuper = FloatingPointValue.fromDouble(val,
          exponentWidth: 8, mantissaWidth: 23);
      assert(val == fpSuper.toDouble(), 'mismatch');
      expect(fpSuper.toDouble(), val);
    }
  });

  test('FPV: simple 64', () {
    final values = [0.15625, 12.375, -1.0, 0.25, 0.375];
    for (final val in values) {
      final fp = FloatingPoint64Value.fromDouble(val);
      assert(val == fp.toDouble(), 'mismatch');
      expect(fp.toDouble(), val);
      final fpSuper = FloatingPointValue.fromDouble(val,
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
      final fp = FloatingPointValue.fromDouble(val,
          exponentWidth: 4, mantissaWidth: 3);
      expect(val, fp.toDouble());
      expect(str, fp.toString());
      final fp8 = FloatingPoint8E4M3Value.fromDouble(val);
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
      final fp = FloatingPointValue.fromDouble(val,
          exponentWidth: 5, mantissaWidth: 2);
      expect(val, fp.toDouble());
      expect(str, fp.toString());
      final fp8 = FloatingPoint8E5M2Value.fromDouble(val);
      expect(val, fp8.toDouble());
      expect(str, fp8.toString());
    }
  });

  test('FPV: setting and getting from a signal', () {
    final fp = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(1.5).value);
    expect(fp.floatingPointValue.toDouble(), 1.5);
    final fp2 = FloatingPoint64()
      ..put(FloatingPoint64Value.fromDouble(1.5).value);
    expect(fp2.floatingPointValue.toDouble(), 1.5);
    final fp8e4m3 = FloatingPoint8E4M3(exponentWidth: 4)
      ..put(FloatingPoint8E4M3Value.fromDouble(1.5).value);
    expect(fp8e4m3.floatingPointValue.toDouble(), 1.5);
    final fp8e5m2 = FloatingPoint8E5M2(exponentWidth: 5)
      ..put(FloatingPoint8E5M2Value.fromDouble(1.5).value);
    expect(fp8e5m2.floatingPointValue.toDouble(), 1.5);
  });

  test('FPV: round nearest even Guard and Sticky', () {
    final fp64 = FloatingPoint64Value.ofBinaryStrings('0', '10000000000',
        '0000100000000000000000000000000000000000000000000001');

    final fpRound = FloatingPointValue.ofBinaryStrings('0', '1000', '0001');
    final val = fp64.toDouble();
    final fpConvert =
        FloatingPointValue.fromDouble(val, exponentWidth: 4, mantissaWidth: 4);
    expect(fpConvert, equals(fpRound));
  });
  test('FPV: round nearest even Guard and Round', () {
    final fp64 = FloatingPoint64Value.ofBinaryStrings('0', '10000000000',
        '0000110000000000000000000000000000000000000000000000');

    final fpRound = FloatingPointValue.ofBinaryStrings('0', '1000', '0001');
    final val = fp64.toDouble();

    final fpConvert =
        FloatingPointValue.fromDouble(val, exponentWidth: 4, mantissaWidth: 4);
    expect(fpConvert, equals(fpRound));
  });
  test('FPV: rounding nearest even increment', () {
    final fp64 = FloatingPoint64Value.ofBinaryStrings('0', '10000000000',
        '0001100000000000000000000000000000000000000000000000');

    final fpRound = FloatingPointValue.ofBinaryStrings('0', '1000', '0010');
    final val = fp64.toDouble();
    final fpConvert =
        FloatingPointValue.fromDouble(val, exponentWidth: 4, mantissaWidth: 4);
    expect(fpConvert, equals(fpRound));
  });
  test('FPV: rounding nearest even increment carry into exponent', () {
    final fp64 = FloatingPoint64Value.ofBinaryStrings('0', '10000000000',
        '1111100000000000000000000000000000000000000000000000');

    final fpRound = FloatingPointValue.ofBinaryStrings('0', '1001', '0000');
    final val = fp64.toDouble();
    final fpConvert =
        FloatingPointValue.fromDouble(val, exponentWidth: 4, mantissaWidth: 4);
    expect(fpConvert, equals(fpRound));
  });
  test('FPV: rounding nearest even truncate', () {
    final fp64 = FloatingPoint64Value.ofBinaryStrings('0', '10000000000',
        '0010100000000000000000000000000000000000000000000000');

    final fpTrunc = FloatingPointValue.ofBinaryStrings('0', '1000', '0010');
    final val = fp64.toDouble();
    final fpConvert =
        FloatingPointValue.fromDouble(val, exponentWidth: 4, mantissaWidth: 4);
    expect(fpConvert, equals(fpTrunc));
  });
}
