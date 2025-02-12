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
//

import 'dart:async';
import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('FP: simple adder random', () {
    const exponentWidth = 5;
    const mantissaWidth = 20;

    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    fp1.put(0);
    fp2.put(0);
    final adder = FloatingPointAdderSimple(fp1, fp2);
    final value = Random(513);
    for (var i = 0; i < 500; i++) {
      final fv1 = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .random(value);
      final fv2 = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .random(value);
      fp1.put(fv1);
      fp2.put(fv2);
      final computed = adder.sum.floatingPointValue;

      final expectedDouble =
          fp1.floatingPointValue.toDouble() + fp2.floatingPointValue.toDouble();

      final expectedNoRound = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .ofDoubleUnrounded(expectedDouble);
      expect(computed.withinRounding(expectedNoRound), true, reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedNoRound (${expectedNoRound.toDouble()})\texpected
''');
    }
  });

  test('FP: simple adder exhaustive', () {
    const exponentWidth = 6;
    const mantissaWidth = 2;

    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    fp1.put(0);
    fp2.put(0);
    final adder = FloatingPointAdderSimple(fp1, fp2);

    for (final subtract in [0, 1]) {
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
              final expectedNoRound = FloatingPointValue.populator(
                      exponentWidth: exponentWidth,
                      mantissaWidth: mantissaWidth)
                  .ofDoubleUnrounded(fv1.toDouble() + fv2.toDouble());

              expect(computed.withinRounding(expectedNoRound), true, reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedNoRound (${expectedNoRound.toDouble()})\texpected
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
        (ofString('0 1100 0000'), ofString('0 1100 0000')),
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
        expect(computed.withinRounding(expectedNoRound), true, reason: '''
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
      fp1.put(ofString('0 0000 0000'));
      fp2.put(ofString('0 0001 0000'));

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
      final clk = SimpleClockGenerator(10).clk;

      final adder = FloatingPointAdderSimple(clk: clk, fp1, fp2);
      await adder.build();
      unawaited(Simulator.run());

      final value = Random(513);

      for (var i = 0; i < 500; i++) {
        final fv1 = FloatingPointValue.populator(
                exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
            .random(value, normal: true);
        final fv2 = FloatingPointValue.populator(
                exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
            .random(value, normal: true);

        fp1.put(fv1.value);
        fp2.put(fv2.value);
        await clk.nextNegedge;
        fp1.put(0);
        fp2.put(0);

        final computed = adder.sum.floatingPointValue;

        final expectedNoRound = FloatingPointValue.populator(
                exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
            .ofDoubleUnrounded(fv1.toDouble() + fv2.toDouble());

        expect(computed.withinRounding(expectedNoRound), true, reason: '''
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

    final adder = FloatingPointAdderSimple(fp1, fp2);
    await adder.build();
    unawaited(Simulator.run());

    final value = Random(513);

    for (var i = 0; i < 500; i++) {
      final fv1 = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .random(value);
      final fv2 = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .random(value);

      fp1.put(fv1.value);
      fp2.put(fv2.value);

      final computed = adder.sum.floatingPointValue;

      final expectedNoRound = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .ofDoubleUnrounded(fv1.toDouble() + fv2.toDouble());

      expect(computed.withinRounding(expectedNoRound), true, reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedNoRound (${expectedNoRound.toDouble()})\texpected
''');
    }
  });

  test('FP: adder simple wide exponent random', () async {
    const exponentWidth = 10;
    const mantissaWidth = 2;
    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

    final adder = FloatingPointAdderSimple(fp1, fp2);
    await adder.build();

    final value = Random(513);

    for (var i = 0; i < 500; i++) {
      final fv1 = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .random(value);
      final fv2 = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .random(value);

      fp1.put(fv1.value);
      fp2.put(fv2.value);

      final computed = adder.sum.floatingPointValue;

      final expectedNoRound = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .ofDoubleUnrounded(fv1.toDouble() + fv2.toDouble());

      expect(computed.withinRounding(expectedNoRound), true, reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedNoRound (${expectedNoRound.toDouble()})\texpected
''');
    }
  });

  test('FP: simple adder general singleton test', () async {
    FloatingPointValue ofString(String s) =>
        FloatingPointValue.ofSpacedBinaryString(s);

    final fv1 = ofString('0 001 111111');
    final fv2 = ofString('1 010 000000');

    final fp1 = FloatingPoint(
        exponentWidth: fv1.exponent.width, mantissaWidth: fv1.mantissa.width);
    final fp2 = FloatingPoint(
        exponentWidth: fv2.exponent.width, mantissaWidth: fv2.mantissa.width);
    fp1.put(fv1);
    fp2.put(fv2);
    final adder = FloatingPointAdderSimple(fp1, fp2);
    await adder.build();

    final exponentWidth = adder.sum.exponent.width;
    final mantissaWidth = adder.sum.mantissa.width;

    final expectedDouble =
        fp1.floatingPointValue.toDouble() + fp2.floatingPointValue.toDouble();

    final expectedNoRound = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofDoubleUnrounded(expectedDouble);
    expect(adder.sum.floatingPointValue, equals(expectedNoRound));
  });
}
