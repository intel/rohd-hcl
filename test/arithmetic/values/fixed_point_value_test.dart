// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_point_value_test.dart
// Tests of fixed-point value representation
//
// 2024 September 24
// Authors:
//  Soner Yaldiz <soner.yaldiz@intel.com>

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  test('Constructor smoke', () {
    final corners = [
      // value, signed, m, n, expected width
      (LogicValue.ofInt(15, 8), true, 4, 3, 8),
      (LogicValue.ofInt(15, 7), false, 4, 3, 7),
      (LogicValue.filled(64, LogicValue.one), false, 0, 64, 64),
      (LogicValue.filled(128, LogicValue.one), false, 128, 0, 128),
    ];
    for (var c = 0; c < corners.length; c++) {
      final fxp = FixedPointValue(
          value: corners[c].$1,
          signed: corners[c].$2,
          m: corners[c].$3,
          n: corners[c].$4);
      expect(corners[c].$1, fxp.value);
      expect(fxp.signed, corners[c].$2);
      expect(fxp.value.width, corners[c].$5);
    }
  });

  test('expandWidth', () {
    final corners = [
      // value, signed, m, n, sign, m, n, result
      ('01111111', true, 4, 3, true, 4, 3, '01111111'),
      ('01111111', true, 4, 3, true, 6, 4, '00011111110'),
      ('10000111', true, 4, 3, true, 6, 4, '11100001110'),
      ('1111111', false, 4, 3, false, 6, 4, '0011111110'),
      ('0111', true, 0, 3, true, 0, 3, '0111'),
      ('0111', true, 0, 3, true, 0, 5, '011100'),
      ('0111', true, 0, 3, true, 2, 3, '000111'),
      ('1000', true, 0, 3, true, 2, 3, '111000'),
      ('0111', true, 3, 0, true, 3, 0, '0111'),
      ('0111', true, 3, 0, true, 4, 0, '00111'),
      ('0111', true, 3, 0, true, 3, 1, '01110'),
      ('1100', true, 3, 0, true, 4, 2, '1110000'),
    ];
    for (var c = 0; c < corners.length; c++) {
      final fxp = FixedPointValue(
          value: LogicValue.ofString(corners[c].$1),
          signed: corners[c].$2,
          m: corners[c].$3,
          n: corners[c].$4);
      final value = fxp.expandWidth(
          sign: corners[c].$5, m: corners[c].$6, n: corners[c].$7);
      expect(value, LogicValue.ofString(corners[c].$8),
          reason: value.bitString);
    }
  });

  test('compareTo', () {
    final corners = [
      // value, sign, m, n, value, sign, m, n, result
      // pos pos
      ('00111', true, 2, 2, '0001110', true, 3, 3, 0),
      ('00111', true, 2, 2, '0000110', true, 3, 3, greaterThan(0)),
      ('00111', true, 2, 2, '0010110', true, 3, 3, lessThan(0)),
      ('0111', false, 2, 2, '0001110', true, 3, 3, 0),
      ('0111', false, 2, 2, '0000110', true, 3, 3, greaterThan(0)),
      ('0111', false, 2, 2, '0010110', true, 3, 3, lessThan(0)),
      ('01111', true, 2, 2, '1000000', true, 3, 3, greaterThan(0)),
      ('11000', true, 2, 2, '1111000', true, 3, 3, greaterThan(0)),
      ('11110', true, 2, 2, '1111000', true, 3, 3, lessThan(0)),
      ('10000', true, 2, 2, '0111000', true, 3, 3, lessThan(0)),
    ];
    for (var c = 0; c < corners.length; c++) {
      final fxp1 = FixedPointValue(
          value: LogicValue.ofString(corners[c].$1),
          signed: corners[c].$2,
          m: corners[c].$3,
          n: corners[c].$4);
      final fxp2 = FixedPointValue(
          value: LogicValue.ofString(corners[c].$5),
          signed: corners[c].$6,
          m: corners[c].$7,
          n: corners[c].$8);
      expect(fxp1.compareTo(fxp2), corners[c].$9);
    }
  });

  test('ofDouble toDouble', () {
    final corners = [
      // value, m, n, double
      ('00000000', 4, 3, 0.0),
      ('11111111', 7, 0, -1.0),
      ('00011010', 4, 3, 3.25),
      ('11110010', 4, 3, -1.75),
      ('1000', 0, 3, -1.0),
      ('10000', 1, 3, -2.0),
      ('1100', 0, 3, -0.5),
    ];
    for (var c = 0; c < corners.length; c++) {
      final number = corners[c].$4;
      final fxp = FixedPointValue.ofDouble(number,
          signed: true, m: corners[c].$2, n: corners[c].$3);
      expect(fxp.value.bitString, corners[c].$1);
      expect(fxp.toDouble(), number);
    }
    corners
      ..clear()
      ..addAll([
        // value, m, n, double
        ('00000000', 5, 3, 0.0),
        ('00001001', 5, 3, 1.125),
        ('11111111', 5, 3, 31.875),
        ('11111111', 8, 0, pow(2, 8).toDouble() - 1),
      ]);
    for (var c = 0; c < corners.length; c++) {
      final number = corners[c].$4;
      final fxp = FixedPointValue.ofDouble(number,
          signed: false, m: corners[c].$2, n: corners[c].$3);
      expect(fxp.value.bitString, corners[c].$1);
      expect(fxp.toDouble(), number);
    }
    // Exhaustive unsigned
    for (var i = 0; i < pow(2, 4); i++) {
      for (var m = 0; m < 5; m++) {
        final n = 4 - m;
        final fxp = FixedPointValue(
            value: LogicValue.ofInt(i, 4), signed: false, m: m, n: n);
        expect(fxp.value.width, 4);
        expect(fxp.toDouble(), i / pow(2, n));
      }
    }
  });

  test('Comparison operators', () {
    expect(
        FixedPointValue.ofDouble(14.432, signed: false, m: 4, n: 2)
            .eq(FixedPointValue.ofDouble(14.432, signed: false, m: 4, n: 2)),
        LogicValue.one);
    expect(
        FixedPointValue.ofDouble(14.432, signed: false, m: 4, n: 2)
            .neq(FixedPointValue.ofDouble(14.432, signed: false, m: 4, n: 2)),
        LogicValue.zero);
    expect(
        FixedPointValue.ofDouble(13.454, signed: false, m: 4, n: 2) >
            (FixedPointValue.ofDouble(14, signed: false, m: 4, n: 2)),
        LogicValue.zero);
    expect(
        FixedPointValue.ofDouble(13.454, signed: false, m: 4, n: 2) >=
            (FixedPointValue.ofDouble(14, signed: false, m: 4, n: 2)),
        LogicValue.zero);
    expect(
        FixedPointValue.ofDouble(13.454, signed: false, m: 4, n: 2) <
            (FixedPointValue.ofDouble(14, signed: false, m: 4, n: 2)),
        LogicValue.one);
    expect(
        FixedPointValue.ofDouble(13.454, signed: false, m: 4, n: 2) <=
            (FixedPointValue.ofDouble(14, signed: false, m: 4, n: 2)),
        LogicValue.one);
    expect(
        FixedPointValue.ofDouble(14, signed: false, m: 4, n: 2) <=
            (FixedPointValue.ofDouble(14, signed: false, m: 4, n: 2)),
        LogicValue.one);
    expect(
        FixedPointValue.ofDouble(14, signed: false, m: 4, n: 2) >=
            (FixedPointValue.ofDouble(14, signed: false, m: 4, n: 2)),
        LogicValue.one);
  });

  test('Math', () {
    const w = 4;
    FixedPointValue fxp;
    FixedPointValue fxp1;
    FixedPointValue fxp2;
    for (var i1 = 0; i1 < pow(2, w); i1++) {
      for (var i2 = 1; i2 < pow(2, w); i2++) {
        for (var m1 = 0; m1 < w; m1++) {
          for (var m2 = 0; m2 < w; m2++) {
            final n1 = w - 1 - m1;
            final n2 = w - 1 - m2;
            fxp1 = FixedPointValue(
                value: LogicValue.ofInt(i1, w), signed: true, m: m1, n: n1);
            fxp2 = FixedPointValue(
                value: LogicValue.ofInt(i2, w), signed: true, m: m2, n: n2);

            // add
            fxp = fxp1 + fxp2;
            expect(fxp.toDouble(), fxp1.toDouble() + fxp2.toDouble(),
                reason: '+');
            expect(fxp.n, max(n1, n2));

            // subtract
            fxp = fxp1 - fxp2;
            expect(fxp.toDouble(), fxp1.toDouble() - fxp2.toDouble(),
                reason: '-');
            expect(fxp.n, max(n1, n2));

            // multiply
            fxp = fxp1 * fxp2;
            expect(fxp.toDouble(), fxp1.toDouble() * fxp2.toDouble(),
                reason: '${fxp1.toDouble()}*${fxp2.toDouble()}');
            expect(fxp.n, n1 + n2);

            // divide
            fxp = fxp1 / fxp2;
            final q = n1 + m2 + 1;
            double expectedValue;
            if (i1 == 0) {
              expectedValue = 0;
            } else {
              expectedValue =
                  ((fxp1.toDouble() / fxp2.toDouble()).abs() * pow(2, q))
                          .floor() /
                      pow(2, q);
              if (fxp1.toDouble() / fxp2.toDouble() < 0) {
                expectedValue = -expectedValue;
              }
            }
            expect(fxp.toDouble(), expectedValue,
                reason:
                    '${fxp1.toDouble()}/${fxp2.toDouble()} = $expectedValue');
          }
        }
      }
    }
  });
}
