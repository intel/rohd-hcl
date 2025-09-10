// Copyright (C) 2024-2025 Intel Corporation
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
    }
  });

  test('Initializing derived type', () {
    final fp = FloatingPoint16Value.populator().ofInts(15, 0);
    final s = fp.toString();
    final fp2 = FloatingPoint16Value.populator().ofSpacedBinaryString(s);
    expect(fp, equals(fp2));
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
    // TODO(desmonddak):  is this exhaustive enough: should we do EFP to FP rt
    // as well as FP to EFP rt?
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
}
