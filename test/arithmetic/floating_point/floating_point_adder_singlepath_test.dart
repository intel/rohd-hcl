// Copyright (C) 2024-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_singlepath_test.dart
// Tests of FloatingPointAdderSinglePath -- a single path FP adder.
//
// 2024 April 1
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:async';
import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('FP: single-path adder definition names include rounding mode', () {
    final a = FloatingPoint(exponentWidth: 4, mantissaWidth: 4);
    final b = FloatingPoint(exponentWidth: 4, mantissaWidth: 4);
    final nearest = FloatingPointAdderSinglePath(a, b);
    final towardsZero = FloatingPointAdderSinglePath(a, b,
        roundingMode: FloatingPointRoundingMode.roundTowardsZero);

    expect(nearest.definitionName, isNot(towardsZero.definitionName));
  });

  test('FP: simple wide singleton test', () async {
    const exponentWidth = 4;
    const mantissaWidth = 18;
    FloatingPoint fpConstructor() => FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp1 = fpConstructor();
    final fp2 = fpConstructor();
    FloatingPointValuePopulator fpvPopulator() => fp1.valuePopulator();
    FloatingPointValue ofString(String s) =>
        fpvPopulator().ofSpacedBinaryString(s);

    final fv1 = ofString('0 0000 101011100101000000');
    final fv2 = ofString('1 0001 100100101111011100');

    fp1.put(fv1);
    fp2.put(fv2);
    final adder = FloatingPointAdderSinglePath(fp1, fp2);

    final computed = adder.sum.floatingPointValue;

    final expectedRound = fpvPopulator().add(fv1, fv2);
    final expectedNoRound = fpvPopulator()
        .add(fv1, fv2, roundingMode: FloatingPointRoundingMode.truncate);

    expect(computed, equals(expectedRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedRound (${expectedRound.toDouble()})\texpectedRound
      $expectedNoRound (${expectedNoRound.toDouble()})\texpectedRoundNo
''');
  });

  test('FP: simple adder truncating random', () {
    const exponentWidth = 5;
    const mantissaWidth = 6;
    FloatingPoint fpConstructor() => FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp1 = fpConstructor();
    final fp2 = fpConstructor();

    FloatingPointValuePopulator fpvPopulator() => fp1.valuePopulator();
    fp1.put(0);
    fp2.put(0);
    final adder = FloatingPointAdderSinglePath(fp1, fp2,
        roundingMode: FloatingPointRoundingMode.truncate);
    final rand = Random(513);
    for (var i = 0; i < 500; i++) {
      final fv1 = fpvPopulator().random(rand);
      final fv2 = fpvPopulator().random(rand);
      fp1.put(fv1);
      fp2.put(fv2);

      final computed = adder.sum.floatingPointValue;

      final expectedNoRound = fpvPopulator()
          .add(fv1, fv2, roundingMode: FloatingPointRoundingMode.truncate);
      final expectedRound = fpvPopulator().add(fv1, fv2);
      expect(computed.isNaN, equals(expectedRound.isNaN));
      if (!computed.isNaN) {
        expect(computed, equals(expectedNoRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedNoRound (${expectedNoRound.toDouble()})\texpectedNoRnd
      $expectedRound (${expectedRound.toDouble()})\texpectedRnd
''');
      }
    }
  });

  test('FP: simple adder rounding random', () {
    const exponentWidth = 5;
    const mantissaWidth = 6;

    FloatingPoint fpConstructor() => FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp1 = fpConstructor();
    final fp2 = fpConstructor();

    FloatingPointValuePopulator fpvPopulator() => fp1.valuePopulator();
    fp1.put(0);
    fp2.put(0);
    final adder = FloatingPointAdderSinglePath(fp1, fp2);
    final rand = Random(513);
    for (var i = 0; i < 500; i++) {
      final fv1 = fpvPopulator().random(rand);
      final fv2 = fpvPopulator().random(rand);
      fp1.put(fv1);
      fp2.put(fv2);

      final computed = adder.sum.floatingPointValue;

      final expectedNoRound = fpvPopulator()
          .add(fv1, fv2, roundingMode: FloatingPointRoundingMode.truncate);
      final expectedRound = fpvPopulator().add(fv1, fv2);
      expect(computed.isNaN, equals(expectedRound.isNaN));
      if (!computed.isNaN) {
        expect(computed, equals(expectedRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedNoRound (${expectedNoRound.toDouble()})\texpected
      $expectedRound (${expectedRound.toDouble()})\texpectedRnd
''');
      }
    }
  });

  test('FP: single-path adder supports every rounding mode', () {
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
      final adder = FloatingPointAdderSinglePath(a, b, roundingMode: mode);

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

  group('FP: single-path adder DAZ/FTZ tests', () {
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

    test('FP: single-path adder DAZ/FTZ test singleton', () {
      for (final subtract in [0, 1]) {
        for (final daz1 in [false, true]) {
          for (final daz2 in [false, true]) {
            for (final ftz in [false, true]) {
              final fp1 = fpConstructor(subNormalAsZero: daz1);
              final fp2 = fpConstructor(subNormalAsZero: daz2);
              final fpOut = fpConstructor(subNormalAsZero: ftz);

              fp1.put(0);
              fp2.put(0);
              final adder =
                  FloatingPointAdderSinglePath(fp1, fp2, outSum: fpOut);
              const e1 = 0;
              const m1 = 6;
              const e2 = 0;
              const m2 = 7;

              final fv1 = fp1.valuePopulator().ofInts(e1, m1);
              final fv2 =
                  fp2.valuePopulator().ofInts(e2, m2, sign: subtract == 1);

              fp1.put(fv1.value);
              fp2.put(fv2.value);
              // This will interpret the adder.sum value as
              // a FloatingPointValue without the sumNormalAsZero
              // property set, so we can validate it is indeed zero.
              final computed = fpvPopulator()
                  .ofFloatingPointValue(adder.sum.floatingPointValue);

              final expected = fpOut.valuePopulator().add(fv1, fv2);

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
    });

    test('FP: single-path adder DAZ/FTZ test exhaustive', () {
      for (final subtract in [0, 1]) {
        for (final daz1 in [false, true]) {
          for (final daz2 in [false, true]) {
            for (final ftz in [false, true]) {
              final fp1 = fpConstructor(subNormalAsZero: daz1);
              final fp2 = fpConstructor(subNormalAsZero: daz2);
              final fpOut = fpConstructor(subNormalAsZero: ftz);

              fp1.put(0);
              fp2.put(0);
              final adder =
                  FloatingPointAdderSinglePath(fp1, fp2, outSum: fpOut);
              for (final e1 in representativeExponents) {
                for (final m1 in representativeMantissas) {
                  final fv1 = fp1.valuePopulator().ofInts(e1, m1);
                  for (final e2 in representativeExponents) {
                    for (final m2 in representativeMantissas) {
                      final fv2 = fp2
                          .valuePopulator()
                          .ofInts(e2, m2, sign: subtract == 1);

                      fp1.put(fv1.value);
                      fp2.put(fv2.value);
                      // This will interpret the adder.sum value as
                      // a FloatingPointValue without the sumNormalAsZero
                      // property set, so we can validate it is indeed zero.
                      final computed = fpvPopulator()
                          .ofFloatingPointValue(adder.sum.floatingPointValue);

                      final expected = fpOut.valuePopulator().add(fv1, fv2);

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
    });
  });

  test('FP: simple new singleton test', () {
    const exponentWidth = 4;
    const mantissaWidth = 4;
    FloatingPoint fpConstructor() => FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp1 = fpConstructor();
    final fp2 = fpConstructor();

    FloatingPointValuePopulator fpvPopulator() => fp1.valuePopulator();
    final fv1 = fpvPopulator().ofSpacedBinaryString('0 0000 0001');
    final fv2 = fpvPopulator().ofSpacedBinaryString('1 0000 0000');

    fp1.put(fv1);
    fp2.put(fv2);
    final adder = FloatingPointAdderSinglePath(fp1, fp2);
    final computed = adder.sum.floatingPointValue;

    final expectedRound = fpvPopulator().add(fv1, fv2);
    final expectedNoRound = fpvPopulator()
        .add(fv1, fv2, roundingMode: FloatingPointRoundingMode.truncate);

    expect(computed, equals(expectedRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedRound (${expectedRound.toDouble()})\texpectedRound
      $expectedNoRound (${expectedNoRound.toDouble()})\texpectedRoundNo
''');
  });

  test('FP: simple adder truncating exhaustive', () {
    const exponentWidth = 3;
    const mantissaWidth = 3;
    FloatingPoint fpConstructor() => FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp1 = fpConstructor();
    final fp2 = fpConstructor();

    FloatingPointValuePopulator fpvPopulator() => fp1.valuePopulator();
    fp1.put(0);
    fp2.put(0);
    final adder = FloatingPointAdderSinglePath(fp1, fp2,
        roundingMode: FloatingPointRoundingMode.truncate);

    for (final subtract in [1, 0]) {
      final expLimit = pow(2, exponentWidth);
      final mantLimit = pow(2, mantissaWidth);
      for (var e1 = 0; e1 < expLimit; e1++) {
        for (var m1 = 0; m1 < mantLimit; m1++) {
          final fv1 = fpvPopulator().ofInts(e1, m1);
          for (var e2 = 0; e2 < expLimit; e2++) {
            for (var m2 = 0; m2 < mantLimit; m2++) {
              final fv2 = fpvPopulator().ofInts(e2, m2, sign: subtract == 1);
              fp1.put(fv1.value);
              fp2.put(fv2.value);

              final computed = adder.sum.floatingPointValue;
              final expectedNoRound = fpvPopulator().add(fv1, fv2,
                  roundingMode: FloatingPointRoundingMode.truncate);
              final expectedRound = fpvPopulator().add(fv1, fv2);
              expect(computed.isNaN, equals(expectedRound.isNaN));
              if (!computed.isNaN) {
                expect(computed, equals(expectedNoRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedNoRound (${expectedNoRound.toDouble()})\texpectedNo
      $expectedRound (${expectedRound.toDouble()})\texpectedRnd
''');
              }
            }
          }
        }
      }
    }
  });

  test('FP: simple adder rounding exhaustive', () {
    const exponentWidth = 3;
    const mantissaWidth = 3;
    FloatingPoint fpConstructor() => FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp1 = fpConstructor();
    final fp2 = fpConstructor();
    FloatingPointValuePopulator fpvPopulator() => fp1.valuePopulator();
    fp1.put(0);
    fp2.put(0);
    final adder = FloatingPointAdderSinglePath(fp1, fp2);

    for (final subtract in [1, 0]) {
      final expLimit = pow(2, exponentWidth);
      final mantLimit = pow(2, mantissaWidth);
      for (var e1 = 0; e1 < expLimit; e1++) {
        for (var m1 = 0; m1 < mantLimit; m1++) {
          final fv1 = fpvPopulator().ofInts(e1, m1);
          for (var e2 = 0; e2 < expLimit; e2++) {
            for (var m2 = 0; m2 < mantLimit; m2++) {
              final fv2 = fpvPopulator().ofInts(e2, m2, sign: subtract == 1);
              fp1.put(fv1.value);
              fp2.put(fv2.value);

              final computed = adder.sum.floatingPointValue;
              final expectedNoRound = fpvPopulator().add(fv1, fv2,
                  roundingMode: FloatingPointRoundingMode.truncate);
              final expectedRound = fpvPopulator().add(fv1, fv2);
              expect(computed.isNaN, equals(expectedRound.isNaN));
              if (!computed.isNaN) {
                expect(computed, equals(expectedRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedNoRound (${expectedNoRound.toDouble()})\texpectedNo
      $expectedRound (${expectedRound.toDouble()})\texpectedRnd
''');
              }
            }
          }
        }
      }
    }
  });

  group('FP: simple adder narrow tests', () {
    tearDown(() async {
      await Simulator.reset();
    });
    const exponentWidth = 4;
    const mantissaWidth = 4;
    FloatingPoint fpConstructor() => FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp1 = fpConstructor();
    final fp2 = fpConstructor();

    FloatingPointValuePopulator fpvPopulator() => fp1.valuePopulator();
    FloatingPointValue ofString(String s) =>
        fpvPopulator().ofSpacedBinaryString(s);

    fp1.put(0);
    fp2.put(0);
    test('FP: simple adder narrow corner tests', () {
      final testCases = [
        (ofString('0 0001 0000'), ofString('0 0000 0000')),
        // subnormal from ae=1 s1=1, chop
        (ofString('0 0000 0001'), ofString('1 0001 0000')),
        // ae=0, l1=0 -- don't chop the leading digit
        (ofString('0 0000 0000'), ofString('1 0000 1000')),
        // requires unrounded comparison
        (ofString('0 0000 0001'), ofString('1 0010 0010')),
        // fix for shifting by l1
        (ofString('0 0000 0010'), ofString('1 0010 0000')),
        // circle back ae=1 l1=1, shift, do not chop
        (ofString('0 0000 0001'), ofString('1 0001 0000')),
        // Large exponent difference requires rounding?
        (ofString('0 0000 0001'), ofString('1 0111 0000')),
        // This one wants no rounding
        (ofString('0 0000 0001'), ofString('1 0011 0000')),
        // wants rounding
        (ofString('0 0000 0001'), ofString('1 0101 0000')),
        //  here a=7, l1=0, we need to add 1
        (ofString('0 0111 0000'), ofString('0 0111 0000')),
        // Needs a shift of 1 when ae = 0 and l1 > ae and subnormal
        (ofString('0 0000 0000'), ofString('0 0000 0001')),
        // needs to shift 1 more and add to exponent a = 0 l1=0 when adding
        (ofString('0 0000 0010'), ofString('0 0000 1110')),
        // counterexample to adding 1 to exponent a = 0 l1=14
        (ofString('0 0000 0000'), ofString('0 0000 0000')),
        //another counterexample:  adding 1 to many to exp
        (ofString('0 0000 0001'), ofString('0 0000 0001')),
        // catastrophic cancellation
        (ofString('0 1100 0000'), ofString('1 1100 0000')),
      ];
      final adder = FloatingPointAdderSinglePath(fp1, fp2);

      for (final test in testCases) {
        final fv1 = test.$1;
        final fv2 = test.$2;
        fp1.put(fv1.value);
        fp2.put(fv2.value);

        final expectedNoRound = fpvPopulator()
            .add(fv1, fv2, roundingMode: FloatingPointRoundingMode.truncate);

        final computed = adder.sum.floatingPointValue;
        final expectedRound = fpvPopulator().add(fv1, fv2);
        expect(computed, equals(expectedRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedNoRound (${expectedNoRound.toDouble()})\texpected
''');
      }
    });

    test('FP: simple adder narrow singleton test', () {
      fp1.put(ofString('0 1100 0000'));
      fp2.put(ofString('1 1100 0000'));
      final adder = FloatingPointAdderSinglePath(fp1, fp2);

      final fv1 = fp1.floatingPointValue;
      final fv2 = fp2.floatingPointValue;
      final expectedNoRound = fpvPopulator()
          .add(fv1, fv2, roundingMode: FloatingPointRoundingMode.truncate);
      expect(adder.sum.floatingPointValue, equals(expectedNoRound));
    });

    test('FP: simple adder singleton pipelined path', () async {
      final clk = SimpleClockGenerator(10).clk;
      fp1.put(ofString('1 1100 1100'));
      fp2.put(ofString('0 1101 0000'));

      final fv1 = fp1.floatingPointValue;
      final fv2 = fp2.floatingPointValue;
      final expectedNoRound = fpvPopulator()
          .add(fv1, fv2, roundingMode: FloatingPointRoundingMode.truncate);

      final FloatingPointValue expected;
      expected = expectedNoRound;
      final adder = FloatingPointAdderSinglePath(clk: clk, fp1, fp2);
      await adder.build();
      unawaited(Simulator.run());
      await clk.nextNegedge;
      fp1.put(0);
      fp2.put(0);

      final computed = adder.sum.floatingPointValue;
      expect(computed, equals(expected));
      await Simulator.endSimulation();
    });

    test('FP: adder simple pipeline random', () async {
      await Simulator.reset();

      final clk = SimpleClockGenerator(10).clk;
      fp1.put(0);
      fp2.put(0);

      final adder = FloatingPointAdderSinglePath(clk: clk, fp1, fp2);
      await adder.build();
      unawaited(Simulator.run());

      final rand = Random(513);

      for (var i = 0; i < 100; i++) {
        final fv1 = fpvPopulator().random(rand, genSubNormal: false);
        final fv2 = fpvPopulator().random(rand, genSubNormal: false);

        fp1.put(fv1.value);
        fp2.put(fv2.value);
        await clk.nextNegedge;
        fp1.put(0);
        fp2.put(0);

        final computed = adder.sum.floatingPointValue;

        final expectedNoRound = fpvPopulator()
            .add(fv1, fv2, roundingMode: FloatingPointRoundingMode.truncate);
        final expectedRound = fpvPopulator().add(fv1, fv2);
        expect(computed.isNaN, equals(expectedRound.isNaN));
        if (!computed.isNaN) {
          expect(computed, equals(expectedRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedNoRound (${expectedNoRound.toDouble()})\texpected
''');
        }
      }
      await Simulator.endSimulation();
    });
  });

  test('FP: adder simple wide mantissa singleton', () async {
    const exponentWidth = 2;
    const mantissaWidth = 8;
    FloatingPoint fpConstructor() => FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp1 = fpConstructor();
    final fp2 = fpConstructor();
    final fpout = fpConstructor();
    FloatingPointValuePopulator fpvPopulator() => fp1.valuePopulator();

    fp1.put(0);
    fp2.put(0);

    final adder = FloatingPointAdderSinglePath(fp1, fp2, outSum: fpout);
    final fv1 =
        fpvPopulator().ofLogicValue(LogicValue.ofRadixString("23'h50bd0d"));
    final fv2 =
        fpvPopulator().ofLogicValue(LogicValue.ofRadixString("23'h4ff000"));

    fp1.put(fv1.value);
    fp2.put(fv2.value);

    final computed = adder.sum.floatingPointValue;

    final expectedNoRound = fpvPopulator()
        .add(fv1, fv2, roundingMode: FloatingPointRoundingMode.truncate);

    final expectedRound = fpvPopulator().add(fv1, fv2);
    expect(computed, equals(expectedRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedRound (${expectedRound.toDouble()})\texpectedRnd
      $expectedNoRound (${expectedNoRound.toDouble()})\texpectedNo
''');
  });

  test('FP: adder simple wide mantissa random', () async {
    const exponentWidth = 2;
    const mantissaWidth = 20;
    FloatingPoint fpConstructor() => FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp1 = fpConstructor();
    final fp2 = fpConstructor();
    final fpout = fpConstructor();
    FloatingPointValuePopulator fpvPopulator() => fp1.valuePopulator();

    fp1.put(0);
    fp2.put(0);

    final adder = FloatingPointAdderSinglePath(fp1, fp2, outSum: fpout);
    await adder.build();
    unawaited(Simulator.run());

    final rand = Random(513);

    for (var i = 0; i < 100; i++) {
      final fv1 = fpvPopulator().random(rand);
      final fv2 = fpvPopulator().random(rand);

      fp1.put(fv1.value);
      fp2.put(fv2.value);

      final computed = adder.sum.floatingPointValue;

      final expectedNoRound = fpvPopulator()
          .add(fv1, fv2, roundingMode: FloatingPointRoundingMode.truncate);

      final expectedRound = fpvPopulator().add(fv1, fv2);
      expect(computed.isNaN, equals(expectedRound.isNaN));
      if (computed.isNaN) {
        expect(computed, equals(expectedRound), reason: '''
      $fv1 ${fv1.value} (${fv1.toDouble()})\t+
      $fv2 ${fv2.value} (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedRound (${expectedRound.toDouble()})\texpectedRnd
      $expectedNoRound (${expectedNoRound.toDouble()})\texpectedNo
''');
      }
    }
  });

  test('FP: adder simple wide exponent random', () async {
    const exponentWidth = 5;
    const mantissaWidth = 3;
    FloatingPoint fpConstructor() => FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp1 = fpConstructor();
    final fp2 = fpConstructor();
    FloatingPointValuePopulator fpvPopulator() => fp1.valuePopulator();

    fp1.put(0);
    fp2.put(0);

    final adder = FloatingPointAdderSinglePath(fp1, fp2);
    await adder.build();

    final rand = Random(513);

    for (var i = 0; i < 500; i++) {
      final fv1 = fpvPopulator().random(rand);
      final fv2 = fpvPopulator().random(rand);

      fp1.put(fv1.value);
      fp2.put(fv2.value);

      final computed = adder.sum.floatingPointValue;

      final expectedNoRound = fpvPopulator()
          .add(fv1, fv2, roundingMode: FloatingPointRoundingMode.truncate);
      final expectedRound = fpvPopulator().add(fv1, fv2);
      expect(computed.isNaN, equals(expectedRound.isNaN));
      if (computed.isNaN) {
        expect(computed, equals(expectedRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedNoRound (${expectedNoRound.toDouble()})\texpected
''');
      }
    }
  });

  test('FP: adder simple exponent difference sweep', () {
    // Resolves the TO-DO asking for the maximum exponent difference worth
    // testing as a function of mantissa width: once the exponent difference
    // exceeds the adder's internal `extendedWidth` (roughly
    // mantissaWidth + 2), the smaller operand is fully absorbed into the
    // sticky bit and further increasing the difference cannot change the
    // result. This test sweeps the exponent difference from 0 through well
    // past that saturation point (for both same-sign addition and
    // differing-sign subtraction) and checks against the value-side oracle.
    const exponentWidth = 5;
    const mantissaWidth = 4;
    FloatingPoint fpConstructor() => FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp1 = fpConstructor();
    final fp2 = fpConstructor();
    FloatingPointValuePopulator fpvPopulator() => fp1.valuePopulator();

    fp1.put(0);
    fp2.put(0);
    final adder = FloatingPointAdderSinglePath(fp1, fp2);

    const maxExpDiff = 12; // well beyond the saturation point for mW=4.
    const baseExponent = 20; // large enough to subtract maxExpDiff from.
    for (final mant1 in [0, 1, pow(2, mantissaWidth).toInt() - 1]) {
      for (final mant2 in [0, 1, pow(2, mantissaWidth).toInt() - 1]) {
        for (var expDiff = 0; expDiff <= maxExpDiff; expDiff++) {
          for (final sign2 in [false, true]) {
            final fv1 = fpvPopulator().ofInts(baseExponent, mant1);
            final fv2 = fpvPopulator()
                .ofInts(baseExponent - expDiff, mant2, sign: sign2);
            fp1.put(fv1);
            fp2.put(fv2);
            final computed = adder.sum.floatingPointValue;
            final expected = fpvPopulator().add(fv1, fv2);
            expect(computed, equals(expected), reason: '''
        $fv1 (${fv1.toDouble()})\t+
        $fv2 (${fv2.toDouble()})\t=
        $computed (${computed.toDouble()})\tcomputed
        $expected (${expected.toDouble()})\texpected
        expDiff=$expDiff
''');
          }
        }
      }
    }
  });

  test('FP: simple widening mantissa singleton', () {
    const exponentWidth = 4;
    const mantissaWidth = 4;
    const outMantissaWidth = 20;
    FloatingPoint fpConstructor() => FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp1 = fpConstructor();
    final fp2 = fpConstructor();
    final fpOut = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: outMantissaWidth);
    FloatingPointValuePopulator fpvPopulator() => fp1.valuePopulator();
    FloatingPointValue ofString(String s) =>
        fpvPopulator().ofSpacedBinaryString(s);
    FloatingPointValuePopulator fpvOutPopulator() => fpOut.valuePopulator();

    final fv1 = ofString('0 0000 0001');
    final fv2 = ofString('1 0000 0000');

    fp1.put(fv1);
    fp2.put(fv2);
    final adder = FloatingPointAdderSinglePath(fp1, fp2, outSum: fpOut);
    final computed = adder.sum.floatingPointValue;

    final expectedRound = fpvOutPopulator().add(fv1, fv2);
    final expectedNoRound = fpvOutPopulator()
        .add(fv1, fv2, roundingMode: FloatingPointRoundingMode.truncate);

    expect(computed, equals(expectedRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedRound (${expectedRound.toDouble()})\texpectedRound
      $expectedNoRound (${expectedNoRound.toDouble()})\texpectedRoundNo
''');
  });

  test('FP: simple adder widening mantissa exhaustive', () {
    const exponentWidth = 3;
    const mantissaWidth = 3;
    FloatingPoint fpConstructor() => FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp1 = fpConstructor();
    final fp2 = fpConstructor();
    FloatingPointValuePopulator fpvPopulator() => fp1.valuePopulator();

    for (final outMantissaWidth in [6, 9]) {
      final fpOut = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: outMantissaWidth);
      FloatingPointValuePopulator fpvOutPopulator() => fpOut.valuePopulator();
      fp1.put(0);
      fp2.put(0);
      final adder = FloatingPointAdderSinglePath(fp1, fp2, outSum: fpOut);

      for (final subtract in [1, 0]) {
        final expLimit = pow(2, exponentWidth);
        final mantLimit = pow(2, mantissaWidth);
        for (var e1 = 0; e1 < expLimit; e1++) {
          for (var m1 = 0; m1 < mantLimit; m1++) {
            final fv1 = fpvPopulator().ofInts(e1, m1);
            for (var e2 = 0; e2 < expLimit; e2++) {
              for (var m2 = 0; m2 < mantLimit; m2++) {
                final fv2 = fpvPopulator().ofInts(e2, m2, sign: subtract == 1);
                fp1.put(fv1.value);
                fp2.put(fv2.value);

                final computed = adder.sum.floatingPointValue;
                final expectedNoRound = fpvOutPopulator().add(fv1, fv2,
                    roundingMode: FloatingPointRoundingMode.truncate);
                final expectedRound = fpvOutPopulator().add(fv1, fv2);
                expect(computed.isNaN, equals(expectedRound.isNaN));
                if (!computed.isNaN) {
                  expect(computed, equals(expectedRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedNoRound (${expectedNoRound.toDouble()})\texpectedNo
      $expectedRound (${expectedRound.toDouble()})\texpectedRnd
''');
                }
              }
            }
          }
        }
      }
    }
  });

  test('FP: widening mantissa with wide exponent stays exact', () {
    // Resolves a self-doubting TO-DO about whether `outExtendedWidth` (used
    // to position rounding within a widened output mantissa) mistakenly
    // stays pinned to the input mantissa width instead of scaling with a
    // much wider output format. Combines a wide exponent (allowing a large
    // shift amount) with a large widening (mantissaWidth 4 -> 30) so any
    // lost precision would show up as a mismatch against the exact
    // value-side oracle.
    const exponentWidth = 6;
    const mantissaWidth = 4;
    const outMantissaWidth = 30;
    FloatingPoint fpConstructor() => FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp1 = fpConstructor();
    final fp2 = fpConstructor();
    final fpOut = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: outMantissaWidth);
    FloatingPointValuePopulator fpvPopulator() => fp1.valuePopulator();
    FloatingPointValuePopulator fpvOutPopulator() => fpOut.valuePopulator();

    fp1.put(0);
    fp2.put(0);
    final adder = FloatingPointAdderSinglePath(fp1, fp2, outSum: fpOut);

    for (final subtract in [false, true]) {
      for (var e1 = 20; e1 < 40; e1++) {
        for (var e2 = 0; e2 < 40; e2 += 3) {
          for (var m1 = 0; m1 < 16; m1 += 5) {
            for (var m2 = 0; m2 < 16; m2 += 5) {
              final fv1 = fpvPopulator().ofInts(e1, m1);
              final fv2 = fpvPopulator().ofInts(e2, m2, sign: subtract);
              fp1.put(fv1.value);
              fp2.put(fv2.value);
              final computed = adder.sum.floatingPointValue;
              final expected = fpvOutPopulator().add(fv1, fv2);
              expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
      e1=$e1 m1=$m1 e2=$e2 m2=$m2 subtract=$subtract
''');
            }
          }
        }
      }
    }
  });

  test('FP: leading-zero prediction needs the full extended-width search', () {
    // Resolves a TO-DO suggesting the leading-zero-anticipation search could
    // be narrowed to skip the low, extendedWidth-sized bits for
    // implicit-jbit (non-explicit) outputs. Verified empirically that
    // narrowing this way is unsafe: when the larger operand's high bits are
    // entirely zero, the true leading one can only be found within the low
    // bits, so the full combined width must be searched regardless of
    // explicitJBit. This is a minimal, non-explicit-jbit repro of that.
    const exponentWidth = 3;
    const mantissaWidth = 3;
    FloatingPoint fpConstructor() => FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp1 = fpConstructor();
    final fp2 = fpConstructor();
    FloatingPointValuePopulator fpvPopulator() => fp1.valuePopulator();
    fp1.put(0);
    fp2.put(0);
    final adder = FloatingPointAdderSinglePath(fp1, fp2);

    final fv1 = fpvPopulator().ofInts(0, 0); // 0.0
    final fv2 = fpvPopulator().ofInts(1, 0); // 0.25
    fp1.put(fv1.value);
    fp2.put(fv2.value);
    final computed = adder.sum.floatingPointValue;
    final expected = fpvPopulator().add(fv1, fv2);
    expect(computed, equals(expected));
  });

  group('FP: explicit-jbit addition', () {
    const exponentWidth = 3;
    const mantissaWidth = 3;

    FloatingPointValuePopulator fpvPopulator({required bool explicitJBit}) =>
        FloatingPointValue.populator(
            exponentWidth: exponentWidth,
            mantissaWidth: mantissaWidth,
            explicitJBit: explicitJBit);
    FloatingPointValue ofString(String s, {bool explicitJBit = false}) =>
        fpvPopulator(explicitJBit: explicitJBit).ofSpacedBinaryString(s);
    FloatingPoint fpConstructor({required bool explicitJBit}) => FloatingPoint(
        exponentWidth: exponentWidth,
        mantissaWidth: mantissaWidth,
        explicitJBit: explicitJBit);

    test('FP: simple adder mixed explicit/implicit j-bit IO singleton', () {
      const input1ExplicitJBit = false;
      const input2ExplicitJBit = false;
      const outputExplicitJBit = true;
      final fp1 = fpConstructor(explicitJBit: input1ExplicitJBit);
      final fp2 = fpConstructor(explicitJBit: input2ExplicitJBit);
      final fpOut = fpConstructor(explicitJBit: outputExplicitJBit);

      // Subtraction fails from i to e should not round.
      final fv1 = ofString('0 000 001');
      final fv2 = ofString('1 110 011');

      fp1.put(fv1);
      fp2.put(fv2);
      final adder = FloatingPointAdderSinglePath(fp1, fp2, outSum: fpOut);
      final computed = fpOut
          .valuePopulator()
          .ofFloatingPointValue(adder.sum.floatingPointValue);
      final expectedNoRound = fpOut
          .valuePopulator()
          .add(fv1, fv2, roundingMode: FloatingPointRoundingMode.truncate);
      final expectedRound = fpOut.valuePopulator().add(fv1, fv2);

      expect(computed, predicate((e) => e == expectedRound), reason: '''
                  in1Explicit=$input1ExplicitJBit 
                  in2Explicit=$input2ExplicitJBit 
                  outExplicit=$outputExplicitJBit
                  $fv1 (${fv1.toDouble()})\t+
                  $fv2 (${fv2.toDouble()})\t=
                  $computed (${computed.toDouble()})\tcomputed
                  $expectedNoRound (${expectedNoRound.toDouble()})\texpectedUn
                  $expectedRound (${expectedRound.toDouble()})\texpected
''');
    });

    test('FP: simple adder with mixed explicit/implicit j-bit IO exhaustive',
        () {
      for (final input1ExplicitJBit in [false, true]) {
        for (final input2ExplicitJBit in [false, true]) {
          final fp1 = fpConstructor(explicitJBit: input1ExplicitJBit);
          final fp2 = fpConstructor(explicitJBit: input2ExplicitJBit);

          fp1.put(0);
          fp2.put(0);
          for (final outputExplicitJBit in [false, true]) {
            final fpOut = fpConstructor(explicitJBit: outputExplicitJBit);
            final adder = FloatingPointAdderSinglePath(fp1, fp2, outSum: fpOut);

            for (final subtract in [0, 1]) {
              final expLimit = pow(2, exponentWidth - 1);
              final mantLimit = pow(2, mantissaWidth - 1);
              for (var e1 = 0; e1 < expLimit; e1++) {
                for (var m1 = 0; m1 < mantLimit; m1++) {
                  final fv1 = fp1.valuePopulator().ofInts(e1, m1);
                  if (fv1.isLegalValue()) {
                    for (var e2 = 0; e2 < expLimit; e2++) {
                      for (var m2 = 0; m2 < mantLimit; m2++) {
                        final fv2 = fp2
                            .valuePopulator()
                            .ofInts(e2, m2, sign: subtract == 1);
                        if (fv2.isLegalValue()) {
                          fp1.put(fv1.value);
                          fp2.put(fv2.value);

                          final computed = fpOut
                              .valuePopulator()
                              .ofFloatingPointValue(
                                  adder.sum.floatingPointValue,
                                  canonicalizeExplicit: true);
                          final expectedNoRound = fpOut
                              .valuePopulator()
                              .add(fv1, fv2,
                                  roundingMode:
                                      FloatingPointRoundingMode.truncate)
                              .canonicalize();
                          final expectedRound = fpOut
                              .valuePopulator()
                              .add(fv1, fv2)
                              .canonicalize();
                          expect(computed.isNaN, equals(expectedRound.isNaN));
                          if (!computed.isNaN) {
                            expect(
                                computed, predicate((e) => e == expectedRound),
                                reason: '''
                  in1Explicit=$input1ExplicitJBit 
                  in2Explicit=$input2ExplicitJBit 
                  outExplicit=$outputExplicitJBit
                  $fv1 (${fv1.toDouble()})\t+
                  $fv2 (${fv2.toDouble()})\t=
                  $computed (${computed.toDouble()})\tcomputed
                  $expectedNoRound (${expectedNoRound.toDouble()})\texpectedUn
                  $expectedRound (${expectedRound.toDouble()})\texpected
                  e1=$e1 m1=$m1  e2=$e2 m2=$m2
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
      }
    });

    test('FP: simple adder mixed explicit/implicit j-bit IO singleton', () {
      const input1ExplicitJBit = false;
      const input2ExplicitJBit = true;
      const outputExplicitJBit = false;
      final fp1 = fpConstructor(explicitJBit: input1ExplicitJBit);
      final fp2 = fpConstructor(explicitJBit: input2ExplicitJBit);
      final fpOut = fpConstructor(explicitJBit: outputExplicitJBit);

      // Subtraction fails from i to e should not round
      var fv1 = ofString('0 000 001');
      var fv2 = ofString('1 110 011');
      // I/E->I  fails here both unrounded and rounded
      fv1 = ofString('0 000 000');
      fv2 = ofString('0 001 001', explicitJBit: input2ExplicitJBit);

      fp1.put(fv1);
      fp2.put(fv2);
      final adder = FloatingPointAdderSinglePath(fp1, fp2, outSum: fpOut);
      final computed = fpOut.valuePopulator().ofFloatingPointValue(
          adder.sum.floatingPointValue,
          canonicalizeExplicit: true);
      final expectedNoRound = fpOut
          .valuePopulator()
          .add(fv1, fv2, roundingMode: FloatingPointRoundingMode.truncate)
          .canonicalize();
      final expectedRound = fpOut.valuePopulator().add(fv1, fv2).canonicalize();

      expect(computed, predicate((e) => e == expectedRound), reason: '''
                  in1Explicit=$input1ExplicitJBit 
                  in2Explicit=$input2ExplicitJBit 
                  outExplicit=$outputExplicitJBit
                  $fv1 (${fv1.toDouble()})\t+
                  $fv2 (${fv2.toDouble()})\t=
                  $computed (${computed.toDouble()})\tcomputed
                  $expectedNoRound (${expectedNoRound.toDouble()})\texpectedUn
                  $expectedRound (${expectedRound.toDouble()})\texpected
''');
    });

    test(
        'FP: simple adder with mixed explicit/implicit j-bit IO '
        'widening exhaustive', () {
      for (final outMantissaWidth in [3, 6]) {
        FloatingPoint fpOutConstructor({bool explicitJBit = false}) =>
            FloatingPoint(
                exponentWidth: exponentWidth,
                mantissaWidth: outMantissaWidth,
                explicitJBit: explicitJBit);

        for (final input1ExplicitJBit in [false, true]) {
          for (final input2ExplicitJBit in [false, true]) {
            final fp1 = fpConstructor(explicitJBit: input1ExplicitJBit);
            final fp2 = fpConstructor(explicitJBit: input2ExplicitJBit);

            fp1.put(0);
            fp2.put(0);
            for (final outputExplicitJBit in [false, true]) {
              final fpOut = fpOutConstructor(explicitJBit: outputExplicitJBit);
              final adder =
                  FloatingPointAdderSinglePath(fp1, fp2, outSum: fpOut);

              for (final subtract in [0, 1]) {
                final expLimit = pow(2, exponentWidth - 1);
                final mantLimit = pow(2, mantissaWidth - 1);
                for (var e1 = 0; e1 < expLimit; e1++) {
                  for (var m1 = 0; m1 < mantLimit; m1++) {
                    final fv1 = fp1.valuePopulator().ofInts(e1, m1);
                    if (fv1.isLegalValue()) {
                      for (var e2 = 0; e2 < expLimit; e2++) {
                        for (var m2 = 0; m2 < mantLimit; m2++) {
                          final fv2 = fp2
                              .valuePopulator()
                              .ofInts(e2, m2, sign: subtract == 1);
                          if (fv2.isLegalValue()) {
                            fp1.put(fv1.value);
                            fp2.put(fv2.value);

                            final computed = fpOut
                                .valuePopulator()
                                .ofFloatingPointValue(
                                    adder.sum.floatingPointValue,
                                    canonicalizeExplicit: true);
                            final expectedNoRound = fpOut
                                .valuePopulator()
                                .add(fv1, fv2,
                                    roundingMode:
                                        FloatingPointRoundingMode.truncate)
                                .canonicalize();
                            final expectedRound = fpOut
                                .valuePopulator()
                                .add(fv1, fv2)
                                .canonicalize();

                            expect(computed.isNaN, equals(expectedRound.isNaN));
                            if (!computed.isNaN) {
                              expect(computed,
                                  predicate((e) => e == expectedRound),
                                  reason: '''
                  in1Explicit=$input1ExplicitJBit 
                  in2Explicit=$input2ExplicitJBit 
                  outExplicit=$outputExplicitJBit
                  outMantissa=$outMantissaWidth
                  $fv1 (${fv1.toDouble()})\t+
                  $fv2 (${fv2.toDouble()})\t=
                  $computed (${computed.toDouble()})\tcomputed
                  $expectedNoRound (${expectedNoRound.toDouble()})\texpectedUn
                  $expectedRound (${expectedRound.toDouble()})\texpected
                  e1=$e1 m1=$m1  e2=$e2 m2=$m2
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
        }
      }
    });
  });

  test('FP: simple j-bit adder wide mantissa random', () {
    const exponentWidth = 5;
    const mantissaWidth = 7;
    FloatingPoint fpConstructor({bool explicitJBit = false}) => FloatingPoint(
        exponentWidth: exponentWidth,
        mantissaWidth: mantissaWidth,
        explicitJBit: explicitJBit);
    FloatingPointValuePopulator fpvPopulator({bool explicitJBit = false}) =>
        FloatingPointValue.populator(
            exponentWidth: exponentWidth,
            mantissaWidth: mantissaWidth,
            explicitJBit: explicitJBit);

    final fp1 = fpConstructor(explicitJBit: true);
    final fp2 = fpConstructor(explicitJBit: true);
    final fpOut = fpConstructor();
    fp1.put(0);
    fp2.put(0);
    final adder = FloatingPointAdderSinglePath(fp1, fp2, outSum: fpOut);
    final rand = Random(513);
    for (var i = 0; i < 100; i++) {
      final fv1 = fp1.valuePopulator().random(rand);
      final fv2 = fp2.valuePopulator().random(rand);
      if (fv1.isLegalValue() & fv2.isLegalValue()) {
        fp1.put(fv1);
        fp2.put(fv2);
        final computed = adder.sum.floatingPointValue;

        final expectedNoRound = fpvPopulator()
            .add(fv1, fv2, roundingMode: FloatingPointRoundingMode.truncate);
        final expectedRound = fpvPopulator().add(fv1, fv2);
        expect(computed.isNaN, equals(expectedRound.isNaN));
        if (computed.isNaN) {
          expect(computed, equals(expectedRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedNoRound (${expectedNoRound.toDouble()})\texpected
''');
        }
      }
    }
  });

  test('FP: simple j-bit adder wide exponent random', () {
    const exponentWidth = 5;
    const mantissaWidth = 4;
    FloatingPoint fpConstructor({bool explicitJBit = false}) => FloatingPoint(
        exponentWidth: exponentWidth,
        mantissaWidth: mantissaWidth,
        explicitJBit: explicitJBit);
    FloatingPointValuePopulator fpvPopulator({bool explicitJBit = false}) =>
        FloatingPointValue.populator(
            exponentWidth: exponentWidth,
            mantissaWidth: mantissaWidth,
            explicitJBit: explicitJBit);

    final fp1 = fpConstructor(explicitJBit: true);
    final fp2 = fpConstructor(explicitJBit: true);
    final fpout = fpConstructor();
    fp1.put(0);
    fp2.put(0);
    final adder = FloatingPointAdderSinglePath(fp1, fp2, outSum: fpout);
    final rand = Random(513);
    for (var i = 0; i < 100; i++) {
      final fv1 = fp1.valuePopulator().random(rand);
      final fv2 = fp2.valuePopulator().random(rand);
      if (fv1.isLegalValue() & fv2.isLegalValue()) {
        if (fv1.isAnInfinity | fv2.isAnInfinity) {
          continue;
        }
        fp1.put(fv1);
        fp2.put(fv2);
        final computed = adder.sum.floatingPointValue;

        final expectedNoRound = fpvPopulator()
            .add(fv1, fv2, roundingMode: FloatingPointRoundingMode.truncate);
        final expectedRound = fpvPopulator().add(fv1, fv2);
        expect(computed.isNaN, equals(expectedRound.isNaN));
        if (!computed.isNaN) {
          expect(computed, equals(expectedRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedNoRound (${expectedNoRound.toDouble()})\texpected
''');
        }
      }
    }
  });

  group('FP: single-path adder DAZ/FTZ tests', () {
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
    test('FP: single-path adder DAZ/FTZ test exhaustive', () {
      for (final daz1 in [false, true]) {
        for (final daz2 in [false, true]) {
          for (final ftz in [false, true]) {
            final fp1 = fpConstructor(subNormalAsZero: daz1);
            final fp2 = fpConstructor(subNormalAsZero: daz2);
            final fpOut = fpConstructor(subNormalAsZero: ftz);

            fp1.put(0);
            fp2.put(0);
            final adder = FloatingPointAdderSinglePath(fp1, fp2, outSum: fpOut);
            for (final e1 in representativeExponents) {
              for (final m1 in representativeMantissas) {
                for (final sign1 in [false, true]) {
                  final fv1 = fp1.valuePopulator().ofInts(e1, m1, sign: sign1);
                  for (final e2 in representativeExponents) {
                    for (final m2 in representativeMantissas) {
                      for (final sign2 in [false, true]) {
                        final fv2 =
                            fp2.valuePopulator().ofInts(e2, m2, sign: sign2);

                        fp1.put(fv1.value);
                        fp2.put(fv2.value);
                        // This will interpret the adder.sum value as
                        // a FloatingPointValue without the sumNormalAsZero
                        // property set, so we can validate it is indeed zero.
                        final computed = fpvPopulator()
                            .ofFloatingPointValue(adder.sum.floatingPointValue);

                        final expectedRound =
                            fpOut.valuePopulator().add(fv1, fv2);
                        final expected = expectedRound;
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
}
