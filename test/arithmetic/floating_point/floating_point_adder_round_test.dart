// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_rnd_test.dart
// Tests of FloatingPointAdderRound -- a rounding FP Adder.
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
  test('FP: rounding adder singleton N path', () async {
    const exponentWidth = 4;
    const mantissawidth = 5;
    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissawidth);
    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissawidth);

    final fv1 = FloatingPointValue.ofInts(14, 31,
        exponentWidth: exponentWidth, mantissaWidth: mantissawidth);
    final fv2 = FloatingPointValue.ofInts(13, 7,
        exponentWidth: exponentWidth, mantissaWidth: mantissawidth, sign: true);

    fp1.put(fv1);
    fp2.put(fv2);

    final expectedNoRound = FloatingPointValue.ofDoubleUnrounded(
        fv1.toDouble() + fv2.toDouble(),
        exponentWidth: exponentWidth,
        mantissaWidth: mantissawidth);
    final expected = expectedNoRound;

    final adder = FloatingPointAdderRound(fp1, fp2);

    unawaited(Simulator.run());

    final computed = adder.sum.floatingPointValue;
    expect(computed, equals(expected));
    await Simulator.endSimulation();
  });

  test('FP: rounding adder N path, subtraction, delta < 2', () async {
    const exponentWidth = 3;
    const mantissaWidth = 5;

    final one = FloatingPointValue.getFloatingPointConstant(
        FloatingPointConstants.one, exponentWidth, mantissaWidth);
    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    fp1.put(one);
    fp2.put(one);
    final adder = FloatingPointAdderRound(fp1, fp2);
    await adder.build();
    unawaited(Simulator.run());

    final largestExponent = FloatingPointValue.computeBias(exponentWidth) +
        FloatingPointValue.computeMaxExponent(exponentWidth);
    final largestMantissa = pow(2, mantissaWidth).toInt() - 1;
    for (var e1 = 0; e1 <= largestExponent; e1++) {
      for (var e2 = 0; e2 <= largestExponent; e2++) {
        if ((e1 - e2).abs() < 2) {
          for (var m1 = 0; m1 <= largestMantissa; m1++) {
            final fv1 = FloatingPointValue.ofInts(e1, m1,
                exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
            for (var m2 = 0; m2 <= largestMantissa; m2++) {
              final fv2 = FloatingPointValue.ofInts(e2, m2,
                  exponentWidth: exponentWidth,
                  mantissaWidth: mantissaWidth,
                  sign: true);

              fp1.put(fv1);
              fp2.put(fv2);
              // No rounding
              final expected = FloatingPointValue.ofDoubleUnrounded(
                  fv1.toDouble() + fv2.toDouble(),
                  exponentWidth: exponentWidth,
                  mantissaWidth: mantissaWidth);

              final computed = adder.sum.floatingPointValue;
              expect(computed, equals(expected));
            }
          }
        }
      }
    }
    await Simulator.endSimulation();
  });

  test('FP: rounding adder singleton R path', () async {
    final clk = SimpleClockGenerator(10).clk;

    const exponentWidth = 4;
    const mantissaWidth = 5;
    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    fp1.put(0);
    fp2.put(0);

    final fv1 = FloatingPointValue.ofInts(3, 11,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fv2 = FloatingPointValue.ofInts(11, 25,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth, sign: true);

    fp1.put(fv1);
    fp2.put(fv2);

    final expected = fv1 + fv2;
    final adder = FloatingPointAdderRound(clk: clk, fp1, fp2);
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

  test('FP: rounding adder R path, strict subnormal', () async {
    const exponentWidth = 4;
    const mantissaWidth = 5;

    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    fp1.put(0);
    fp2.put(0);
    final adder = FloatingPointAdderRound(fp1, fp2);
    await adder.build();
    unawaited(Simulator.run());

    final largestMantissa = pow(2, mantissaWidth).toInt() - 1;
    for (final sign in [false, true]) {
      for (var e1 = 0; e1 <= 1; e1++) {
        for (var e2 = 0; e2 <= 1; e2++) {
          if (!sign || (e1 - e2).abs() >= 2) {
            for (var m1 = 0; m1 <= largestMantissa; m1++) {
              final fv1 = FloatingPointValue.ofInts(e1, m1,
                  exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
              for (var m2 = 0; m2 <= largestMantissa; m2++) {
                final fv2 = FloatingPointValue.ofInts(e2, m2,
                    exponentWidth: exponentWidth,
                    mantissaWidth: mantissaWidth,
                    sign: sign);

                fp1.put(fv1);
                fp2.put(fv2);
                final expected = fv1 + fv2;
                final computed = adder.sum.floatingPointValue;
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
    await Simulator.endSimulation();
  });

  test('FP: rounding adder R path, full random', () async {
    final clk = SimpleClockGenerator(10).clk;

    const exponentWidth = 3;
    const mantissaWidth = 5;

    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    fp1.put(0);
    fp2.put(0);
    final adder = FloatingPointAdderRound(clk: clk, fp1, fp2);
    await adder.build();
    unawaited(Simulator.run());
    final value = Random(47);

    var cnt = 200;
    while (cnt > 0) {
      final fv1 = FloatingPointValue.random(value,
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fv2 = FloatingPointValue.random(value,
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      fp1.put(fv1);
      fp2.put(fv2);
      if ((fv1.exponent.toInt() - fv2.exponent.toInt()).abs() >= 2) {
        cnt--;
        final expected = fv1 + fv2;
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
      }
    }
    await Simulator.endSimulation();
  });

  test('FP: rounding adder singleton merged pipelined path', () async {
    final clk = SimpleClockGenerator(10).clk;

    const exponentWidth = 3;
    const mantissaWidth = 5;
    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    fp1.put(0);
    fp2.put(0);
    final fv1 = FloatingPointValue.ofInts(14, 31,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fv2 = FloatingPointValue.ofInts(13, 7,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth, sign: true);
    fp1.put(fv1);
    fp2.put(fv2);

    final expectedNoRound = FloatingPointValue.ofDoubleUnrounded(
        fv1.toDouble() + fv2.toDouble(),
        exponentWidth: exponentWidth,
        mantissaWidth: mantissaWidth);

    final FloatingPointValue expected;
    final expectedRound = fv1 + fv2;
    if (((fv1.exponent.toInt() - fv2.exponent.toInt()).abs() < 2) &
        (fv1.sign.toInt() != fv2.sign.toInt())) {
      expected = expectedNoRound;
    } else {
      expected = expectedRound;
    }
    final adder = FloatingPointAdderRound(clk: clk, fp1, fp2);
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

  test('FP: rounding adder full random wide', () async {
    const exponentWidth = 11;
    const mantissaWidth = 52;

    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    fp1.put(0);
    fp2.put(0);
    final adder = FloatingPointAdderRound(fp1, fp2);
    await adder.build();
    unawaited(Simulator.run());
    final value = Random(51);

    var cnt = 100;
    while (cnt > 0) {
      final fv1 = FloatingPointValue.random(value,
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fv2 = FloatingPointValue.random(value,
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      fp1.put(fv1);
      fp2.put(fv2);
      final expected = fv1 + fv2;
      final computed = adder.sum.floatingPointValue;
      expect(computed.isNaN, equals(expected.isNaN));
      expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
      cnt--;
    }
    await Simulator.endSimulation();
  });

  test('FP: rounding adder singleton merged path', () async {
    const exponentWidth = 3;
    const mantissaWidth = 5;
    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    fp1.put(0);
    fp2.put(0);
    final fv1 = FloatingPointValue.ofInts(14, 31,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fv2 = FloatingPointValue.ofInts(13, 7,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth, sign: true);
    fp1.put(fv1);
    fp2.put(fv2);

    final expectedNoRound = FloatingPointValue.ofDoubleUnrounded(
        fv1.toDouble() + fv2.toDouble(),
        exponentWidth: exponentWidth,
        mantissaWidth: mantissaWidth);

    final FloatingPointValue expected;
    final expectedRound = fv1 + fv2;
    if (((fv1.exponent.toInt() - fv2.exponent.toInt()).abs() < 2) &
        (fv1.sign.toInt() != fv2.sign.toInt())) {
      expected = expectedNoRound;
    } else {
      expected = expectedRound;
    }
    final adder = FloatingPointAdderRound(fp1, fp2);

    final computed = adder.sum.floatingPointValue;
    expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
  });

  test('FP: rounding adder singleton', () async {
    const exponentWidth = 4;
    const mantissaWidth = 4;
    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    fp1.put(0);
    fp2.put(0);
    final fv1 = FloatingPointValue.ofBinaryStrings('0', '1100', '0000');
    final fv2 = FloatingPointValue.ofBinaryStrings('1', '1100', '0000');

    fp1.put(fv1);
    fp2.put(fv2);

    final expectedNoRound = FloatingPointValue.ofDoubleUnrounded(
        fv1.toDouble() + fv2.toDouble(),
        exponentWidth: exponentWidth,
        mantissaWidth: mantissaWidth);

    final FloatingPointValue expected;
    final expectedRound = fv1 + fv2;
    if (((fv1.exponent.toInt() - fv2.exponent.toInt()).abs() < 2) &
        (fv1.sign.toInt() != fv2.sign.toInt())) {
      expected = expectedNoRound;
    } else {
      expected = expectedRound;
    }
    final adder = FloatingPointAdderRound(fp1, fp2);

    final computed = adder.sum.floatingPointValue;
    expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
  });

  test('FP: rounding adder exhaustive', () {
    const exponentWidth = 4;
    const mantissaWidth = 4;

    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final adder = FloatingPointAdderRound(fp1, fp2);

    final expLimit = pow(2, exponentWidth);
    final mantLimit = pow(2, mantissaWidth);
    for (final subtract in [0, 1]) {
      for (var e1 = 0; e1 < expLimit; e1++) {
        for (var m1 = 0; m1 < mantLimit; m1++) {
          final fv1 = FloatingPointValue.ofInts(e1, m1,
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
          for (var e2 = 0; e2 < expLimit; e2++) {
            for (var m2 = 0; m2 < mantLimit; m2++) {
              final fv2 = FloatingPointValue.ofInts(e2, m2,
                  exponentWidth: exponentWidth,
                  mantissaWidth: mantissaWidth,
                  sign: subtract == 1);

              fp1.put(fv1.value);
              fp2.put(fv2.value);
              final computed = adder.sum.floatingPointValue;
              final expectedDouble = fv1.toDouble() + fv2.toDouble();

              final FloatingPointValue expected;
              if ((subtract == 1) &
                  ((fv1.exponent.toInt() - fv2.exponent.toInt()).abs() < 2)) {
                expected = FloatingPointValue.ofDoubleUnrounded(expectedDouble,
                    exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
              } else {
                expected = FloatingPointValue.ofDouble(expectedDouble,
                    exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
              }

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
  });
  test('FP: rounding adder general singleton test', () {
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
    final adder = FloatingPointAdderRound(fp1, fp2);
    final exponentWidth = adder.sum.exponent.width;
    final mantissaWidth = adder.sum.mantissa.width;

    final expectedDouble =
        fp1.floatingPointValue.toDouble() + fp2.floatingPointValue.toDouble();

    final expectedNoRound = FloatingPointValue.ofDoubleUnrounded(expectedDouble,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    expect(adder.sum.floatingPointValue, equals(expectedNoRound));
  });
  test('FP: rounding with prefix adder', () async {
    final clk = SimpleClockGenerator(10).clk;

    const eWidth = 3;
    const mWidth = 5;
    final fa = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    final fb = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    fa.put(0);
    fb.put(0);
    final fv1 = FloatingPointValue.ofInts(14, 31,
        exponentWidth: eWidth, mantissaWidth: mWidth);
    final fv2 = FloatingPointValue.ofInts(13, 7,
        exponentWidth: eWidth, mantissaWidth: mWidth, sign: true);
    fa.put(fv1);
    fb.put(fv2);

    final expectedNoRound = FloatingPointValue.ofDoubleUnrounded(
        fv1.toDouble() + fv2.toDouble(),
        exponentWidth: eWidth,
        mantissaWidth: mWidth);

    final FloatingPointValue expected;
    final expectedRound = fv1 + fv2;
    if (((fv1.exponent.toInt() - fv2.exponent.toInt()).abs() < 2) &
        (fv1.sign.toInt() != fv2.sign.toInt())) {
      expected = expectedNoRound;
    } else {
      expected = expectedRound;
    }
    final adder = FloatingPointAdderRound(
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
