// Copyright (C) 2024-2026 Intel Corporation
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

  test('FP: dual-path adder supports every rounding mode', () {
    const exponentWidth = 5;
    const mantissaWidth = 6;
    FloatingPointValuePopulator populator() => FloatingPointValue.populator(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final random = Random(0x754);

    for (final mode in FloatingPointRoundingMode.values) {
      final a = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final b = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final adder = FloatingPointAdderDualPath(a, b, roundingMode: mode);

      for (var iteration = 0; iteration < 150; iteration++) {
        final aValue = populator().random(random);
        final bValue = populator().random(random);
        a.put(aValue);
        b.put(bValue);

        final actual = adder.sum.floatingPointValue;
        final expected = populator().add(aValue, bValue, roundingMode: mode);
        expect(actual.isNaN, expected.isNaN,
            reason: 'mode=$mode a=$aValue b=$bValue');
        if (!expected.isNaN) {
          expect(actual, expected, reason: 'mode=$mode a=$aValue b=$bValue');
        }
      }
    }
  });

  test('FP: dual-path directed rounding sees subtraction tail', () {
    final a = FloatingPoint(exponentWidth: 5, mantissaWidth: 6);
    final b = FloatingPoint(exponentWidth: 5, mantissaWidth: 6);
    final adder = FloatingPointAdderDualPath(a, b,
        roundingMode: FloatingPointRoundingMode.roundTowardsInfinity);
    a.put(a.valuePopulator().ofSpacedBinaryString('1 01000 111111'));
    b.put(b.valuePopulator().ofSpacedBinaryString('0 01010 111110'));

    expect(adder.status.inexact.value.toBool(), isTrue);
    expect(adder.sum.floatingPointValue,
        a.valuePopulator().ofSpacedBinaryString('0 01010 011111'));

    a.put(a.valuePopulator().ofSpacedBinaryString('1 00001 000100'));
    b.put(b.valuePopulator().ofSpacedBinaryString('0 00100 101101'));
    expect(adder.status.inexact.value.toBool(), isTrue);
    expect(adder.sum.floatingPointValue,
        a.valuePopulator().ofSpacedBinaryString('0 00100 100101'));
  });

  test('FP: dual-path special values do not report inexact', () {
    final a = FloatingPoint(exponentWidth: 5, mantissaWidth: 6);
    final b = FloatingPoint(exponentWidth: 5, mantissaWidth: 6);
    final adder = FloatingPointAdderDualPath(a, b);

    a.put(a.valuePopulator().positiveInfinity);
    b.put(b.valuePopulator().one);
    expect(adder.sum.floatingPointValue.isAnInfinity, isTrue);
    expect(adder.status.inexact.value.toBool(), isFalse);

    a.put(a.valuePopulator().nan);
    b.put(b.valuePopulator().one);
    expect(adder.sum.floatingPointValue.isNaN, isTrue);
    expect(adder.status.inexact.value.toBool(), isFalse);
  });

  test('FP: dual-path native rounding is exhaustive at reduced width', () {
    const exponentWidth = 3;
    const mantissaWidth = 2;

    for (final mode in FloatingPointRoundingMode.values) {
      final a = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final b = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final adder = FloatingPointAdderDualPath(a, b, roundingMode: mode);

      for (final aSign in [false, true]) {
        for (var aExponent = 0; aExponent < 1 << exponentWidth; aExponent++) {
          for (var aMantissa = 0; aMantissa < 1 << mantissaWidth; aMantissa++) {
            final aValue =
                a.valuePopulator().ofInts(aExponent, aMantissa, sign: aSign);
            a.put(aValue);
            for (final bSign in [false, true]) {
              for (var bExponent = 0;
                  bExponent < 1 << exponentWidth;
                  bExponent++) {
                for (var bMantissa = 0;
                    bMantissa < 1 << mantissaWidth;
                    bMantissa++) {
                  final bValue = b
                      .valuePopulator()
                      .ofInts(bExponent, bMantissa, sign: bSign);
                  b.put(bValue);
                  final expected = a
                      .valuePopulator()
                      .add(aValue, bValue, roundingMode: mode);
                  final actual = adder.sum.floatingPointValue;
                  expect(actual.isNaN, expected.isNaN,
                      reason: 'mode=$mode a=$aValue b=$bValue');
                  if (!expected.isNaN) {
                    expect(actual, expected,
                        reason: 'mode=$mode a=$aValue b=$bValue');
                  }
                }
              }
            }
          }
        }
      }
    }
  });

  test('FP: dual-path rounding does not instantiate single-path', () async {
    final adder = FloatingPointAdderDualPath(
        FloatingPoint(exponentWidth: 5, mantissaWidth: 6),
        FloatingPoint(exponentWidth: 5, mantissaWidth: 6),
        roundingMode: FloatingPointRoundingMode.roundTowardsInfinity);
    await adder.build();

    Iterable<Module> descendants(Module module) sync* {
      for (final child in module.subModules) {
        yield child;
        yield* descendants(child);
      }
    }

    expect(
        descendants(adder).whereType<FloatingPointAdderSinglePath>(), isEmpty);
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

      final expected = fpvPopulator().add(fv1, fv2);

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
                    final expected = fpvPopulator().add(fv1, fv2);

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
    const representativeExponents = [0, 1, 7];
    const representativeMantissas = [0, 1, 15];

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

      final expected = fpvPopulator().add(fv1, fv2);
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

      final expected = fpvPopulator().add(fv1, fv2);
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
        for (final e1 in representativeExponents) {
          for (final m1 in representativeMantissas) {
            final fv1 = fpvPopulator().ofInts(e1, m1);
            for (final e2 in representativeExponents) {
              for (final m2 in representativeMantissas) {
                final fv2 = fpvPopulator().ofInts(e2, m2, sign: subtract == 1);

                fp1.put(fv1.value);
                fp2.put(fv2.value);
                final computed = adder.sum.floatingPointValue;

                final expected = fpvPopulator().add(fv1, fv2);
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
    const representativeExponents = [0, 1, 7];
    const representativeMantissas = [0, 1, 7];
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

                final expected =
                    fpvPopulator(subNormalAsZero: ftz).add(fv1, fv2);
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
            for (final e1 in representativeExponents) {
              for (final m1 in representativeMantissas) {
                for (final sign1 in [false, true]) {
                  final fv1 = fpvPopulator(subNormalAsZero: daz1)
                      .ofInts(e1, m1, sign: sign1);
                  for (final e2 in representativeExponents) {
                    for (final m2 in representativeMantissas) {
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

                        final expected =
                            fpvPopulator(subNormalAsZero: ftz).add(fv1, fv2);
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
    const exponentWidth = 5;
    const mantissaWidth = 7;

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

    final expected = FloatingPointValue.populator(
            exponentWidth: eWidth, mantissaWidth: mWidth)
        .add(fv1, fv2);
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
