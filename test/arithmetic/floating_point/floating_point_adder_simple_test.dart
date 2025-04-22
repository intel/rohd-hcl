// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_simple test.dart
// Tests of FloatingPointAdderSimple -- non-rounding FP adder
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

  test('FP: simple wide singleton test', () {
    const exponentWidth = 4;
    const mantissaWidth = 18;
    FloatingPointValue ofString(String s) =>
        FloatingPointValue.ofSpacedBinaryString(s);

    final fv1 = ofString('0 0000 101011100101000000');
    final fv2 = ofString('1 0001 100100101111011100');
    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    fp1.put(fv1);
    fp2.put(fv2);
    final adder = FloatingPointAdderSimple(fp1, fp2);

    final computed = adder.sum.floatingPointValue;

    final expectedDouble = fv1.toDouble() + fv2.toDouble();

    final expectedRound = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofDouble(expectedDouble);
    final expectedNoRound = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofDoubleUnrounded(expectedDouble);

    expect(computed, equals(expectedRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedRound (${expectedRound.toDouble()})\texpectedRound
      $expectedNoRound (${expectedNoRound.toDouble()})\texpectedRoundNo
''');
  });

  test('FP: simple adder random', () {
    const exponentWidth = 9;
    const mantissaWidth = 15;

    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    fp1.put(0);
    fp2.put(0);
    final adder = FloatingPointAdderSimple(fp1, fp2);
    final rand = Random(513);
    for (var i = 0; i < 500; i++) {
      final fv1 = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .random(rand);
      final fv2 = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .random(rand);
      if ((fv1.exponent.toInt() - fv2.exponent.toInt()).abs() >
          51 - mantissaWidth) {
        // Native double math cannot verify unrounded result
        continue;
      }
      fp1.put(fv1);
      fp2.put(fv2);

      final computed = adder.sum.floatingPointValue;

      final expectedDouble =
          fp1.floatingPointValue.toDouble() + fp2.floatingPointValue.toDouble();

      final expectedNoRound = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .ofDoubleUnrounded(expectedDouble);
      final expectedRound = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .ofDouble(expectedDouble);
      expect(computed, equals(expectedRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedNoRound (${expectedNoRound.toDouble()})\texpected
      $expectedRound (${expectedRound.toDouble()})\texpectedRnd
''');
    }
  });

  test('FP: simple new singleton test', () {
    const exponentWidth = 4;
    const mantissaWidth = 4;
    FloatingPointValue ofString(String s) =>
        FloatingPointValue.ofSpacedBinaryString(s);
    final fv1 = ofString('0 0000 0001');
    final fv2 = ofString('1 0000 0000');

    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    fp1.put(fv1);
    fp2.put(fv2);
    final adder = FloatingPointAdderSimple(fp1, fp2);
    final computed = adder.sum.floatingPointValue;

    final expectedDouble = fv1.toDouble() + fv2.toDouble();

    final expectedRound = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofDouble(expectedDouble);
    final expectedNoRound = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofDoubleUnrounded(expectedDouble);

    expect(computed, equals(expectedRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedRound (${expectedRound.toDouble()})\texpectedRound
      $expectedNoRound (${expectedNoRound.toDouble()})\texpectedRoundNo
''');
  });

  test('FP: simple adder exhaustive', () {
    const exponentWidth = 4;
    const mantissaWidth = 4;
    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    fp1.put(0);
    fp2.put(0);
    final adder = FloatingPointAdderSimple(fp1, fp2);

    for (final subtract in [1, 0]) {
      final expLimit = pow(2, exponentWidth);
      final mantLimit = pow(2, mantissaWidth);
      for (var e1 = 0; e1 < expLimit; e1++) {
        for (var m1 = 0; m1 < mantLimit; m1++) {
          final fv1 = FloatingPointValue.populator(
                  exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
              .ofInts(e1, m1);
          for (var e2 = 0; e2 < expLimit; e2++) {
            for (var m2 = 0; m2 < mantLimit; m2++) {
              final fv2 = FloatingPointValue.populator(
                      exponentWidth: exponentWidth,
                      mantissaWidth: mantissaWidth)
                  .ofInts(e2, m2, sign: subtract == 1);
              fp1.put(fv1.value);
              fp2.put(fv2.value);

              final computed = adder.sum.floatingPointValue;
              final dbl = fv1.toDouble() + fv2.toDouble();
              final expectedNoRound = FloatingPointValue.populator(
                      exponentWidth: exponentWidth,
                      mantissaWidth: mantissaWidth)
                  .ofDoubleUnrounded(dbl);
              final expectedRound = FloatingPointValue.populator(
                      exponentWidth: exponentWidth,
                      mantissaWidth: mantissaWidth)
                  .ofDouble(dbl);
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
  });

  group('FP: simple adder narrow tests', () {
    tearDown(() async {
      await Simulator.reset();
    });
    const exponentWidth = 4;
    const mantissaWidth = 4;

    FloatingPointValue ofString(String s) =>
        FloatingPointValue.ofSpacedBinaryString(s);

    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
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
      final adder = FloatingPointAdderSimple(fp1, fp2);

      for (final test in testCases) {
        final fv1 = test.$1;
        final fv2 = test.$2;
        fp1.put(fv1.value);
        fp2.put(fv2.value);
        final expectedDouble = fp1.floatingPointValue.toDouble() +
            fp2.floatingPointValue.toDouble();

        final expectedNoRound = FloatingPointValue.populator(
                exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
            .ofDoubleUnrounded(expectedDouble);

        final computed = adder.sum.floatingPointValue;
        final expectedRound = FloatingPointValue.populator(
                exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
            .ofDouble(fv1.toDouble() + fv2.toDouble());
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
      final adder = FloatingPointAdderSimple(fp1, fp2);

      final expectedDouble =
          fp1.floatingPointValue.toDouble() + fp2.floatingPointValue.toDouble();

      final expectedNoRound = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .ofDoubleUnrounded(expectedDouble);
      expect(adder.sum.floatingPointValue, equals(expectedNoRound));
    });

    test('FP: simple adder singleton pipelined path', () async {
      final clk = SimpleClockGenerator(10).clk;
      fp1.put(ofString('1 1100 1100'));
      fp2.put(ofString('0 1101 0000'));

      final expectedDouble =
          fp1.floatingPointValue.toDouble() + fp2.floatingPointValue.toDouble();

      final expectedNoRound = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .ofDoubleUnrounded(expectedDouble);

      final FloatingPointValue expected;
      expected = expectedNoRound;
      final adder = FloatingPointAdderSimple(clk: clk, fp1, fp2);
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

      final adder = FloatingPointAdderSimple(clk: clk, fp1, fp2);
      await adder.build();
      unawaited(Simulator.run());

      final rand = Random(513);

      for (var i = 0; i < 500; i++) {
        final fv1 = FloatingPointValue.populator(
                exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
            .random(rand, normal: true);
        final fv2 = FloatingPointValue.populator(
                exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
            .random(rand, normal: true);

        fp1.put(fv1.value);
        fp2.put(fv2.value);
        await clk.nextNegedge;
        fp1.put(0);
        fp2.put(0);

        final computed = adder.sum.floatingPointValue;

        final expectedNoRound = FloatingPointValue.populator(
                exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
            .ofDoubleUnrounded(fv1.toDouble() + fv2.toDouble());
        final expectedRound = FloatingPointValue.populator(
                exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
            .ofDouble(fv1.toDouble() + fv2.toDouble());
        expect(computed, equals(expectedRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedNoRound (${expectedNoRound.toDouble()})\texpected
''');
      }
      await Simulator.endSimulation();
    });
  });

  test('FP: adder simple wide mantissa random', () async {
    const exponentWidth = 2;
    const mantissaWidth = 20;
    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    fp1.put(0);
    fp2.put(0);

    final adder = FloatingPointAdderSimple(fp1, fp2);
    await adder.build();
    unawaited(Simulator.run());

    final rand = Random(513);

    for (var i = 0; i < 500; i++) {
      final fv1 = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .random(rand);
      final fv2 = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .random(rand);

      fp1.put(fv1.value);
      fp2.put(fv2.value);

      final computed = adder.sum.floatingPointValue;

      final expectedNoRound = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .ofDoubleUnrounded(fv1.toDouble() + fv2.toDouble());

      final expectedRound = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .ofDouble(fv1.toDouble() + fv2.toDouble());
      expect(computed, equals(expectedRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedNoRound (${expectedNoRound.toDouble()})\texpected
''');
    }
  });

  test('FP: adder simple wide exponent random', () async {
    const exponentWidth = 10;
    const mantissaWidth = 3;
    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    fp1.put(0);
    fp2.put(0);

    final adder = FloatingPointAdderSimple(fp1, fp2);
    await adder.build();

    final rand = Random(513);

    for (var i = 0; i < 5000; i++) {
      final fv1 = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .random(rand);
      final fv2 = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .random(rand);
      if ((fv1.exponent.toInt() - fv2.exponent.toInt()).abs() >
          51 - mantissaWidth) {
        // Native double math cannot verify unrounded result
        continue;
      }

      fp1.put(fv1.value);
      fp2.put(fv2.value);

      final computed = adder.sum.floatingPointValue;

      final expectedNoRound = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .ofDoubleUnrounded(fv1.toDouble() + fv2.toDouble());
      final expectedRound = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .ofDouble(fv1.toDouble() + fv2.toDouble());
      expect(computed, equals(expectedRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedNoRound (${expectedNoRound.toDouble()})\texpected
''');
    }
  });

// TODO(desmonddak): Find the maximum exponent difference as a
// function of mantissa width that we can use in testing using
// e1 0001 - e2 -0001  and sweeping e1 and e2 diff
  test('FP: simple adder with explicit j-bit singleton', () {
    const exponentWidth = 8;
    const mantissaWidth = 24;
    FloatingPointExplicitJBitValue ofString(String s) =>
        FloatingPointExplicitJBitValue.ofSpacedBinaryString(s);

    final fp1 = FloatingPointExplicitJBit(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPointExplicitJBit(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fv1 = ofString('0 10000010 100100000000000000000000');
    final fv2 = ofString('0 00000000 000000000000000000000000');

    fp1.put(fv1);
    fp2.put(fv2);
    final adder = FloatingPointAdderSimple(fp1, fp2);
    final computed = adder.sum.floatingPointValue;

    final expectedDouble = fv1.toDouble() + fv2.toDouble();

    final expectedRound = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofDouble(expectedDouble);
    final expectedNoRound = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofDoubleUnrounded(expectedDouble);

    expect(computed, equals(expectedRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedRound (${expectedRound.toDouble()})\texpectedRound
      $expectedNoRound (${expectedNoRound.toDouble()})\texpectedRoundNo
''');
  });

  test('FP: simple adder with explicit j-bit exhaustive', () {
    const exponentWidth = 4;
    const mantissaWidth = 4;
    final fp1 = FloatingPointExplicitJBit(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPointExplicitJBit(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    fp1.put(0);
    fp2.put(0);
    final adder = FloatingPointAdderSimple(fp1, fp2);

    for (final subtract in [1, 0]) {
      final expLimit = pow(2, exponentWidth);
      final mantLimit = pow(2, mantissaWidth);
      for (var e1 = 0; e1 < expLimit; e1++) {
        for (var m1 = 0; m1 < mantLimit; m1++) {
          final fv1 = FloatingPointExplicitJBitValue.populator(
                  exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
              .ofInts(e1, m1);
          if (fv1.isLegalValue()) {
            for (var e2 = 0; e2 < expLimit; e2++) {
              for (var m2 = 0; m2 < mantLimit; m2++) {
                final fv2 = FloatingPointExplicitJBitValue.populator(
                        exponentWidth: exponentWidth,
                        mantissaWidth: mantissaWidth)
                    .ofInts(e2, m2, sign: subtract == 1);
                if (fv2.isLegalValue()) {
                  if ((fv1.exponent.toInt() - fv2.exponent.toInt()).abs() >
                      51 - mantissaWidth) {
                    // Native double math cannot verify unrounded result
                    continue;
                  }
                  fp1.put(fv1.value);
                  fp2.put(fv2.value);

                  final computed = adder.sum.floatingPointValue;
                  final expectedNoRound = FloatingPointValue.populator(
                          exponentWidth: exponentWidth,
                          mantissaWidth: mantissaWidth)
                      .ofDoubleUnrounded(fv1.toDouble() + fv2.toDouble());
                  final expectedRound = FloatingPointValue.populator(
                          exponentWidth: exponentWidth,
                          mantissaWidth: mantissaWidth)
                      .ofDouble(fv1.toDouble() + fv2.toDouble());

                  if (computed.isNaN &
                      (expectedNoRound.isNaN | expectedNoRound.isAnInfinity)) {
                    continue;
                  }
                  expect(computed, equals(expectedRound), reason: '''
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
  });

  test('FP: simple j-bit adder wide mantissa random', () {
    const exponentWidth = 8;
    const mantissaWidth = 25;

    final fp1 = FloatingPointExplicitJBit(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPointExplicitJBit(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    fp1.put(0);
    fp2.put(0);
    final adder = FloatingPointAdderSimple(fp1, fp2);
    final rand = Random(513);
    for (var i = 0; i < 500; i++) {
      final fv1 = FloatingPointExplicitJBitValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .random(rand);
      final fv2 = FloatingPointExplicitJBitValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .random(rand);
      if (fv1.isLegalValue() & fv2.isLegalValue()) {
        fp1.put(fv1);
        fp2.put(fv2);
        final computed = adder.sum.floatingPointValue;

        final expectedDouble = fp1.floatingPointExplicitJBitValue.toDouble() +
            fp2.floatingPointExplicitJBitValue.toDouble();

        final expectedNoRound = FloatingPointValue.populator(
                exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
            .ofDoubleUnrounded(expectedDouble);
        final expectedRound = FloatingPointValue.populator(
                exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
            .ofDouble(fv1.toDouble() + fv2.toDouble());
        expect(computed, equals(expectedRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedNoRound (${expectedNoRound.toDouble()})\texpected
''');
      }
    }
  });

  test('FP: simple j-bit adder wide exponent random', () {
    const exponentWidth = 6;
    const mantissaWidth = 4;

    final fp1 = FloatingPointExplicitJBit(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPointExplicitJBit(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    fp1.put(0);
    fp2.put(0);
    final adder = FloatingPointAdderSimple(fp1, fp2);
    final rand = Random(513);
    for (var i = 0; i < 5000; i++) {
      final fv1 = FloatingPointExplicitJBitValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .random(rand);
      final fv2 = FloatingPointExplicitJBitValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .random(rand);
      if (fv1.isLegalValue() & fv2.isLegalValue()) {
        if (fv1.isAnInfinity | fv2.isAnInfinity) {
          continue;
        }
        if ((fv1.exponent.toInt() - fv2.exponent.toInt()).abs() >
            51 - mantissaWidth) {
          // Native double math cannot verify unrounded result
          continue;
        }
        fp1.put(fv1);
        fp2.put(fv2);
        final computed = adder.sum.floatingPointValue;

        final expectedDouble = fp1.floatingPointExplicitJBitValue.toDouble() +
            fp2.floatingPointExplicitJBitValue.toDouble();

        final expectedNoRound = FloatingPointValue.populator(
                exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
            .ofDoubleUnrounded(expectedDouble);
        final expectedRound = FloatingPointValue.populator(
                exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
            .ofDouble(fv1.toDouble() + fv2.toDouble());
        expect(computed, equals(expectedRound), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedNoRound (${expectedNoRound.toDouble()})\texpected
''');
      }
    }
  });
}
