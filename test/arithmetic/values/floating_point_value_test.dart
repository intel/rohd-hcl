// Copyright (C) 2024-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_value_test.dart
// Tests of Floating Point value stuff
//
// 2024 April 1
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  group('FPV: subNormalAsZero', () {
    const exponentWidth = 4;
    const mantissaWidth = 4;
    final expLimit = pow(2.0, exponentWidth).toInt();
    final mantLimit = pow(2.0, mantissaWidth).toInt();
    FloatingPointValuePopulator fpvPopulator(
            {int exponentWidth = exponentWidth,
            int mantissaWidth = mantissaWidth,
            bool subNormalAsZero = false}) =>
        FloatingPointValue.populator(
            exponentWidth: exponentWidth,
            mantissaWidth: mantissaWidth,
            subNormalAsZero: subNormalAsZero);

    test('FPV: subNormalAsZero exhaustive', () {
      for (final negate in [0, 1]) {
        for (var e1 = 0; e1 < expLimit; e1++) {
          for (var m1 = 0; m1 < mantLimit; m1++) {
            final fpv = fpvPopulator().ofInts(e1, m1, sign: negate == 1);
            final fpvSaZ = fpvPopulator(subNormalAsZero: true)
                .ofInts(e1, m1, sign: negate == 1);
            expect(fpv.toString(), equals(fpvSaZ.toString()));
            if (fpv.isSubnormal()) {
              expect(fpvSaZ.toDouble(), equals(0.0));
              expect(fpvSaZ.isAZero, true);
            } else if (!fpv.isNaN) {
              expect(fpvSaZ.toDouble(), equals(fpv.toDouble()));
            }
          }
        }
      }
    });
  });

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
          final fp = FloatingPointValue.populator(
                  exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
              .ofBinaryStrings(signStr, expStr, mantStr);
          final dbl = fp.toDouble();
          final fp2 = FloatingPointValue.populator(
                  exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
              .ofDouble(dbl);
          expect(fp, equals(fp2));
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
        final fp = FloatingPointValue.populator(
                exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
            .ofBinaryStrings(signStr, expStr, mantStr);
        expect(fp.toString(), '$signStr $expStr $mantStr');
        final fp2 = FloatingPointValue.populator(
                exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
            .ofDouble(
          fp.toDouble(),
        );
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
          final fp = FloatingPointValue.populator(
                  exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
              .ofBinaryStrings(signStr, expStr, mantStr);
          expect(fp.toString(), '$signStr $expStr $mantStr');
          final fp2 = FloatingPointValue.populator(
                  exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
              .ofDoubleUnrounded(fp.toDouble());
          expect(fp2, equals(fp));
        }
      }
    }
  });

  test('FPV: round trip 32', () {
    final values = [
      FloatingPoint32Value.populator()
          .ofConstant(FloatingPointConstants.largestPositiveSubnormal),
      FloatingPoint32Value.populator()
          .ofConstant(FloatingPointConstants.smallestPositiveSubnormal),
      FloatingPoint32Value.populator()
          .ofConstant(FloatingPointConstants.smallestPositiveNormal),
      FloatingPoint32Value.populator()
          .ofConstant(FloatingPointConstants.largestLessThanOne),
      FloatingPoint32Value.populator().ofConstant(FloatingPointConstants.one),
      FloatingPoint32Value.populator()
          .ofConstant(FloatingPointConstants.smallestLargerThanOne),
      FloatingPoint32Value.populator()
          .ofConstant(FloatingPointConstants.largestNormal)
    ];
    for (final fp in values) {
      final fp2 = FloatingPoint32Value.populator().ofDouble(fp.toDouble());
      expect(fp2, equals(fp));
    }
  });

  test('FPV: round trip 64', () {
    final values = [
      FloatingPoint64Value.populator()
          .ofConstant(FloatingPointConstants.largestPositiveSubnormal),
      FloatingPoint64Value.populator()
          .ofConstant(FloatingPointConstants.smallestPositiveSubnormal),
      FloatingPoint64Value.populator()
          .ofConstant(FloatingPointConstants.smallestPositiveNormal),
      FloatingPoint64Value.populator()
          .ofConstant(FloatingPointConstants.largestLessThanOne),
      FloatingPoint64Value.populator().ofConstant(FloatingPointConstants.one),
      FloatingPoint64Value.populator()
          .ofConstant(FloatingPointConstants.smallestLargerThanOne),
      FloatingPoint64Value.populator()
          .ofConstant(FloatingPointConstants.largestNormal)
    ];
    for (final fp in values) {
      final fp2 = FloatingPoint64Value.populator().ofDouble(fp.toDouble());
      expect(fp2, equals(fp));
    }
  });

  test('FloatingPointValue string conversion', () {
    const str = '0 10000001 01000100000000000000000'; // 5.0625
    final fp = FloatingPoint32Value.populator().ofSpacedBinaryString(str);
    expect(fp.toString(), str);
    expect(fp.toDouble(), 5.0625);
  });

  test('FloatingPointValue infinity check', () {
    final populator64 = FloatingPoint64Value.populator();
    final expWidth64 = populator64.exponentWidth;
    final mantissaWidth64 = populator64.mantissaWidth;
    final str64 = '0 ${'1' * expWidth64} ${'0' * mantissaWidth64}'; // infinity
    final fp = populator64.ofDouble(double.infinity);
    expect(fp.toDouble(), double.infinity);
    expect(fp.toString(), str64);

    final populator32 = FloatingPoint32Value.populator();
    final expWidth32 = populator32.exponentWidth;
    final mantissaWidth32 = populator32.mantissaWidth;
    final str32 = '0 ${'1' * expWidth32} ${'0' * mantissaWidth32}'; // infinity

    final fp2 = populator32.ofDouble(double.infinity);
    expect(fp2.toDouble(), double.infinity);
    expect(fp2.toString(), str32);
  });

  test('FPV: simple 32', () {
    final values = [0.15625, 12.375, -1.0, 0.25, 0.375];
    for (final val in values) {
      final fp = FloatingPoint32Value.populator().ofDouble(val);
      assert(val == fp.toDouble(), 'mismatch');
      expect(fp.toDouble(), val);
      final fpSuper =
          FloatingPointValue.populator(exponentWidth: 8, mantissaWidth: 23)
              .ofDouble(val);
      assert(val == fpSuper.toDouble(), 'mismatch');
      expect(fpSuper.toDouble(), val);
    }
  });

  test('FPV: simple 64', () {
    final values = [0.15625, 12.375, -1.0, 0.25, 0.375];
    for (final val in values) {
      final fp = FloatingPoint64Value.populator().ofDouble(val);
      assert(val == fp.toDouble(), 'mismatch');
      expect(fp.toDouble(), val);
      final fpSuper =
          FloatingPointValue.populator(exponentWidth: 11, mantissaWidth: 52)
              .ofDouble(val);
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

      final fp8 = FloatingPoint8E4M3Value.populator().ofDouble(val);
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
          FloatingPointValue.populator(exponentWidth: 5, mantissaWidth: 2)
              .ofDouble(val);
      expect(val, fp.toDouble());
      expect(str, fp.toString());
      final fp8 = FloatingPoint8E5M2Value.populator().ofDouble(val);
      expect(val, fp8.toDouble());
      expect(str, fp8.toString());
    }
  });

  test('FPV: setting and getting from a signal', () {
    final fp = FloatingPoint32()
      ..put(FloatingPoint32Value.populator().ofDouble(1.5).value);
    expect(fp.floatingPointValue.toDouble(), 1.5);
    final fp2 = FloatingPoint64()
      ..put(FloatingPoint64Value.populator().ofDouble(1.5).value);
    expect(fp2.floatingPointValue.toDouble(), 1.5);
    final fp8e4m3 = FloatingPoint8E4M3()
      ..put(FloatingPoint8E4M3Value.populator().ofDouble(1.5).value);
    expect(fp8e4m3.floatingPointValue.toDouble(), 1.5);
    final fp8e5m2 = FloatingPoint8E5M2()
      ..put(FloatingPoint8E5M2Value.populator().ofDouble(1.5).value);
    expect(fp8e5m2.floatingPointValue.toDouble(), 1.5);
  });

  test('FPV: round nearest even Guard and Sticky', () {
    final fp64 = FloatingPoint64Value.populator().ofBinaryStrings('0',
        '10000000000', '0000100000000000000000000000000000000000000000000001');

    final fpRound =
        FloatingPointValue.populator(exponentWidth: 4, mantissaWidth: 4)
            .ofBinaryStrings('0', '1000', '0001');
    final val = fp64.toDouble();
    final fpConvert =
        FloatingPointValue.populator(exponentWidth: 4, mantissaWidth: 4)
            .ofDouble(val);
    expect(fpConvert, equals(fpRound));
  });

  test('FPV: round nearest even Guard and Round', () {
    final fp64 = FloatingPoint64Value.populator().ofBinaryStrings('0',
        '10000000000', '0000110000000000000000000000000000000000000000000000');

    final fpRound =
        FloatingPointValue.populator(exponentWidth: 4, mantissaWidth: 4)
            .ofBinaryStrings('0', '1000', '0001');
    final val = fp64.toDouble();

    final fpConvert =
        FloatingPointValue.populator(exponentWidth: 4, mantissaWidth: 4)
            .ofDouble(val);
    expect(fpConvert, equals(fpRound));
  });

  test('FPV: rounding nearest even increment', () {
    final fp64 = FloatingPoint64Value.populator().ofBinaryStrings('0',
        '10000000000', '0001100000000000000000000000000000000000000000000000');

    final fpRound =
        FloatingPointValue.populator(exponentWidth: 4, mantissaWidth: 4)
            .ofBinaryStrings('0', '1000', '0010');
    final val = fp64.toDouble();
    final fpConvert =
        FloatingPointValue.populator(exponentWidth: 4, mantissaWidth: 4)
            .ofDouble(val);
    expect(fpConvert, equals(fpRound));
  });

  test('FPV: rounding nearest even increment carry into exponent', () {
    final fp64 = FloatingPoint64Value.populator().ofBinaryStrings('0',
        '10000000000', '1111100000000000000000000000000000000000000000000000');

    final fpRound =
        FloatingPointValue.populator(exponentWidth: 4, mantissaWidth: 4)
            .ofBinaryStrings('0', '1001', '0000');
    final val = fp64.toDouble();
    final fpConvert =
        FloatingPointValue.populator(exponentWidth: 4, mantissaWidth: 4)
            .ofDouble(val);
    expect(fpConvert, equals(fpRound));
  });

  test('FPV: rounding nearest even truncate', () {
    final fp64 = FloatingPoint64Value.populator().ofBinaryStrings('0',
        '10000000000', '0010100000000000000000000000000000000000000000000000');

    final fpTrunc =
        FloatingPointValue.populator(exponentWidth: 4, mantissaWidth: 4)
            .ofBinaryStrings('0', '1000', '0010');
    final val = fp64.toDouble();
    final fpConvert =
        FloatingPointValue.populator(exponentWidth: 4, mantissaWidth: 4)
            .ofDouble(val);
    expect(fpConvert, equals(fpTrunc));
  });

  group('FPV: exact rounding oracle', () {
    FloatingPointValue source(String sign, String mantissa) =>
        FloatingPointValue.populator(exponentWidth: 5, mantissaWidth: 6)
            .ofBinaryStrings(sign, '01111', mantissa);

    FloatingPointValue convert(
            FloatingPointValue value, FloatingPointRoundingMode mode) =>
        FloatingPointValue.populator(exponentWidth: 5, mantissaWidth: 2)
            .ofFloatingPointValueRounded(value, roundingMode: mode);

    test('halfway values distinguish tie parity and rounding direction', () {
      final halfwayEven = source('0', '001000');
      final halfwayOdd = source('0', '011000');

      expect(
          convert(halfwayEven, FloatingPointRoundingMode.roundNearestEven)
              .toString(),
          '0 01111 00');
      expect(
          convert(halfwayEven, FloatingPointRoundingMode.roundNearestTiesAway)
              .toString(),
          '0 01111 01');
      expect(
          convert(halfwayOdd, FloatingPointRoundingMode.roundNearestEven)
              .toString(),
          '0 01111 10');
      expect(
          convert(halfwayEven, FloatingPointRoundingMode.roundTowardsInfinity)
              .toString(),
          '0 01111 01');
      expect(
          convert(halfwayEven,
                  FloatingPointRoundingMode.roundTowardsNegativeInfinity)
              .toString(),
          '0 01111 00');
    });

    test('directed rounding accounts for sign', () {
      final negativeHalfway = source('1', '001000');

      expect(
          convert(negativeHalfway,
                  FloatingPointRoundingMode.roundTowardsInfinity)
              .toString(),
          '1 01111 00');
      expect(
          convert(negativeHalfway,
                  FloatingPointRoundingMode.roundTowardsNegativeInfinity)
              .toString(),
          '1 01111 01');
      expect(
          convert(negativeHalfway,
                  FloatingPointRoundingMode.roundNearestTiesAway)
              .toString(),
          '1 01111 01');
    });

    test('truncate is an alias for round toward zero', () {
      for (final sign in ['0', '1']) {
        for (var mantissa = 0; mantissa < 64; mantissa++) {
          final value = source(sign, mantissa.toRadixString(2).padLeft(6, '0'));
          expect(convert(value, FloatingPointRoundingMode.truncate),
              convert(value, FloatingPointRoundingMode.roundTowardsZero));
        }
      }
    });

    test('precision near binary64 retains guard and sticky information', () {
      final midpoint = FloatingPoint64Value.populator()
          .ofBinaryStrings('0', '01111111111', '${'0' * 50}10');
      final aboveMidpoint = FloatingPoint64Value.populator()
          .ofBinaryStrings('0', '01111111111', '${'0' * 50}11');
      final destination =
          FloatingPointValue.populator(exponentWidth: 11, mantissaWidth: 50);

      expect(
          destination.ofFloatingPointValueRounded(midpoint).mantissa.toBigInt(),
          BigInt.zero);
      expect(
          FloatingPointValue.populator(exponentWidth: 11, mantissaWidth: 50)
              .ofFloatingPointValueRounded(aboveMidpoint)
              .mantissa
              .toBigInt(),
          BigInt.one);
    });

    test('exact add and multiply round only once', () {
      final populator =
          FloatingPointValue.populator(exponentWidth: 5, mantissaWidth: 2);
      final oneAndQuarter = populator.ofBinaryStrings('0', '01111', '01');
      final oneEighth =
          FloatingPointValue.populator(exponentWidth: 5, mantissaWidth: 2)
              .ofBinaryStrings('0', '01100', '00');
      final oneAndHalf =
          FloatingPointValue.populator(exponentWidth: 5, mantissaWidth: 2)
              .ofBinaryStrings('0', '01111', '10');

      expect((oneAndQuarter + oneEighth).toString(), '0 01111 10');
      expect((oneAndHalf * oneAndHalf).toString(), '0 10000 00');
    });

    test('rounding crosses subnormal and exponent boundaries', () {
      final sourcePopulator =
          FloatingPointValue.populator(exponentWidth: 5, mantissaWidth: 6);
      final destination =
          FloatingPointValue.populator(exponentWidth: 3, mantissaWidth: 2);
      final nearSmallestNormal =
          sourcePopulator.ofBinaryStrings('0', '01100', '111000');

      expect(
          destination
              .ofFloatingPointValueRounded(nearSmallestNormal)
              .toString(),
          '0 001 00');
      expect(
          FloatingPointValue.populator(
                  exponentWidth: 3, mantissaWidth: 2, subNormalAsZero: true)
              .ofFloatingPointValueRounded(nearSmallestNormal)
              .toString(),
          '0 001 00');

      final nearTwo = source('0', '111000');
      expect(
          FloatingPointValue.populator(exponentWidth: 5, mantissaWidth: 2)
              .ofFloatingPointValueRounded(nearTwo)
              .toString(),
          '0 10000 00');
    });

    test('overflow follows each rounding direction', () {
      final positive =
          FloatingPointValue.populator(exponentWidth: 5, mantissaWidth: 6)
              .ofBinaryStrings('0', '11110', '111111');
      final negative = positive.negate();

      FloatingPointValue convertOverflow(
              FloatingPointValue value, FloatingPointRoundingMode mode) =>
          FloatingPointValue.populator(exponentWidth: 3, mantissaWidth: 2)
              .ofFloatingPointValueRounded(value, roundingMode: mode);

      for (final mode in [
        FloatingPointRoundingMode.roundNearestEven,
        FloatingPointRoundingMode.roundNearestTiesAway,
        FloatingPointRoundingMode.roundTowardsInfinity,
      ]) {
        expect(convertOverflow(positive, mode).isAnInfinity, isTrue);
      }
      for (final mode in [
        FloatingPointRoundingMode.truncate,
        FloatingPointRoundingMode.roundTowardsZero,
        FloatingPointRoundingMode.roundTowardsNegativeInfinity,
      ]) {
        expect(convertOverflow(positive, mode).toString(), '0 110 11');
      }

      expect(
          convertOverflow(
                  negative, FloatingPointRoundingMode.roundTowardsInfinity)
              .toString(),
          '1 110 11');
      expect(
          convertOverflow(negative,
                  FloatingPointRoundingMode.roundTowardsNegativeInfinity)
              .isAnInfinity,
          isTrue);
    });
  });

  group('populators', () {
    final populators = [
      FloatingPoint32Value.populator,
      FloatingPoint64Value.populator,
      FloatingPoint8E4M3Value.populator,
      FloatingPoint8E5M2Value.populator,
      FloatingPoint16Value.populator,
      FloatingPointBF16Value.populator,
      FloatingPointTF32Value.populator,
    ];

    for (final p in populators) {
      group('${p()} constants', () {
        for (final c in FloatingPointConstants.values) {
          if (p() is FloatingPointValuePopulator<FloatingPoint8E4M3Value>) {
            if (c == FloatingPointConstants.negativeInfinity ||
                c == FloatingPointConstants.positiveInfinity) {
              test('${c.name} not supported', () {
                expect(
                  () => p().ofConstant(c),
                  throwsA(isA<InfinityNotSupportedException>()),
                );
              });
              continue;
            }
          }

          test(c.name, () {
            p().ofConstant(c);
          });
        }
      });

      group('${p()} operations', () {
        final operations = {
          'add': (FloatingPointValue a) => a + a,
          'sub': (FloatingPointValue a) => a - a,
          'mul': (FloatingPointValue a) => a * a,
          'div': (FloatingPointValue a) => a / a,
          'neg': (FloatingPointValue a) => a.negate(),
          'abs': (FloatingPointValue a) => a.abs(),
          'ulp': (FloatingPointValue a) => a.ulp(),
        };
        for (final MapEntry(key: opName, value: op) in operations.entries) {
          test(opName, () {
            final fp = p().ofDouble(1.2);
            expect(op(fp).runtimeType, equals(fp.runtimeType));
          });
        }
      });

      // Basic construction, string conversion, and comparison smoke tests
      // that every FloatingPointValue subtype must pass (issue #133). 1.0
      // and 2.0 are exactly representable in every supported format.
      group('${p()} smoke', () {
        test('construction and toDouble round-trip', () {
          expect(p().ofDouble(1).toDouble(), 1);
        });

        test('string round-trip', () {
          final fp = p().ofDouble(1);
          final fp2 = p().ofSpacedBinaryString(fp.toString());
          expect(fp2, equals(fp));
        });

        test('comparison operators', () {
          final small = p().ofDouble(1);
          final large = p().ofDouble(2);
          expect(small < large, isTrue);
          expect(small <= large, isTrue);
          expect(large > small, isTrue);
          expect(large >= small, isTrue);
          expect(small.compareTo(large), lessThan(0));
          expect(large.compareTo(small), greaterThan(0));
          expect(small.compareTo(small), 0);
          expect(p().ofDouble(1), equals(p().ofDouble(1)));
        });
      });
    }
  });

  test('Initializing derived type', () {
    final fp = FloatingPoint16Value.populator().ofInts(15, 0);
    final s = fp.toString();
    final fp2 = FloatingPoint16Value.populator().ofSpacedBinaryString(s);
    expect(fp, equals(fp2));
  });

  test('FPV Value comparison', () {
    final fp = FloatingPointValue.populator(exponentWidth: 4, mantissaWidth: 4)
        .ofSpacedBinaryString('1 0101 0101');
    expect(
        fp.compareTo(
            FloatingPointValue.populator(exponentWidth: 4, mantissaWidth: 4)
                .ofSpacedBinaryString('1 0101 0101')),
        0);
    expect(
        fp.compareTo(
            FloatingPointValue.populator(exponentWidth: 4, mantissaWidth: 4)
                .ofSpacedBinaryString('1 0100 0101')),
        lessThan(0));
    expect(
        fp.compareTo(
            FloatingPointValue.populator(exponentWidth: 4, mantissaWidth: 4)
                .ofSpacedBinaryString('1 0101 0100')),
        lessThan(0));

    final fp2 = FloatingPointValue.populator(exponentWidth: 4, mantissaWidth: 4)
        .ofSpacedBinaryString('1 0000 0000');
    expect(
        fp2.compareTo(
            FloatingPointValue.populator(exponentWidth: 4, mantissaWidth: 4)
                .ofSpacedBinaryString('0 0000 0000')),
        equals(0));
  });

  test('FPV: infinity/NaN conversion tests', () async {
    const exponentWidth = 4;
    const mantissaWidth = 4;
    final infinity = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofConstant(FloatingPointConstants.positiveInfinity);
    final negativeInfinity = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofConstant(FloatingPointConstants.negativeInfinity);

    final tooLargeNumber = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofDouble(257);

    expect(infinity.toDouble(), equals(double.infinity));
    expect(negativeInfinity.toDouble(), equals(double.negativeInfinity));

    expect(tooLargeNumber.toDouble(), equals(double.infinity));

    expect(tooLargeNumber.negate().toDouble(), equals(double.negativeInfinity));

    expect(
        FloatingPointValue.populator(
                exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
            .ofConstant(FloatingPointConstants.nan)
            .toDouble()
            .isNaN,
        equals(true));
  });

  test('FPV: infinity/NaN unrounded conversion tests', () async {
    const exponentWidth = 4;
    const mantissaWidth = 4;
    final infinity = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofDoubleUnrounded(double.infinity);
    final negativeInfinity = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofDoubleUnrounded(double.negativeInfinity);
    final tooLargeNumber = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofDoubleUnrounded(557);
    expect(tooLargeNumber.toDouble(), equals(double.infinity));
    final tooLargeNumberRnded = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofDouble(557);
    expect(tooLargeNumberRnded.toDouble(), equals(double.infinity));
    expect(infinity.toDouble(), equals(double.infinity));
    expect(tooLargeNumber.negate().toDouble(), equals(double.negativeInfinity));
    expect(negativeInfinity.toDouble(), equals(double.negativeInfinity));
  });

  test('FPV: infinity operation tests', () {
    const exponentWidth = 4;
    const mantissaWidth = 4;
    final one = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofConstant(FloatingPointConstants.one);
    final zero = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofConstant(FloatingPointConstants.positiveZero);
    final infinity = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofConstant(FloatingPointConstants.positiveInfinity);
    final negativeInfinity = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofConstant(FloatingPointConstants.negativeInfinity);

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
  test('FPV: rounding check', () async {
    final fpv1 = FloatingPoint32Value.populator().ofDouble(1);
    final fpv2 = FloatingPoint32Value.populator().ofDouble(0.5);
    final fpv3 = FloatingPoint32Value.populator().ofDoubleUnrounded(
        FloatingPoint32Value.populator()
                .ofConstant(FloatingPointConstants.smallestPositiveSubnormal)
                .toDouble() +
            fpv1.toDouble());

    expect(fpv1.withinRounding(fpv2), false);
    expect(fpv1.withinRounding(fpv1), true);
    expect(fpv1.withinRounding(fpv3), true);
  });

  group('FPV: constrained random generation', () {
    const exponentWidth = 4;
    const mantissaWidth = 4;
    FloatingPointValuePopulator populator() => FloatingPointValue.populator(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

    test('FPV: constrained random generation: tight range', () {
      final lt = populator().ofBinaryStrings('0', '1100', '0001');
      final gt = populator().ofBinaryStrings('0', '1011', '1111');
      final expected = populator().ofBinaryStrings('0', '1100', '0000');
      final fpv = populator().random(Random(), lt: lt, gt: gt);

      expect(fpv, equals(expected));
    });

    test('FPV: constrained random generation: infinity', () {
      final gt = populator().ofBinaryStrings('0', '1110', '1111');
      final expected =
          populator().ofConstant(FloatingPointConstants.positiveInfinity);
      final fpv = populator().random(Random(), gt: gt);
      expect(fpv, equals(expected));
    });

    test('FPV: constrained random generation: negative infinity', () {
      final lt = populator().ofBinaryStrings('1', '1110', '1111');
      final expected =
          populator().ofConstant(FloatingPointConstants.negativeInfinity);
      final fpv = populator().random(Random(), lt: lt);
      expect(fpv, equals(expected));
    });

    test('FPV: random generation: normals', () {
      for (var iter = 0; iter < 100; iter++) {
        final fpv = populator().random(Random(), genSubNormal: false);
        expect(fpv.isNormal(), isTrue);
      }
    });

    test('FPV: random generation: subnormals', () {
      for (var iter = 0; iter < 100; iter++) {
        final fpv = populator().random(Random(), genNormal: false);
        expect(fpv.isSubnormal(), isTrue);
      }
    });

    test('FPV: constrained random testing key intervals', () {
      final points = [
        populator().ofConstant(FloatingPointConstants.negativeInfinity),
        populator().ofConstant(FloatingPointConstants.one).negate(),
        populator()
            .ofConstant(FloatingPointConstants.smallestPositiveNormal)
            .negate(),
        populator()
            .ofConstant(FloatingPointConstants.largestPositiveSubnormal)
            .negate(),
        populator().ofConstant(FloatingPointConstants.negativeZero),
        populator().ofConstant(FloatingPointConstants.positiveZero),
        populator().ofConstant(FloatingPointConstants.largestPositiveSubnormal),
        populator().ofConstant(FloatingPointConstants.smallestPositiveNormal),
        populator().ofConstant(FloatingPointConstants.one),
        populator().ofConstant(FloatingPointConstants.positiveInfinity),
      ];
      final rv = Random(71);

      for (var i = 0; i < points.length - 1; i++) {
        for (var j = i + 1; j < points.length - 1; j++) {
          final lb = points[i];
          final ub = points[j];

          if ((lb.isNormal() && ub.isNormal()) && (lb.sign == ub.sign)) {
            final fpv = populator().random(rv, gt: lb, lt: ub);
            expect(fpv.isNormal(), isTrue);
            expect(fpv > lb, isTrue);
            expect(fpv < ub, isTrue);
            populator().random(rv,
                gt: lb, lt: ub, genNormal: true, genSubNormal: false);
            try {
              populator().random(rv,
                  gt: lb, lt: ub, genNormal: false, genSubNormal: true);
              fail('should throw due to no subnormals');
            } on Exception catch (e) {
              expect(e, isA<RohdHclException>());
            }
          }
          // Adjacent FPVs at indexes: (2,3), (4,5), (6,7)
          if ((i == 2) & (j == 3) ||
              (i == 4) & (j == 5) ||
              (i == 6) & (j == 7)) {
            try {
              populator().random(rv, gt: lb, lt: ub);
              fail('should throw due to too tight a range');
            } on Exception catch (e) {
              expect(e, isA<RohdHclException>());
            }
            if ((i != 4) & (j != 5)) {
              // both are non-zero.
              populator().random(rv, gte: lb, lt: ub);
            }
            populator().random(rv, gte: lb, lte: ub);
          } else {
            populator().random(rv, gt: lb, lt: ub);
            populator().random(rv, gte: lb, lt: ub);
            populator().random(rv, gt: lb, lte: ub);
            populator().random(rv, gte: lb, lte: ub);
            // Subnormal ranges: (2,7)
            if (i >= 2 && j <= 6) {
              populator().random(rv,
                  gt: lb, lt: ub, genNormal: false, genSubNormal: true);
              try {
                populator().random(rv,
                    gt: lb, lt: ub, genNormal: true, genSubNormal: false);
                fail('should throw due to no normals');
              } on Exception catch (e) {
                expect(e, isA<RohdHclException>());
              }
              if (i > 2) {
                populator().random(rv,
                    gte: lb, lt: ub, genNormal: false, genSubNormal: true);
              }
              if (j < 6) {
                populator().random(rv,
                    gte: lb, lte: ub, genNormal: false, genSubNormal: true);
              }
            }
          }
        }
      }
    });
  });

  group('FPV: ofDouble supports all rounding modes', () {
    test(
        'FPV: ofDouble rounding-mode tie-breaking for even and odd '
        'mantissa widths', () {
      const exponentWidth = 6;
      final bias = pow(2, exponentWidth - 1).toInt() - 1;
      // Covers subnormal (0), boundary-to-normal (1), and mid-range (bias,
      // bias+1) exponents, and even and odd mantissa widths.
      for (final mantissaWidth in [2, 3, 4, 5, 8, 9]) {
        FloatingPointValuePopulator populator() => FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
        final maxM = (1 << mantissaWidth) - 1;
        for (final exp in [0, 1, bias, bias + 1]) {
          for (var mBits = 0; mBits < maxM; mBits++) {
            final vLow = populator().ofInts(exp, mBits).toDouble();
            final vHigh = populator().ofInts(exp, mBits + 1).toDouble();
            if (vLow == vHigh) {
              continue;
            }
            for (final negative in [false, true]) {
              final tie = (negative ? -1 : 1) * (vLow + vHigh) / 2.0;
              for (final mode in FloatingPointRoundingMode.values) {
                final expectedMBits = switch (mode) {
                  FloatingPointRoundingMode.truncate ||
                  FloatingPointRoundingMode.roundTowardsZero =>
                    mBits,
                  FloatingPointRoundingMode.roundTowardsInfinity =>
                    negative ? mBits : mBits + 1,
                  FloatingPointRoundingMode.roundTowardsNegativeInfinity =>
                    negative ? mBits + 1 : mBits,
                  FloatingPointRoundingMode.roundNearestTiesAway => mBits + 1,
                  FloatingPointRoundingMode.roundNearestEven =>
                    mBits.isEven ? mBits : mBits + 1,
                };
                final result = populator().ofDouble(tie, roundingMode: mode);
                final reason = 'mode=$mode mantissaWidth=$mantissaWidth '
                    'exp=$exp mBits=$mBits negative=$negative tie=$tie';
                expect(result.sign.toBool(), negative, reason: reason);
                expect(result.exponent.toInt(), exp, reason: reason);
                expect(result.mantissa.toInt(), expectedMBits, reason: reason);
              }
            }
          }
        }
      }
    });
  });

  test('FPV: isLegalValue requires the explicit j-bit to match normalcy', () {
    // For explicitJBit formats: a normal exponent (e>0) requires the j-bit
    // (mantissa MSB) set; a subnormal/zero exponent (e==0) requires it clear.
    // "Unnormal" bit patterns that violate this are not legal encodings.
    const exponentWidth = 4;
    const mantissaWidth = 4;
    FloatingPointValuePopulator populator() => FloatingPointValue.populator(
        exponentWidth: exponentWidth,
        mantissaWidth: mantissaWidth,
        explicitJBit: true);

    // e=0 (subnormal): legal only when the j-bit (MSB) is clear.
    expect(populator().ofInts(0, 0).isLegalValue(), isTrue);
    expect(populator().ofInts(0, 7).isLegalValue(), isTrue);
    expect(populator().ofInts(0, 8).isLegalValue(), isFalse);

    // e>0 (normal): legal only when the j-bit (MSB) is set.
    expect(populator().ofInts(1, 8).isLegalValue(), isTrue);
    expect(populator().ofInts(1, 15).isLegalValue(), isTrue);
    expect(populator().ofInts(1, 0).isLegalValue(), isFalse);
    expect(populator().ofInts(1, 1).isLegalValue(), isFalse);
  });

  test('FPV: explicit j-bit NaN includes a quiet payload bit', () {
    final populator = FloatingPointValue.populator(
        exponentWidth: 4, mantissaWidth: 4, explicitJBit: true);
    final nan = populator.ofConstant(FloatingPointConstants.nan);

    expect(nan.isNaN, isTrue);
    expect(nan.isQuietNaN, isTrue);
    expect(nan.mantissa.toInt(), equals(12));
    expect(
        () => FloatingPointValue.populator(
            exponentWidth: 4, mantissaWidth: 1, explicitJBit: true),
        throwsArgumentError);
  });

  group('FPV: j-bit conversion', () {
    const exponentWidth = 4;
    const mantissaWidth = 4;

    FloatingPointValuePopulator explicitPopulator() =>
        FloatingPointValue.populator(
            exponentWidth: exponentWidth,
            mantissaWidth: mantissaWidth,
            explicitJBit: true);
    FloatingPointValuePopulator implicitPopulator() =>
        FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth - 1);

    test('FPV: j-bit conversion singleton', () {
      // wants us to +eJ and - fpv.Ej in converter
      // final fp = explicitPopulator().ofSpacedBinaryString('0 0000 0000');
      final fp = explicitPopulator().ofSpacedBinaryString('0 1111 0001');
      if (fp.isLegalValue()) {
        final dbl = fp.toDouble();
        final fp2 = explicitPopulator()
            .ofDouble(dbl, roundingMode: FloatingPointRoundingMode.truncate);

        final fpCanon = explicitPopulator()
            .ofFloatingPointValue(fp, canonicalizeExplicit: true);
        expect(fpCanon.isNaN, equals(fp2.isNaN));
        if (!fpCanon.isNaN) {
          expect(fpCanon, equals(fp2));
        }
        final fpOrig = implicitPopulator()
            .ofDouble(dbl, roundingMode: FloatingPointRoundingMode.truncate);
        final computed = implicitPopulator().ofFloatingPointValue(fp);
        expect(computed.isNaN, equals(fpOrig.isNaN));
        if (!computed.isNaN) {
          expect(computed, equals(fpOrig));
        }
        final ifp = implicitPopulator().ofFloatingPointValue(fp);
        expect(ifp.isNaN, equals(fpOrig.isNaN));
        if (!ifp.isNaN) {
          expect(ifp, equals(fpOrig));
        }
      }
    });
    test('FPV: explicit EFP-FP j-bit exhaustive round-trip', () {
      const exponentWidth = 4;
      const mantissaWidth = 4;
      for (final signStr in ['0', '1']) {
        var exponent = LogicValue.zero.zeroExtend(exponentWidth);
        for (var e = 0; e < pow(2.0, exponentWidth).toInt(); e++) {
          final expStr = exponent.bitString;
          var mantissa = LogicValue.zero.zeroExtend(mantissaWidth);
          for (var m = 0; m < pow(2.0, mantissaWidth).toInt(); m++) {
            final mantStr = mantissa.bitString;

            final efp = FloatingPointValue.populator(
                    exponentWidth: exponentWidth,
                    mantissaWidth: mantissaWidth,
                    explicitJBit: true)
                .ofBinaryStrings(signStr, expStr, mantStr);
            if (efp.isLegalValue()) {
              final dbl = efp.toDouble();
              final efp2 = explicitPopulator().ofDouble(dbl,
                  roundingMode: FloatingPointRoundingMode.truncate);
              final efpCanon = explicitPopulator()
                  .ofFloatingPointValue(efp, canonicalizeExplicit: true);
              expect(efpCanon.isNaN, equals(efp2.isNaN));
              if (!efpCanon.isNaN) {
                expect(efpCanon, equals(efp2));
              }
              final fp = implicitPopulator().ofDouble(dbl,
                  roundingMode: FloatingPointRoundingMode.truncate);
              final efpNonCanon = implicitPopulator().ofFloatingPointValue(efp);
              expect(efpNonCanon.isNaN, equals(fp.isNaN));
              if (!efpNonCanon.isNaN) {
                expect(efpNonCanon, equals(fp));
              }
            }
            mantissa = mantissa + 1;
          }
          exponent = exponent + 1;
        }
      }
    });

    test('FPV: implicit FP-EFP j-bit exhaustive round-trip', () {
      // Mirrors the EFP-FP round-trip test above, but starting from the
      // implicit-j-bit (FP) domain and converting to the explicit-j-bit
      // (EFP) domain, to ensure the conversion is validated in both
      // directions and not just derived from the EFP domain's image.
      const exponentWidth = 4;
      const implicitMantissaWidth = mantissaWidth - 1;
      for (final signStr in ['0', '1']) {
        var exponent = LogicValue.zero.zeroExtend(exponentWidth);
        for (var e = 0; e < pow(2.0, exponentWidth).toInt(); e++) {
          final expStr = exponent.bitString;
          var mantissa = LogicValue.zero.zeroExtend(implicitMantissaWidth);
          for (var m = 0; m < pow(2.0, implicitMantissaWidth).toInt(); m++) {
            final mantStr = mantissa.bitString;

            final fp = FloatingPointValue.populator(
                    exponentWidth: exponentWidth,
                    mantissaWidth: implicitMantissaWidth)
                .ofBinaryStrings(signStr, expStr, mantStr);
            if (fp.isLegalValue()) {
              final dbl = fp.toDouble();
              final efpExpected = explicitPopulator().ofDouble(dbl,
                  roundingMode: FloatingPointRoundingMode.truncate);
              final efpFromFp = explicitPopulator().ofFloatingPointValue(fp);
              expect(efpFromFp.isNaN, equals(efpExpected.isNaN));
              if (!efpFromFp.isNaN) {
                expect(efpFromFp, equals(efpExpected));
              }
            }
            mantissa = mantissa + 1;
          }
          exponent = exponent + 1;
        }
      }
    });
  });

  test('FloatingPointValue negation', () async {
    const exponentWidth = 4;
    const mantissaWidth = 4;
    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

    final val1 = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofDouble(-1.23);
    fp1.put(val1);
    final val2 = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofDouble(1.23);
    expect((-fp1).floatingPointValue, equals(val2));
  });

  /// Compare two FloatingPointValues differing in jbit
  test('FloatingPointValue jbit comparison', () async {
    const exponentWidth = 4;
    const mantissaWidth = 4;

    final val1 = FloatingPointValue.populator(
            exponentWidth: exponentWidth,
            mantissaWidth: mantissaWidth,
            explicitJBit: true)
        .ofDouble(1.23);
    final val2 = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth - 1)
        .ofDouble(1.23);
    expect(val1 == val2, isTrue);
    expect(val1.hashCode, val2.hashCode);
    expect(val1 != val2, isFalse);
    expect(val1 <= val2, isTrue);
    expect(val1 >= val2, isTrue);
    expect(val1 < val2, isFalse);
    expect(val1 > val2, isFalse);
    expect(val2 < val1, isFalse);
    expect(val2 > val1, isFalse);
  });

  test('FloatingPointValue comparison operators', () async {
    const exponentWidth = 4;
    const mantissaWidth = 4;

    final rv = Random(71);

    for (var iter = 0; iter < 50; iter++) {
      final val1 = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .random(rv);
      final val2 = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .random(rv);

      expect(val1 == val1, isTrue);
      expect(val1 <= val1, isTrue);
      expect(val1 >= val1, isTrue);
      expect(val1 != val1, isFalse);
      expect(val1 < val1, isFalse);
      expect(val1 > val1, isFalse);

      if (val1 < val2) {
        expect(val1 < val2, isTrue);
        expect(val1 <= val2, isTrue);
        expect(val1 != val2, isTrue); // This will use Logic.neq()
        expect(val1 == val2, isFalse);
        expect(val1 > val2, isFalse);
      } else if (val1 > val2) {
        expect(val1 > val2, isTrue);
        expect(val1 < val2, isFalse);
        expect(val1 <= val2, isFalse);
        expect(val1 != val2, isTrue); // This will use Logic.neq()
      } else {
        // rare that the two numbers would collide but just to be safe
        expect(val1 == val2, isTrue);
        expect(val1 != val2, isFalse);
      }
    }
  });

  test('FloatingPointValue corner case comparisons', () async {
    const exponentWidth = 4;
    const mantissaWidth = 4;
    final nan = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .nan;
    final posInfinity = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofConstant(FloatingPointConstants.positiveInfinity);
    final negInfinity = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofConstant(FloatingPointConstants.negativeInfinity);

    expect(nan == nan, isFalse);
    expect(nan < nan, isFalse);
    expect(nan > nan, isFalse);

    expect(posInfinity == nan, isFalse);
    expect(posInfinity == posInfinity, isTrue);
    expect(posInfinity >= posInfinity, isTrue);
    expect(posInfinity <= posInfinity, isTrue);
    expect(posInfinity < posInfinity, isFalse);
    expect(posInfinity > posInfinity, isFalse);
    expect(posInfinity == negInfinity, isFalse);
    expect(posInfinity >= negInfinity, isTrue);
    expect(negInfinity == negInfinity, isTrue);
    expect(negInfinity < negInfinity, isFalse);
    expect(negInfinity <= negInfinity, isTrue);
    expect(negInfinity > negInfinity, isFalse);
    expect(negInfinity >= negInfinity, isTrue);
    expect((-negInfinity) == posInfinity, isTrue);
    expect((-negInfinity) < posInfinity, isFalse);
    expect((-negInfinity) > posInfinity, isFalse);
  });

  test('FloatingPointValue NaNs are unordered for every quiet predicate', () {
    FloatingPointValue value(int exponent, int mantissa, {bool sign = false}) =>
        FloatingPointValue.populator(exponentWidth: 4, mantissaWidth: 4)
            .ofInts(exponent, mantissa, sign: sign);
    final quietNaN = value(15, 8);
    final signalingNaN = value(15, 1, sign: true);
    final finite = value(7, 0);

    for (final nan in [quietNaN, signalingNaN]) {
      for (final (left, right) in [(nan, nan), (nan, finite), (finite, nan)]) {
        expect(left == right, isFalse);
        expect(left != right, isTrue);
        expect(left < right, isFalse);
        expect(left <= right, isFalse);
        expect(left > right, isFalse);
        expect(left >= right, isFalse);
        expect(() => left.compareTo(right), throwsA(isA<RohdHclException>()));
      }
    }

    expect(quietNaN.comparisonInvalid(finite), isFalse);
    expect(signalingNaN.comparisonInvalid(finite), isTrue);
    expect(finite.comparisonInvalid(signalingNaN), isTrue);
    expect(quietNaN.hasSameEncoding(quietNaN), isTrue);
    expect(quietNaN.withinRounding(quietNaN), isFalse);
    expect(finite.withinRounding(quietNaN), isFalse);
  });

  test('FloatingPointValue signed zeros compare equal and hash equally', () {
    final positiveZero =
        FloatingPointValue.populator(exponentWidth: 4, mantissaWidth: 4)
            .positiveZero;
    final negativeZero =
        FloatingPointValue.populator(exponentWidth: 4, mantissaWidth: 4)
            .negativeZero;

    expect(positiveZero == negativeZero, isTrue);
    expect(positiveZero.hashCode, negativeZero.hashCode);
    expect(positiveZero.hasSameEncoding(negativeZero), isFalse);
    expect(positiveZero < negativeZero, isFalse);
    expect(positiveZero <= negativeZero, isTrue);
    expect(positiveZero > negativeZero, isFalse);
    expect(positiveZero >= negativeZero, isTrue);
  });

  test('FPV: exact square root supports every rounding mode', () {
    FloatingPointValuePopulator populator() =>
        FloatingPointValue.populator(exponentWidth: 4, mantissaWidth: 3);
    final two = populator().ofDouble(2);
    final four = populator().ofDouble(4);
    final negativeOne = populator().ofDouble(-1);
    final negativeZero =
        populator().ofConstant(FloatingPointConstants.negativeZero);

    for (final mode in FloatingPointRoundingMode.values) {
      final squareRootTwo = populator().squareRoot(two, roundingMode: mode);
      final roundsUp = mode == FloatingPointRoundingMode.roundTowardsInfinity;
      expect(squareRootTwo, populator().ofDouble(roundsUp ? 1.5 : 1.375),
          reason: 'mode=$mode');
      expect(populator().squareRoot(four, roundingMode: mode),
          populator().ofDouble(2),
          reason: 'mode=$mode');
      expect(
          populator().squareRoot(negativeOne, roundingMode: mode).isNaN, isTrue,
          reason: 'mode=$mode');
      expect(populator().squareRoot(negativeZero, roundingMode: mode),
          negativeZero,
          reason: 'mode=$mode');
    }
  });

  test('FPV: signaling NaNs are quieted and prioritized', () {
    FloatingPointValuePopulator populator() =>
        FloatingPointValue.populator(exponentWidth: 5, mantissaWidth: 4);
    final quietFirst = populator().ofInts(31, 13, sign: false);
    final signalingSecond = populator().ofInts(31, 3, sign: true);
    final finite = populator().one;
    final expected = populator().ofInts(31, 11, sign: true);

    expect(
        populator().add(quietFirst, signalingSecond).hasSameEncoding(expected),
        isTrue);
    expect(
        populator().multiply(finite, signalingSecond).hasSameEncoding(expected),
        isTrue);
    expect(
        populator()
            .ofFloatingPointValueRounded(signalingSecond)
            .hasSameEncoding(expected),
        isTrue);
    expect(populator().squareRoot(signalingSecond).hasSameEncoding(expected),
        isTrue);
    expect(expected.isQuietNaN, isTrue);
    expect(expected.isSignalingNaN, isFalse);
  });

  test('FPV: ulp is exact across subnormal and normal boundaries', () {
    FloatingPointValue value(int exponent, int mantissa, {bool sign = false}) =>
        FloatingPointValue.populator(exponentWidth: 5, mantissaWidth: 10)
            .ofInts(exponent, mantissa, sign: sign);
    FloatingPointValue expected(int exponent, int mantissa) =>
        value(exponent, mantissa);

    expect(value(0, 0).ulp(), expected(0, 1));
    expect(value(0, 1).ulp(), expected(0, 1));
    expect(value(0, 1023).ulp(), expected(0, 1));
    expect(value(1, 0).ulp(), expected(0, 1));
    expect(value(10, 0).ulp(), expected(0, 1 << 9));
    expect(value(11, 0).ulp(), expected(1, 0));
    expect(value(15, 0, sign: true).ulp(), expected(5, 0));
  });

  test('FPV: ulp handles explicit J-bit and wide precision exactly', () {
    final explicit = FloatingPointValue.populator(
        exponentWidth: 5, mantissaWidth: 11, explicitJBit: true);
    final smallestNormal = explicit.ofInts(1, 1 << 10);
    expect(
        smallestNormal.ulp().toString(),
        FloatingPointValue.populator(
                exponentWidth: 5, mantissaWidth: 11, explicitJBit: true)
            .ofInts(0, 1)
            .toString());

    final normal = FloatingPointValue.populator(
            exponentWidth: 5, mantissaWidth: 11, explicitJBit: true)
        .ofInts(11, 1 << 10);
    expect(
        normal.ulp().toString(),
        FloatingPointValue.populator(
                exponentWidth: 5, mantissaWidth: 11, explicitJBit: true)
            .ofInts(1, 1 << 10)
            .toString());

    final wide =
        FloatingPointValue.populator(exponentWidth: 8, mantissaWidth: 80)
            .ofInts(80, 0);
    final wideUlp = wide.ulp();
    expect(wideUlp.exponent.toInt(), 0);
    expect(wideUlp.mantissa.toBigInt(), BigInt.one << 79);
  });

  test('FPV: ulp and withinRounding avoid host floating-point precision', () {
    FloatingPointValue wide(int mantissa) =>
        FloatingPointValue.populator(exponentWidth: 8, mantissaWidth: 80)
            .ofBigInts(BigInt.from(127), BigInt.from(mantissa));
    final base = wide(0);

    expect(base.withinRounding(wide(1)), isTrue);
    expect(base.withinRounding(wide(2)), isFalse);

    final flushToZero = FloatingPointValue.populator(
            exponentWidth: 5, mantissaWidth: 10, subNormalAsZero: true)
        .ofInts(1, 0);
    expect(
        flushToZero.ulp().toString(),
        FloatingPointValue.populator(
                exponentWidth: 5, mantissaWidth: 10, subNormalAsZero: true)
            .ofConstant(FloatingPointConstants.smallestPositiveNormal)
            .toString());
  });

  test('FPV: divide is exact (BigInt-based) beyond double precision', () {
    // 1.0 / 3.0 has a repeating binary expansion (0.0101...); a double can
    // only carry ~52 significant bits of it, but a 100-bit mantissa format
    // should carry the repeating pattern much further if divide() is
    // computing this exactly via BigInt long division rather than routing
    // through a host `double`.
    const mantissaWidth = 100;
    FloatingPointValuePopulator pop() => FloatingPointValue.populator(
        exponentWidth: 12, mantissaWidth: mantissaWidth);
    final one = pop().ofDouble(1);
    final three = pop().ofDouble(3);
    final quotient = one / three;
    final mantissaBits = quotient.mantissa.toString(includeWidth: false);
    // The low-order 20 bits should still show the repeating 01 pattern
    // instead of being zero-padded (which is what routing through a
    // double would have produced).
    expect(
        mantissaBits.substring(mantissaWidth - 20), isNot(contains('0' * 10)));
  });

  test('FPV: divide rejects mismatched formats', () {
    final dividend = FloatingPoint32Value.populator().ofDouble(1);
    final divisor =
        FloatingPointValue.populator(exponentWidth: 5, mantissaWidth: 10)
            .ofDouble(2);

    expect(() => dividend / divisor, throwsA(isA<RohdHclException>()));
  });

  test('FPV: divide independent-oracle exhaustive (normal results)', () {
    // Cross-checks divide() against an independently-implemented
    // round-nearest-even reference (long division to a large fixed number
    // of extra bits, then manually rounded) written separately from the
    // library's own BigInt divide/quantize code.
    BigInt oracleDivide(
        {required BigInt aSig, required BigInt bSig, required int fw}) {
      const extraBits = 300;
      final shiftAmount = bSig.bitLength + fw + extraBits - aSig.bitLength;
      final shifted =
          shiftAmount >= 0 ? (aSig << shiftAmount) : (aSig >> -shiftAmount);
      final rawQuotient = shifted ~/ bSig;
      final rawRemainder = shifted.remainder(bSig);
      final dropBits = rawQuotient.bitLength - 1 - fw;
      if (dropBits <= 0) {
        return rawQuotient << -dropBits;
      }
      final kept = rawQuotient >> dropBits;
      final dropped = rawQuotient & ((BigInt.one << dropBits) - BigInt.one);
      final halfway = BigInt.one << (dropBits - 1);
      final roundUp = dropped > halfway ||
          (dropped == halfway && (rawRemainder != BigInt.zero || kept.isOdd));
      return roundUp ? kept + BigInt.one : kept;
    }

    const exponentWidth = 5;
    const mantissaWidth = 4;
    FloatingPointValuePopulator pop() => FloatingPointValue.populator(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

    var checked = 0;
    var failures = 0;
    // Keep both operand exponents mid-range so the true quotient stays
    // well clear of the subnormal boundary (subnormal-result rounding is
    // shared, already-tested code inside the library's `_quantize`,
    // common to add/multiply/divide -- not specific to this new code).
    for (var ea = 12; ea < 19; ea++) {
      for (var ma = 0; ma < 16; ma++) {
        for (var eb = 12; eb < 19; eb++) {
          for (var mb = 0; mb < 16; mb++) {
            final a = pop().ofInts(ea, ma);
            final b = pop().ofInts(eb, mb);
            if (a.isAZero || b.isAZero) {
              continue;
            }
            final computed = a / b;
            if (computed.isAnInfinity ||
                computed.isNaN ||
                !computed.isNormal()) {
              continue;
            }
            checked++;
            final aSig = BigInt.from(ma) | (BigInt.one << mantissaWidth);
            final bSig = BigInt.from(mb) | (BigInt.one << mantissaWidth);
            final expectedSig =
                oracleDivide(aSig: aSig, bSig: bSig, fw: mantissaWidth);
            final computedSig =
                computed.mantissa.toBigInt() | (BigInt.one << mantissaWidth);
            if (computedSig != expectedSig) {
              failures++;
            }
          }
        }
      }
    }
    expect(checked, greaterThan(0));
    expect(failures, equals(0));
  });

  test('FPV: toString(integer: true) works for widths beyond 64 bits', () {
    const mantissaWidth = 100;
    final wide = FloatingPointValue.populator(
            exponentWidth: 12, mantissaWidth: mantissaWidth)
        .ofBinaryStrings('0', '100000000000', '1' * mantissaWidth);
    expect(wide.toString(integer: true),
        equals('(0 2048 ${wide.mantissa.toBigInt()})'));
  });
}
