// Copyright (C) 2024-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
// ignore_for_file: deprecated_member_use_from_same_package
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
  void expectSameDyadic(({BigInt significand, int exponent}) actual,
      ({BigInt significand, int exponent}) expected,
      {String? reason}) {
    final commonExponent = min(actual.exponent, expected.exponent);
    expect(actual.significand << (actual.exponent - commonExponent),
        expected.significand << (expected.exponent - commonExponent),
        reason: reason);
  }

  test('FixedPointValue: legacy and replacement signed defaults', () {
    expect(FixedPoint(integerWidth: 3, fractionWidth: 2).signed, isTrue);
    expect(FixedPointValue.populator(integerWidth: 3, fractionWidth: 2).signed,
        isFalse);
    expect(
        FixedPointValue.populatorWithSignedness(
                integerWidth: 3, fractionWidth: 2)
            .signed,
        isTrue);
    expect(
        FixedPointValue(
                integer: LogicValue.ofInt(3, 4),
                fraction: LogicValue.ofInt(0, 2))
            .signed,
        isFalse);
    expect(
        FixedPointValue.withSignedness(
                integer: LogicValue.ofInt(3, 4),
                fraction: LogicValue.ofInt(0, 2))
            .signed,
        isTrue);
  });

  test('FixedPointValue: factory constructor honors the signed argument', () {
    final signedValue = FixedPointValue.withSignedness(
        integer: LogicValue.ofInt(3, 4), fraction: LogicValue.ofInt(0, 2));
    expect(signedValue.signed, isTrue);
    expect(signedValue.integerWidth, 3);

    final unsignedValue = FixedPointValue.withSignedness(
        integer: LogicValue.ofInt(3, 4),
        fraction: LogicValue.ofInt(0, 2),
        signed: false);
    expect(unsignedValue.signed, isFalse);
    expect(unsignedValue.integerWidth, 4);
  });

  test('Constructor smoke', () {
    final corners = [
      // value, signed, m, n, expected width
      (LogicValue.ofInt(15, 8), true, 4, 3, 8),
      (LogicValue.ofInt(15, 7), false, 4, 3, 7),
      (LogicValue.filled(64, LogicValue.one), false, 0, 64, 64),
      (LogicValue.filled(128, LogicValue.one), false, 128, 0, 128),
    ];
    for (var c = 0; c < corners.length; c++) {
      final pop = FixedPointValue.populatorWithSignedness(
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
      final fxp = FixedPointValue.populatorWithSignedness(
              integerWidth: corners[c].$3,
              fractionWidth: corners[c].$4,
              signed: corners[c].$2)
          .ofLogicValue(LogicValue.ofString(corners[c].$1));

      final value = FixedPointValue.populatorWithSignedness(
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
      final fxp1 = FixedPointValue.populatorWithSignedness(
              integerWidth: corners[c].$3,
              fractionWidth: corners[c].$4,
              signed: corners[c].$2)
          .ofLogicValue(LogicValue.ofString(corners[c].$1));
      final fxp2 = FixedPointValue.populatorWithSignedness(
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
      final fxp = FixedPointValue.populatorWithSignedness(
              integerWidth: corners[c].$2, fractionWidth: corners[c].$3)
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
      final fxp = FixedPointValue.populatorWithSignedness(
              integerWidth: corners[c].$2,
              fractionWidth: corners[c].$3,
              signed: false)
          .ofDouble(number);
      expect(fxp.value.bitString, corners[c].$1);
      expect(fxp.toDouble(), number);
    }
    // Exhaustive unsigned
    for (var i = 0; i < pow(2, 4); i++) {
      for (var m = 0; m < 5; m++) {
        final n = 4 - m;
        final fxp = FixedPointValue.populatorWithSignedness(
                integerWidth: m, fractionWidth: n, signed: false)
            .ofLogicValue(LogicValue.ofInt(i, 4));
        expect(fxp.value.width, 4);
        expect(fxp.toDouble(), i / pow(2, n));
      }
    }
  });

  // Check that fixed-point value conversion uses the same rounding modes as
  // floating-point value and hardware conversion APIs.
  test('FixedPointValue: ofDouble supports every rounding mode', () {
    const expectedPositive = {
      FloatingPointRoundingMode.truncate: 4,
      FloatingPointRoundingMode.roundTowardsZero: 4,
      FloatingPointRoundingMode.roundNearestEven: 4,
      FloatingPointRoundingMode.roundNearestTiesAway: 5,
      FloatingPointRoundingMode.roundTowardsInfinity: 5,
      FloatingPointRoundingMode.roundTowardsNegativeInfinity: 4,
    };
    const expectedNegative = {
      FloatingPointRoundingMode.truncate: -4,
      FloatingPointRoundingMode.roundTowardsZero: -4,
      FloatingPointRoundingMode.roundNearestEven: -4,
      FloatingPointRoundingMode.roundNearestTiesAway: -5,
      FloatingPointRoundingMode.roundTowardsInfinity: -4,
      FloatingPointRoundingMode.roundTowardsNegativeInfinity: -5,
    };

    for (final mode in FloatingPointRoundingMode.values) {
      final positive = FixedPointValue.populatorWithSignedness(
              integerWidth: 2, fractionWidth: 2)
          .ofDouble(1.125, roundingMode: mode);
      final negative = FixedPointValue.populatorWithSignedness(
              integerWidth: 2, fractionWidth: 2)
          .ofDouble(-1.125, roundingMode: mode);
      expect(positive.toScaledBigInt().significand,
          BigInt.from(expectedPositive[mode]!),
          reason: 'positive mode=$mode');
      expect(negative.toScaledBigInt().significand,
          BigInt.from(expectedNegative[mode]!),
          reason: 'negative mode=$mode');
    }

    expect(
        FixedPointValuePopulator.canStore(3.75,
            signed: true, integerWidth: 2, fractionWidth: 2),
        isTrue);
    expect(
        FixedPointValuePopulator.canStore(4,
            signed: true, integerWidth: 2, fractionWidth: 2),
        isFalse);
    expect(
        FixedPointValuePopulator.canStore(-4,
            signed: true, integerWidth: 2, fractionWidth: 2),
        isTrue);
  });

  // Exercise both width-constrained populator conversions without using
  // double as an intermediate representation.
  test('FixedPointValue: direct FP conversion rounds and validates', () {
    final source =
        FloatingPointValue.populator(exponentWidth: 5, mantissaWidth: 10)
            .ofDouble(1.125);
    for (final mode in FloatingPointRoundingMode.values) {
      final fromFloatingPoint = FixedPointValue.populatorWithSignedness(
              integerWidth: 2, fractionWidth: 2)
          .ofFloatingPointValue(source, roundingMode: mode);
      final fromDouble = FixedPointValue.populatorWithSignedness(
              integerWidth: 2, fractionWidth: 2)
          .ofDouble(1.125, roundingMode: mode);
      expect(fromFloatingPoint, fromDouble, reason: 'mode=$mode');
    }

    expect(
        () => FixedPointValue.populatorWithSignedness(
                integerWidth: 1, fractionWidth: 2)
            .ofFloatingPointValue(FloatingPointValue.populator(
                    exponentWidth: 5, mantissaWidth: 10)
                .ofDouble(2)),
        throwsA(isA<RohdHclException>()));
    expect(
        () => FixedPointValue.populatorWithSignedness(
                integerWidth: 2, fractionWidth: 2, signed: false)
            .ofFloatingPointValue(FloatingPointValue.populator(
                    exponentWidth: 5, mantissaWidth: 10)
                .ofDouble(-0.25)),
        throwsA(isA<RohdHclException>()));
    expect(
        () => FixedPointValue.populatorWithSignedness(
                integerWidth: 2, fractionWidth: 2)
            .ofFloatingPointValue(FloatingPointValue.populator(
                    exponentWidth: 5, mantissaWidth: 10)
                .nan),
        throwsA(isA<RohdHclException>()));
    expect(
        () => FloatingPointValue.populator(exponentWidth: 5, mantissaWidth: 10)
            .nan
            .toFixedPointValue(),
        throwsA(isA<RohdHclException>()));
    expect(
        () => FloatingPointValue.populator(exponentWidth: 5, mantissaWidth: 10)
            .positiveInfinity
            .toFixedPointValue(),
        throwsA(isA<RohdHclException>()));

    expect(
        () => FixedPointValue.populatorWithSignedness(
                integerWidth: 1, fractionWidth: 1)
            .ofDouble(1.75,
                roundingMode: FloatingPointRoundingMode.roundNearestEven),
        throwsA(isA<RohdHclException>()));
  });

  // Exhaustively prove that automatic-width conversions preserve the exact
  // dyadic value in both directions, including the wider mantissas that
  // exposed the original issue.
  test('FixedPointValue: lossless fixed and floating conversions', () {
    for (final mantissaWidth in [3, 4, 5, 9]) {
      final width = 1 + 4 + mantissaWidth;
      for (var raw = 0; raw < 1 << width; raw++) {
        final fpv = FloatingPointValue.populator(
                exponentWidth: 4, mantissaWidth: mantissaWidth)
            .ofLogicValue(LogicValue.ofInt(raw, width));
        if (fpv.isNaN || fpv.isAnInfinity) {
          continue;
        }
        final exact = fpv.toScaledBigInt();
        final fixed = fpv.toFixedPointValue();
        expectSameDyadic(fixed.toScaledBigInt(), exact,
            reason: 'FP to fixed mantissaWidth=$mantissaWidth raw=$raw');
        expectSameDyadic(fixed.toFloatingPointValue().toScaledBigInt(), exact,
            reason: 'FP round trip mantissaWidth=$mantissaWidth raw=$raw');
      }
    }

    for (final signed in [false, true]) {
      for (var fractionWidth = 0; fractionWidth <= 7; fractionWidth++) {
        final integerWidth = signed ? 7 - fractionWidth : 8 - fractionWidth;
        for (var raw = 0; raw < 256; raw++) {
          final fixed = FixedPointValue.populatorWithSignedness(
                  integerWidth: integerWidth,
                  fractionWidth: fractionWidth,
                  signed: signed)
              .ofLogicValue(LogicValue.ofInt(raw, 8));
          final exact = fixed.toScaledBigInt();
          final floating = fixed.toFloatingPointValue();
          expectSameDyadic(floating.toScaledBigInt(), exact,
              reason: 'fixed to FP signed=$signed '
                  'fractionWidth=$fractionWidth raw=$raw');
          expectSameDyadic(floating.toFixedPointValue().toScaledBigInt(), exact,
              reason: 'fixed round trip signed=$signed '
                  'fractionWidth=$fractionWidth raw=$raw');
        }
      }
    }
  });

  // A mantissa wider than a host double must survive direct conversion.
  test('FixedPointValue: wide direct conversion avoids host double', () {
    final significand = (BigInt.one << 100) + (BigInt.one << 47) + BigInt.one;
    final fixed = FixedPointValue.populatorWithSignedness(
            integerWidth: 30, fractionWidth: 80, signed: false)
        .ofScaledBigInt(significand, -80);
    final floating =
        FloatingPointValue.populator(exponentWidth: 8, mantissaWidth: 110)
            .ofFixedPointValue(fixed);

    expectSameDyadic(floating.toScaledBigInt(), fixed.toScaledBigInt());
  });

  // E4M3 reserves its top encoding for NaN, so finite overflow must saturate
  // rather than accidentally producing that encoding.
  test('FixedPointValue: direct E4M3 conversion avoids reserved NaN', () {
    final fixed = FixedPointValue.populatorWithSignedness(
            integerWidth: 9, fractionWidth: 0)
        .ofScaledBigInt(BigInt.from(472), 0);
    final converted =
        FloatingPoint8E4M3Value.populator().ofFixedPointValue(fixed);
    final fromDouble = FloatingPoint8E4M3Value.populator().ofDouble(472);
    final largest = FloatingPoint8E4M3Value.populator()
        .ofConstant(FloatingPointConstants.largestNormal);

    expect(converted.isNaN, isFalse);
    expect(converted, largest);
    expect(fromDouble, largest);
  });

  test('Comparison operators', () {
    FixedPointValuePopulator populator({bool signed = false}) =>
        FixedPointValue.populatorWithSignedness(
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
      final fxv = FixedPointValue.populatorWithSignedness(
              integerWidth: m, fractionWidth: n)
          .ofLogicValue(LogicValue.ofInt(i, width));
      final dbl = fxv.toDouble();
      if (!FixedPointValuePopulator.canStore(dbl,
          signed: fxv.signed,
          integerWidth: fxv.integerWidth,
          fractionWidth: fxv.fractionWidth)) {
        throw RohdHclException('generated a value that we cannot store');
      }
      final fxv2 = FixedPointValue.populatorWithSignedness(
              integerWidth: m, fractionWidth: n)
          .ofDouble(dbl);

      expect(fxv, equals(fxv2));
    }
  });

  test('FixedPointValue: random double round-trip', () {
    const m = 4;
    const n = 2;
    final rv = Random(57);
    for (final signed in [false, true]) {
      final lowerBound = FixedPointValue.populatorWithSignedness(
              signed: signed, integerWidth: m, fractionWidth: n)
          .ofDouble(0);
      final upperBound = FixedPointValue.populatorWithSignedness(
              signed: signed, integerWidth: m, fractionWidth: n)
          .ofDouble(0.5);
      for (var i = 0; i < 1000; i++) {
        final fxv = FixedPointValue.populatorWithSignedness(
                signed: signed, integerWidth: m, fractionWidth: n)
            .random(rv, gt: lowerBound, lt: upperBound);
        final dbl = fxv.toDouble();
        expect(dbl > lowerBound.toDouble(), isTrue);
        expect(dbl < upperBound.toDouble(), isTrue);
      }
      for (var i = 0; i < 1000; i++) {
        final fxv = FixedPointValue.populatorWithSignedness(
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
                fxp1 = FixedPointValue.populatorWithSignedness(
                        integerWidth: m1, fractionWidth: n1, signed: s1 == 0)
                    .ofLogicValue(LogicValue.ofInt(i1, w));

                fxp2 = FixedPointValue.populatorWithSignedness(
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
