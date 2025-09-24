// Copyright (C) 2024-2025 Intel Corporation
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
      final pop = FixedPointValue.populator(
          integerWidth: corners[c].$3,
          fractionWidth: corners[c].$4,
          signed: corners[c].$2);
      final fxp = pop.ofLogicValue(corners[c].$1);
      expect(fxp.value.width, corners[c].$5);
      expect(corners[c].$1, fxp.value);
      expect(fxp.signed, corners[c].$2);
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
      final fxp = FixedPointValue.populator(
              integerWidth: corners[c].$3,
              fractionWidth: corners[c].$4,
              signed: corners[c].$2)
          .ofLogicValue(LogicValue.ofString(corners[c].$1));

      final value = FixedPointValue.populator(
              integerWidth: corners[c].$6,
              fractionWidth: corners[c].$7,
              signed: corners[c].$5)
          .widen(fxp)
          .value;

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
      final fxp1 = FixedPointValue.populator(
              integerWidth: corners[c].$3,
              fractionWidth: corners[c].$4,
              signed: corners[c].$2)
          .ofLogicValue(LogicValue.ofString(corners[c].$1));
      final fxp2 = FixedPointValue.populator(
              integerWidth: corners[c].$7,
              fractionWidth: corners[c].$8,
              signed: corners[c].$6)
          .ofLogicValue(LogicValue.ofString(corners[c].$5));
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
      final fxp = FixedPointValue.populator(
              integerWidth: corners[c].$2,
              fractionWidth: corners[c].$3,
              signed: true)
          .ofDouble(number);

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
      final fxp = FixedPointValue.populator(
              integerWidth: corners[c].$2, fractionWidth: corners[c].$3)
          .ofDouble(number);
      expect(fxp.value.bitString, corners[c].$1);
      expect(fxp.toDouble(), number);
    }
    // Exhaustive unsigned
    for (var i = 0; i < pow(2, 4); i++) {
      for (var m = 0; m < 5; m++) {
        final n = 4 - m;
        final fxp = FixedPointValue.populator(integerWidth: m, fractionWidth: n)
            .ofLogicValue(LogicValue.ofInt(i, 4));
        expect(fxp.value.width, 4);
        expect(fxp.toDouble(), i / pow(2, n));
      }
    }
  });

  test('Comparison operators', () {
    FixedPointValuePopulator populator({bool signed = false}) =>
        FixedPointValue.populator(
            integerWidth: 4, fractionWidth: 2, signed: signed);
    expect(
        populator(signed: true).ofDouble(14.432) ==
            populator().ofDouble(14.432),
        true);
    expect(populator().ofDouble(14.432) != populator().ofDouble(14.432), false);
    expect(
        populator().ofDouble(13.454).gtBool(populator().ofDouble(14)), false);
    expect(
        populator().ofDouble(13.454).gteBool(populator().ofDouble(14)), false);
    expect(populator().ofDouble(13.454).ltBool(populator().ofDouble(14)), true);
    expect(
        populator().ofDouble(13.454).lteBool(populator().ofDouble(14)), true);
    expect(populator().ofDouble(14).lteBool(populator().ofDouble(14)), true);
    expect(populator().ofDouble(14).gteBool(populator().ofDouble(14)), true);
  });

  test('FixedPointValue: exhaustive double round-trip', () {
    const width = 8;
    const m = 3;
    const n = 4;
    for (var i = 0; i < pow(2, width); i++) {
      final fxv = FixedPointValue.populator(integerWidth: m, fractionWidth: n)
          .ofLogicValue(LogicValue.ofInt(i, width));
      final dbl = fxv.toDouble();
      if (!FixedPointValuePopulator.canStore(dbl,
          signed: fxv.signed,
          integerWidth: fxv.integerWidth,
          fractionWidth: fxv.fractionWidth)) {
        throw RohdHclException('generated a value that we cannot store');
      }
      final fxv2 = FixedPointValue.populator(
              integerWidth: m, fractionWidth: n, signed: true)
          .ofDouble(dbl);

      expect(fxv, equals(fxv2));
    }
  });

  test('FixedPointValue: random double round-trip', () {
    const m = 4;
    const n = 2;
    final rv = Random(57);
    for (final signed in [false, true]) {
      final lowerBound = FixedPointValue.populator(
              signed: signed, integerWidth: m, fractionWidth: n)
          .ofDouble(0);
      final upperBound = FixedPointValue.populator(
              signed: signed, integerWidth: m, fractionWidth: n)
          .ofDouble(0.5);
      for (var i = 0; i < 1000; i++) {
        final fxv = FixedPointValue.populator(
                signed: signed, integerWidth: m, fractionWidth: n)
            .random(rv, gt: lowerBound, lt: upperBound);
        final dbl = fxv.toDouble();
        expect(dbl > lowerBound.toDouble(), isTrue);
        expect(dbl < upperBound.toDouble(), isTrue);
      }
      for (var i = 0; i < 1000; i++) {
        final fxv = FixedPointValue.populator(
                signed: signed, integerWidth: m, fractionWidth: n)
            .random(rv, gte: lowerBound, lte: upperBound);
        expect(fxv.gteBool(lowerBound), isTrue);
        expect(fxv.lteBool(upperBound), isTrue);
      }
    }
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
            for (var s1 = 0; s1 < 2; s1++) {
              for (var s2 = 0; s2 < 2; s2++) {
                final n1 = s1 == 0 ? w - m1 - 1 : w - m1;
                final n2 = s2 == 0 ? w - m2 - 1 : w - m2;
                fxp1 = FixedPointValue.populator(
                        integerWidth: m1, fractionWidth: n1, signed: s1 == 0)
                    .ofLogicValue(LogicValue.ofInt(i1, w));

                fxp2 = FixedPointValue.populator(
                        integerWidth: m2, fractionWidth: n2, signed: s2 == 0)
                    .ofLogicValue(LogicValue.ofInt(i2, w));

                // add
                fxp = fxp1 + fxp2;
                expect(fxp.toDouble(), fxp1.toDouble() + fxp2.toDouble(),
                    reason: '+');
                expect(fxp.fractionWidth, max(n1, n2));
                expect(fxp.integerWidth, max(m1, m2) + 1);

                // subtract
                fxp = fxp1 - fxp2;
                expect(fxp.toDouble(), fxp1.toDouble() - fxp2.toDouble(),
                    reason: '-');
                expect(fxp.fractionWidth, max(n1, n2));
                expect(fxp.integerWidth, max(m1, m2) + 1);

                // multiply
                fxp = fxp1 * fxp2;
                expect(fxp.toDouble(), fxp1.toDouble() * fxp2.toDouble(),
                    reason: '${fxp1.toDouble()}*${fxp2.toDouble()}');
                expect(fxp.fractionWidth, n1 + n2);
                expect(fxp.integerWidth, s1 + s2 == 2 ? m1 + m2 : m1 + m2 + 1);

                // divide
                fxp = fxp1 / fxp2;
                final q = s1 + s2 == 2 ? n1 + m2 : n1 + m2 + 1;
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
      }
    }
  });
}
