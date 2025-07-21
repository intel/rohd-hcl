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
        expect(
            explicitPopulator()
                .ofFloatingPointValue(fp, canonicalizeExplicit: true),
            equals(fp2));
        final fpOrig = implicitPopulator()
            .ofDouble(dbl, roundingMode: FloatingPointRoundingMode.truncate);
        expect(implicitPopulator().ofFloatingPointValue(fp), equals(fpOrig));
        final ifp = implicitPopulator().ofFloatingPointValue(fp);
        expect(ifp, equals(fpOrig));
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
              expect(
                  explicitPopulator()
                      .ofFloatingPointValue(efp, canonicalizeExplicit: true),
                  equals(efp2));
              final fp = implicitPopulator().ofDouble(dbl,
                  roundingMode: FloatingPointRoundingMode.truncate);
              expect(implicitPopulator().ofFloatingPointValue(efp), equals(fp));
            }
            mantissa = mantissa + 1;
          }
          exponent = exponent + 1;
        }
      }
    });
  });
  group('FPV: toFixedPointValue', () {
    // generate expected result of float2fixed conversion
    FixedPointValue expectedResult(
      int exp,
      int expSize,
      int sign,
      int mant,
      int mantSize,
      LogicValue exponent,
    ) {
      // generate expected result
      final expAbs = exp.abs();
      final shift =
          expAbs + 3; // add two bits for integral part, one bit for sign

      final mantissa = exponent != LogicValue.ofInt(0, expSize)
          ? LogicValue.ofInt(1 << mantSize | mant, mantSize + shift)
          : LogicValue.ofInt(mant, mantSize + shift);
      final shiftedMantissa = exp < 0 ? mantissa : mantissa << expAbs;
      final finalMantissa = sign == 0 ? shiftedMantissa : ~shiftedMantissa + 1;

      final nLen = exp.isNegative ? mantSize - exp : mantSize;
      final mLen = finalMantissa.width - nLen - 1; // one bit for sign
      return FixedPointValue.populator(
        integerWidth: mLen,
        fractionWidth: nLen,
        signed: true,
      ).ofLogicValue(finalMantissa);
    }

    test('FPV: toFixedPointValue exhaustive', () async {
      // bit widths to be tested
      // 6, 7, 8-bit exponent
      // 8, 10, 12-bit mantissa
      final expWidths = [5, 6, 7, 8];
      final mantWidths = [10, 12, 17, 23];

      for (final expWidth in expWidths) {
        for (final mantWidth in mantWidths) {
          final minExp = -1 << (expWidth - 1);
          final maxExp = (1 << (expWidth - 1)) - 1;
          for (int testExp = minExp; testExp < maxExp; testExp++) {
            final bias = (pow(2, expWidth - 1) - 1).toInt();
            final exp = LogicValue.ofInt(testExp, expWidth);
            final sign = LogicValue.ofInt(0, 1);
            final mant = LogicValue.ofInt(testExp, mantWidth);

            final fpv1 = FloatingPointValue(
              exponent: exp + bias,
              sign: sign,
              mantissa: mant,
            );
            if (fpv1.isNaN || fpv1.isAnInfinity) {
              continue;
            }

            final fxv = fpv1.toFixedPointValue();

            final expected = expectedResult(
              testExp,
              expWidth,
              sign.toInt(),
              mant.toInt(),
              mantWidth,
              fpv1.exponent,
            );

            expect(
              fxv == expected,
              true,
              reason: 'Got $fxv expected $expected',
            );
          }
        }
      }
    });
    test('FPV: toFixedPointValue simplified', () async {
      //
      //[exp, expSize, sign (0 == +), mant, mantSize]
      final testCases = [
        [0, 8, 0, 0x000000, 23], // 1.0
        [0, 8, 0, 0x000001, 23], // 1.0000001
        [1, 8, 0, 0x000001, 23], // 2.0000002
        [8, 8, 0, 0x000001, 23], // 256.00003
        [0, 8, 0, 0x400000, 23], // 1.5
        [-1, 8, 0, 0x400000, 23], // 0.75
        [1, 8, 0, 0x400000, 23], // 3.0
        [2, 8, 0, 0x400000, 23], // 6.0
        [0, 8, 1, 0x000000, 23], // -1.0
        [0, 8, 1, 0x400000, 23], // -1.5
        [0, 5, 0, 0x000, 10], // 1.0, 16-bit float
        [-127, 8, 0, 0x000001, 23], // 1e-45
        [-127, 8, 0, 0x000000, 23], // 0
        [-127, 8, 1, 0x000000, 23], // -0
      ];

      for (final testCase in testCases) {
        final bias = (pow(2, testCase[1] - 1) - 1).toInt();
        final exp = testCase[0];
        final fpv1 = FloatingPointValue(
          exponent: LogicValue.ofInt(exp + bias, testCase[1]),
          sign: LogicValue.ofInt(testCase[2], 1),
          mantissa: LogicValue.ofInt(testCase[3], testCase[4]),
        );
        final fxv = fpv1.toFixedPointValue();

        // generate expected result
        final expected = expectedResult(
          exp,
          testCase[1],
          testCase[2],
          testCase[3],
          testCase[4],
          fpv1.exponent,
        );

        expect(fxv == expected, true, reason: 'Got $fxv expected $expected');
      }
    });
  });
  test('FPV: toFixedPointValue, Special values', () async {
    //
    //[exp, expSize, sign (0 == +), mant, mantSize]
    final testCases = [
      [128, 8, 0, 0x400000, 23], // NaN
      [128, 8, 1, 0x000000, 23], // -Inf
      [128, 8, 0, 0x400000, 23], // Inf
    ];

    for (final testCase in testCases) {
      final bias = (pow(2, testCase[1] - 1) - 1).toInt();
      final fpv1 = FloatingPointValue(
          exponent: LogicValue.ofInt(testCase[0] + bias, testCase[1]),
          sign: LogicValue.ofInt(testCase[2], 1),
          mantissa: LogicValue.ofInt(testCase[3], testCase[4]));

      expect(
        () => fpv1.toFixedPointValue(),
        throwsA(isA<RohdHclException>()),
      );
    }
  });
}
