// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_dualpath_test.dart
// Tests of FloatingPointAdderDualPath-- a dual-path FP Adder.
//
// 2024 August 30
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:async';
import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  group('FP: dual-path adder N path tests', () {
    const exponentWidth = 3;
    const mantissaWidth = 5;
    FloatingPoint fpConstructor() => FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp1 = fpConstructor();
    final fp2 = fpConstructor();

    FloatingPointValuePopulator fpvPopulator() => fp1.valuePopulator();
    test('FP: dual-path adder N path singleton', () async {
      final fv1 = fpvPopulator().ofInts(0, 0, sign: true);
      final fv2 = fpvPopulator().ofInts(0, 1, sign: true);

      fp1.put(fv1);
      fp2.put(fv2);

      final expectedNoRound =
          fpvPopulator().ofDoubleUnrounded(fv1.toDouble() + fv2.toDouble());
      final expected = expectedNoRound;

      final adder = FloatingPointAdderDualPath(fp1, fp2);

      final computed = adder.sum.floatingPointValue;
      expect(computed, equals(expected));
    });

    // isR is Addition or exponent delta >= 2
    // N path is Subtraction & exponent delta < 2

    test('FP: dual-path adder N path, subtraction, delta < 2', () async {
      final one = fpvPopulator().ofConstant(FloatingPointConstants.one);
      fp1.put(one);
      fp2.put(one);
      final adder = FloatingPointAdderDualPath(fp1, fp2);

      final largestExponent = fpvPopulator().bias + fpvPopulator().maxExponent;

      final largestMantissa = pow(2, mantissaWidth).toInt() - 1;
      for (var e1 = 0; e1 <= largestExponent; e1++) {
        for (var e2 = 0; e2 <= largestExponent; e2++) {
          for (final sign1 in [false, true]) {
            for (final sign2 in [false, true]) {
              if ((sign1 ^ sign2) && (e1 - e2).abs() < 2) {
                for (var m1 = 0; m1 <= largestMantissa; m1++) {
                  final fv1 = fpvPopulator().ofInts(e1, m1, sign: sign1);
                  for (var m2 = 0; m2 <= largestMantissa; m2++) {
                    final fv2 = fpvPopulator().ofInts(e2, m2, sign: sign2);

                    fp1.put(fv1);
                    fp2.put(fv2);
                    // No rounding
                    final expected = fpvPopulator()
                        .ofDoubleUnrounded(fv1.toDouble() + fv2.toDouble());

                    final computed = adder.sum.floatingPointValue;
                    expect(computed, equals(expected));
                  }
                }
              }
            }
          }
        }
      }
    });
  });

  group('FP: dual-path adder R path tests', () {
    const exponentWidth = 3;
    const mantissaWidth = 4;
    final expLimit = pow(2, exponentWidth).toInt();
    final mantLimit = pow(2, mantissaWidth).toInt();

    FloatingPoint fpConstructor() => FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp1 = fpConstructor();
    final fp2 = fpConstructor();

    FloatingPointValuePopulator fpvPopulator() => fp1.valuePopulator();
    test('FP: dual-path adder singleton R path', () async {
      final clk = SimpleClockGenerator(10).clk;

      fp1.put(0);
      fp2.put(0);

      final fv1 = fpvPopulator().ofInts(3, 5);
      final fv2 = fpvPopulator().ofInts(5, 2, sign: true);

      fp1.put(fv1);
      fp2.put(fv2);

      final expected = fv1 + fv2;
      final adder = FloatingPointAdderDualPath(clk: clk, fp1, fp2);
      await adder.build();
      unawaited(Simulator.run());
      await clk.nextNegedge;
      fp1.put(0);
      fp2.put(0);

      final computed = adder.sum.floatingPointValue;
      expect(computed.isNaN, equals(expected.isNaN));
      expect(computed, equals(expected));
      await Simulator.endSimulation();
    });

    test('FP: dual-path adder R path exhaustive', () async {
      fp1.put(0);
      fp2.put(0);
      final adder = FloatingPointAdderDualPath(fp1, fp2);

      for (var e1 = 0; e1 < expLimit; e1++) {
        for (var e2 = 0; e2 < expLimit; e2++) {
          for (final sign1 in [false, true]) {
            for (final sign2 in [false, true]) {
              if ((sign1 == sign2) || (e1 - e2).abs() >= 2) {
                for (var m1 = 0; m1 < mantLimit; m1++) {
                  final fv1 = fpvPopulator().ofInts(e1, m1, sign: sign1);
                  for (var m2 = 0; m2 < mantLimit; m2++) {
                    final fv2 = fpvPopulator().ofInts(e2, m2, sign: sign2);

                    fp1.put(fv1);
                    fp2.put(fv2);
                    final expected = fv1 + fv2;
                    final computed = adder.sum.floatingPointValue;
                    expect(computed.isNaN, equals(expected.isNaN));
                    if (!computed.isNaN) {
                      expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
                    }
                  }
                }
              }
            }
          }
        }
      }
    });

    test('FP: dual-path adder R path, full random', () async {
      final clk = SimpleClockGenerator(10).clk;

      fp1.put(0);
      fp2.put(0);
      final adder = FloatingPointAdderDualPath(clk: clk, fp1, fp2);
      await adder.build();
      unawaited(Simulator.run());
      final rand = Random(47);

      var cnt = 200;
      while (cnt > 0) {
        final fv1 = fpvPopulator().random(rand);
        final fv2 = fpvPopulator().random(rand);
        fp1.put(fv1);
        fp2.put(fv2);
        if ((fv1.exponent.toInt() - fv2.exponent.toInt()).abs() >= 2) {
          cnt--;
          final expected = fv1 + fv2;
          await clk.nextNegedge;
          fp1.put(0);
          fp2.put(0);
          final computed = adder.sum.floatingPointValue;
          expect(computed.isNaN, equals(expected.isNaN));
          if (!computed.isNaN) {
            expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
          }
        }
      }
      await Simulator.endSimulation();
    });
  });

  group('FP: dual-path adder both paths tests', () {
    const exponentWidth = 3;
    const mantissaWidth = 4;
    final expLimit = pow(2, exponentWidth).toInt();
    final mantLimit = pow(2, mantissaWidth).toInt();

    FloatingPoint fpConstructor() => FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp1 = fpConstructor();
    final fp2 = fpConstructor();

    FloatingPointValuePopulator fpvPopulator() => fp1.valuePopulator();

    test('FP: dual-path adder singleton merged path', () async {
      fp1.put(0);
      fp2.put(0);
      final fv1 = fpvPopulator().ofInts(4, 7);
      final fv2 = fpvPopulator().ofInts(3, 4, sign: true);
      fp1.put(fv1);
      fp2.put(fv2);

      final expectedNoRound =
          fpvPopulator().ofDoubleUnrounded(fv1.toDouble() + fv2.toDouble());

      final expectedRound = fv1 + fv2;
      final expected =
          (((fv1.exponent.toInt() - fv2.exponent.toInt()).abs() < 2) &
                  (fv1.sign.toInt() != fv2.sign.toInt()))
              ? expectedNoRound
              : expectedRound;
      final adder = FloatingPointAdderDualPath(fp1, fp2);

      final computed = adder.sum.floatingPointValue;
      expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
    });

    test('FP: dual-path adder singleton merged pipelined path', () async {
      final clk = SimpleClockGenerator(10).clk;

      fp1.put(0);
      fp2.put(0);
      final fv1 = fpvPopulator().ofInts(4, 5);
      final fv2 = fpvPopulator().ofInts(3, 7, sign: true);
      fp1.put(fv1);
      fp2.put(fv2);

      final expectedNoRound =
          fpvPopulator().ofDoubleUnrounded(fv1.toDouble() + fv2.toDouble());

      final expectedRound = fv1 + fv2;
      final expected =
          (((fv1.exponent.toInt() - fv2.exponent.toInt()).abs() < 2) &
                  (fv1.sign.toInt() != fv2.sign.toInt()))
              ? expectedNoRound
              : expectedRound;
      final adder = FloatingPointAdderDualPath(clk: clk, fp1, fp2);
      await adder.build();
      unawaited(Simulator.run());
      await clk.nextNegedge;
      fp1.put(0);
      fp2.put(0);

      final computed = adder.sum.floatingPointValue;
      expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
      await Simulator.endSimulation();
    });

    test('FP: dual-path adder exhaustive', () {
      fp1.put(0);
      fp2.put(0);
      final adder = FloatingPointAdderDualPath(fp1, fp2);

      for (final subtract in [0, 1]) {
        for (var e1 = 0; e1 < expLimit; e1++) {
          for (var m1 = 0; m1 < mantLimit; m1++) {
            final fv1 = fpvPopulator().ofInts(e1, m1);
            for (var e2 = 0; e2 < expLimit; e2++) {
              for (var m2 = 0; m2 < mantLimit; m2++) {
                final fv2 = fpvPopulator().ofInts(e2, m2, sign: subtract == 1);

                fp1.put(fv1.value);
                fp2.put(fv2.value);
                final computed = adder.sum.floatingPointValue;
                final dbl = fv1.toDouble() + fv2.toDouble();

                final expected =
                    (((fv1.exponent.toInt() - fv2.exponent.toInt()).abs() < 2) &
                            (fv1.sign.toInt() != fv2.sign.toInt()))
                        ? fpvPopulator().ofDoubleUnrounded(dbl)
                        : fv1 + fv2;
                expect(computed.isNaN, equals(expected.isNaN));
                if (!computed.isNaN) {
                  expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
                }
              }
            }
          }
        }
      }
    });
  });

  group('FP: dual-path adder DAZ/FTZ tests', () {
    const exponentWidth = 3;
    const mantissaWidth = 3;
    final expLimit = pow(2, exponentWidth).toInt();
    final mantLimit = pow(2, mantissaWidth).toInt();
    FloatingPoint fpConstructor({bool subNormalAsZero = false}) =>
        FloatingPoint(
            exponentWidth: exponentWidth,
            mantissaWidth: mantissaWidth,
            subNormalAsZero: subNormalAsZero);
    FloatingPointValuePopulator fpvPopulator({bool subNormalAsZero = false}) =>
        FloatingPointValue.populator(
            exponentWidth: exponentWidth,
            mantissaWidth: mantissaWidth,
            subNormalAsZero: subNormalAsZero);

    test('FP: dual-path adder DAZ/FTZ test singleton', () {
      for (final daz1 in [false]) {
        for (final daz2 in [true]) {
          for (final ftz in [false]) {
            final fp1 = fpConstructor(subNormalAsZero: daz1);
            final fp2 = fpConstructor(subNormalAsZero: daz2);
            final fpOut = fpConstructor(subNormalAsZero: ftz);

            fp1.put(0);
            fp2.put(0);
            const e1 = 0;
            const m1 = 1;
            const e2 = 0;
            const m2 = 0;

            for (final sign1 in [true]) {
              final fv1 = fpvPopulator(subNormalAsZero: daz1)
                  .ofInts(e1, m1, sign: sign1);
              for (final sign2 in [true]) {
                final fv2 = fpvPopulator(subNormalAsZero: daz2)
                    .ofInts(e2, m2, sign: sign2);

                fp1.put(fv1.value);
                fp2.put(fv2.value);
                final adder =
                    FloatingPointAdderDualPath(fp1, fp2, outSum: fpOut);
                // This will interpret the adder.sum value as
                // a FloatingPointValue without the sumNormalAsZero
                // property set, so we can validate it is indeed zero.
                final computed = fpvPopulator()
                    .ofFloatingPointValue(adder.sum.floatingPointValue);

                final dbl = fv1.toDouble() + fv2.toDouble();

                final expectedNoRound =
                    fpvPopulator(subNormalAsZero: ftz).ofDoubleUnrounded(dbl);
                final expectedRound =
                    fpvPopulator(subNormalAsZero: ftz).ofDouble(dbl);

                final expected =
                    (((fv1.exponent.toInt() - fv2.exponent.toInt()).abs() < 2) &
                            (fv1.sign.toInt() != fv2.sign.toInt()))
                        ? expectedNoRound
                        : expectedRound;
                expect(computed.isNaN, equals(expected.isNaN));
                if (!computed.isNaN) {
                  expect(computed, equals(expected), reason: '''
      daz1: $daz1, daz2: $daz2    ftz: $ftz
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
                }
              }
            }
          }
        }
      }
    });

    test('FP: dual-path adder DAZ/FTZ test exhaustive', () {
      for (final daz1 in [false, true]) {
        for (final daz2 in [false, true]) {
          for (final ftz in [false, true]) {
            final fp1 = fpConstructor(subNormalAsZero: daz1);
            final fp2 = fpConstructor(subNormalAsZero: daz2);
            final fpOut = fpConstructor(subNormalAsZero: ftz);

            fp1.put(0);
            fp2.put(0);
            final adder = FloatingPointAdderDualPath(fp1, fp2, outSum: fpOut);
            for (var e1 = 0; e1 < expLimit; e1++) {
              for (var m1 = 0; m1 < mantLimit; m1++) {
                for (final sign1 in [false, true]) {
                  final fv1 = fpvPopulator(subNormalAsZero: daz1)
                      .ofInts(e1, m1, sign: sign1);
                  for (var e2 = 0; e2 < expLimit; e2++) {
                    for (var m2 = 0; m2 < mantLimit; m2++) {
                      for (final sign2 in [false, true]) {
                        final fv2 = fpvPopulator(subNormalAsZero: daz2)
                            .ofInts(e2, m2, sign: sign2);

                        fp1.put(fv1.value);
                        fp2.put(fv2.value);
                        // This will interpret the adder.sum value as
                        // a FloatingPointValue without the sumNormalAsZero
                        // property set, so we can validate it is indeed zero.
                        final computed = fpvPopulator()
                            .ofFloatingPointValue(adder.sum.floatingPointValue);

                        final dbl = fv1.toDouble() + fv2.toDouble();

                        final expectedNoRound =
                            fpvPopulator(subNormalAsZero: ftz)
                                .ofDoubleUnrounded(dbl);
                        final expectedRound =
                            fpvPopulator(subNormalAsZero: ftz).ofDouble(dbl);
                        final expected =
                            (((fv1.exponent.toInt() - fv2.exponent.toInt())
                                            .abs() <
                                        2) &
                                    (fv1.sign.toInt() != fv2.sign.toInt()))
                                ? expectedNoRound
                                : expectedRound;
                        expect(computed.isNaN, equals(expected.isNaN));
                        if (!computed.isNaN) {
                          expect(computed, equals(expected), reason: '''
      daz1: $daz1, daz2: $daz2, ftz: $ftz
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    });
  });

  test('FP: dual-path adder full random wide', () async {
    const exponentWidth = 11;
    const mantissaWidth = 52;

    FloatingPoint fpConstructor() => FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp1 = fpConstructor();
    final fp2 = fpConstructor();
    FloatingPointValuePopulator fpvPopulator() => fp1.valuePopulator();
    fp1.put(0);
    fp2.put(0);
    final adder = FloatingPointAdderDualPath(fp1, fp2);
    final rand = Random(51);

    var cnt = 100;
    while (cnt > 0) {
      final fv1 = fpvPopulator().random(rand);
      final fv2 = fpvPopulator().random(rand);
      fp1.put(fv1);
      fp2.put(fv2);
      final expected = fv1 + fv2;
      final computed = adder.sum.floatingPointValue;
      expect(computed.isNaN, equals(expected.isNaN));
      if (!computed.isNaN) {
        expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
      }
      cnt--;
    }
  });

  test('FP: dual-path with prefix adder pipelined', () async {
    const eWidth = 3;
    const mWidth = 5;
    final fa = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    final fb = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    FloatingPointValuePopulator fpvPopulator() => fa.valuePopulator();
    final clk = SimpleClockGenerator(10).clk;
    fa.put(0);
    fb.put(0);
    final fv1 = fpvPopulator().ofInts(14, 31);
    final fv2 = fpvPopulator().ofInts(13, 7, sign: true);
    fa.put(fv1);
    fb.put(fv2);

    final expectedNoRound = FloatingPointValue.populator(
            exponentWidth: eWidth, mantissaWidth: mWidth)
        .ofDoubleUnrounded(fv1.toDouble() + fv2.toDouble());
    final expectedRound = fv1 + fv2;

    final expected =
        (((fv1.exponent.toInt() - fv2.exponent.toInt()).abs() < 2) &
                (fv1.sign.toInt() != fv2.sign.toInt()))
            ? expectedNoRound
            : expectedRound;
    final adder = FloatingPointAdderDualPath(
        clk: clk, fa, fb, adderGen: ParallelPrefixAdder.new);
    await adder.build();
    unawaited(Simulator.run());
    await clk.nextNegedge;
    fa.put(0);
    fb.put(0);

    final computed = adder.sum.floatingPointValue;
    expect(computed.isNaN, equals(expected.isNaN));
    expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
    await Simulator.endSimulation();
  });
}
