// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_multiplier_test.dart
// Tests for floating point multipliers.
//
// 2024 December 30
// Authors:
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
  group('FP: multiplication', () {
    test('FP: simple multiplier sweep exponents', () {
      const exponentWidth = 4;
      const mantissaWidth = 4;

      final fp1 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fp2 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      fp1.put(0);
      fp2.put(0);
      final multiply = FloatingPointMultiplierSimple(fp1, fp2);

      final expLimit = pow(2, exponentWidth) - 1;
      for (var e1 = 0; e1 < expLimit; e1++) {
        for (var e2 = 0; e2 < expLimit; e2++) {
          final fv1 = FloatingPointValue.ofInts(e1, 0,
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
          final fv2 = FloatingPointValue.ofInts(e2, 0,
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
          final expected = FloatingPointValue.ofDoubleUnrounded(
              fv1.toDouble() * fv2.toDouble(),
              exponentWidth: exponentWidth,
              mantissaWidth: mantissaWidth);

          fp1.put(fv1.value);
          fp2.put(fv2.value);
          final computed = multiply.product.floatingPointValue;

          expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t*
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
        }
      }
    });

    test('FP: simple multiplier interesting corners', () {
      const exponentWidth = 4;
      const mantissaWidth = 4;

      final fv = FloatingPointValue(
          sign: LogicValue.zero,
          exponent: LogicValue.filled(exponentWidth, LogicValue.one),
          mantissa: LogicValue.filled(exponentWidth, LogicValue.zero));

      final fp1 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fp2 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      fp1.put(fv);
      fp2.put(fv);
      FloatingPointValue ofString(String s) =>
          FloatingPointValue.ofSpacedBinaryString(s);
      final testCases = [
        (ofString('0 0001 0000'), ofString('0 0000 0000')),
        (ofString('0 0111 0010'), ofString('0 1110 1111')),
        (ofString('0 1010 0000'), ofString('0 1011 0100')),
        (fv.infinity, fv.infinity),
        (fv.negativeInfinity, fv.negativeInfinity),
        (fv.infinity, fv.negativeInfinity),
        (fv.infinity, fv.zero),
        (fv.negativeInfinity, fv.zero),
        (fv.infinity, fv.one),
        (fv.zero, fv.one),
        (fv.negativeInfinity, fv.one),
      ];

      for (final test in testCases) {
        final fv1 = test.$1;
        final fv2 = test.$2;

        final expected = FloatingPointValue.ofDoubleUnrounded(
            fv1.toDouble() * fv2.toDouble(),
            exponentWidth: exponentWidth,
            mantissaWidth: mantissaWidth);

        fp1.put(fv1.value);
        fp2.put(fv2.value);
        final multiply = FloatingPointMultiplierSimple(fp1, fp2);
        final computed = multiply.product.floatingPointValue;

        expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t*
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
      }
    });

    test('FP: simple multiplier exhaustive', () {
      const exponentWidth = 3;
      const mantissaWidth = 3;

      final fp1 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fp2 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      fp1.put(0);
      fp2.put(0);
      final multiply = FloatingPointMultiplierSimple(fp1, fp2);

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

                final expected = FloatingPointValue.ofDoubleUnrounded(
                    fv1.toDouble() * fv2.toDouble(),
                    exponentWidth: exponentWidth,
                    mantissaWidth: mantissaWidth);

                fp1.put(fv1.value);
                fp2.put(fv2.value);
                final computed = multiply.product.floatingPointValue;

                expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t*
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

    test('FP: simple multiplier full random', () async {
      const exponentWidth = 4;
      const mantissaWidth = 4;

      final fp1 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fp2 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      fp1.put(0);
      fp2.put(0);
      final multiplier = FloatingPointMultiplierSimple(fp1, fp2);

      final value = Random(51);
      var cnt = 1000;
      while (cnt > 0) {
        final fv1 = FloatingPointValue.random(value,
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
        final fv2 = FloatingPointValue.random(value,
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
        fp1.put(fv1);
        fp2.put(fv2);

        final expected = FloatingPointValue.ofDoubleUnrounded(
            fv1.toDouble() * fv2.toDouble(),
            exponentWidth: exponentWidth,
            mantissaWidth: mantissaWidth);
        final computed = multiplier.product.floatingPointValue;

        expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t*
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
        cnt--;
      }
    });

    test('FP: simple multiplier full random with compression tree mult',
        () async {
      const exponentWidth = 4;
      const mantissaWidth = 4;

      final fp1 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fp2 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      fp1.put(0);
      fp2.put(0);
      final multiplier = FloatingPointMultiplierSimple(fp1, fp2,
          multGen: (a, b, {clk, reset, enable, name = 'multiplier'}) =>
              CompressionTreeMultiplier(a, b, 4, name: name));
      final value = Random(51);

      var cnt = 1000;
      while (cnt > 0) {
        final fv1 = FloatingPointValue.random(value,
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
        final fv2 = FloatingPointValue.random(value,
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
        fp1.put(fv1);
        fp2.put(fv2);

        final expected = FloatingPointValue.ofDoubleUnrounded(
            fv1.toDouble() * fv2.toDouble(),
            exponentWidth: exponentWidth,
            mantissaWidth: mantissaWidth);
        final computed = multiplier.product.floatingPointValue;

        expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
        cnt--;
      }
    });

    test('FP: simple multiplier singleton', () async {
      const exponentWidth = 4;
      const mantissaWidth = 4;
      final fp1 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fv1 = FloatingPointValue.ofBinaryStrings('1', '1100', '0111');

      final fp2 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fv2 = FloatingPointValue.ofBinaryStrings('1', '1100', '0000');

      final doubleProduct = fv1.toDouble() * fv2.toDouble();
      final expected = FloatingPointValue.ofDoubleUnrounded(doubleProduct,
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

      fp1.put(fv1.value);
      fp2.put(fv2.value);

      final multiply = FloatingPointMultiplierSimple(fp1, fp2);
      await multiply.build();
      final computed = multiply.product.floatingPointValue;

      expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t*
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
    });
    test('FP: simple multiplier specify wider output', () async {
      const exponentWidth = 4;
      const mantissaWidth = 4;
      final fp1 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fv1 = FloatingPointValue.ofBinaryStrings('1', '1000', '0011');

      final fp2 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fv2 = FloatingPointValue.ofBinaryStrings('1', '0001', '0001');

      final doubleProduct = fv1.toDouble() * fv2.toDouble();

      final fpout =
          FloatingPoint(exponentWidth: 4, mantissaWidth: mantissaWidth * 5);

      final expected = FloatingPointValue.ofDoubleUnrounded(doubleProduct,
          exponentWidth: fpout.exponent.width,
          mantissaWidth: fpout.mantissa.width);

      fp1.put(fv1.value);
      fp2.put(fv2.value);
      fpout.put(0);

      final multiply =
          FloatingPointMultiplierSimple(fp1, fp2, outProduct: fpout);
      await multiply.build();
      final computed = multiply.product.floatingPointValue;

      expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t*
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
    });
    test('FP: simple multiplier bug wider output', () async {
      const exponentWidth = 8;
      const mantissaWidth = 7;
      final fp1 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fv1 =
          FloatingPointValue.ofBinaryStrings('0', '00000110', '1010000');

      final fp2 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fv2 =
          FloatingPointValue.ofBinaryStrings('1', '01100010', '1110000');

      final doubleProduct = fv1.toDouble() * fv2.toDouble();

      final fpout = FloatingPoint(exponentWidth: 8, mantissaWidth: 14);

      final expected = FloatingPointValue.ofDoubleUnrounded(doubleProduct,
          exponentWidth: fpout.exponent.width,
          mantissaWidth: fpout.mantissa.width);

      fp1.put(fv1.value);
      fp2.put(fv2.value);
      fpout.put(0);

      final multiply =
          FloatingPointMultiplierSimple(fp1, fp2, outProduct: fpout);
      await multiply.build();
      final computed = multiply.product.floatingPointValue;

      expect(computed.withinRounding(expected), true, reason: '''
      $fv1 (${fv1.toDouble()})\t*
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
    });

    test('FP: simple multiplier bf16 to fp32', () {
      final a = FloatingPointBF16();
      final b = FloatingPointBF16();

      final out = FloatingPoint32();
      a.put(FloatingPointBF16Value.ofDouble(1.2));
      b.put(FloatingPointBF16Value.ofDouble(2.1));

      final dut = FloatingPointMultiplierSimple(a, b, outProduct: out);

      final result = dut.product;

      expect(
          result.floatingPointValue,
          FloatingPoint32Value.ofDouble(a.floatingPointValue.toDouble() *
              b.floatingPointValue.toDouble()));
    });

    test('FP: simple multiplier wide random', () async {
      const exponentWidth = 8;
      const mantissaWidth = 7;

      final fp1 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fp2 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      fp1.put(0);
      fp2.put(0);

      const expOutWidth = 8;
      const mantOutWidth = 23;
      final fpout = FloatingPoint(
          exponentWidth: expOutWidth, mantissaWidth: mantOutWidth);
      // ignore: cascade_invocations
      fpout.put(0);
      final multiplier =
          FloatingPointMultiplierSimple(fp1, fp2, outProduct: fpout);

      final value = Random(51);
      var cnt = 100;
      while (cnt > 0) {
        final fv1 = FloatingPointValue.random(value,
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
        final fv2 = FloatingPointValue.random(value,
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
        fp1.put(fv1);
        fp2.put(fv2);

        final expected = FloatingPointValue.ofDoubleUnrounded(
            fv1.toDouble() * fv2.toDouble(),
            exponentWidth: fpout.exponent.width,
            mantissaWidth: fpout.mantissa.width);
        final computed = multiplier.product.floatingPointValue;
        // print('c=$computed e=$expected');
        expect(computed.withinRounding(expected), true, reason: '''
      $fv1 (${fv1.toDouble()})\t*
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
        cnt--;
      }
    });

    test('FP: simple multiplier sweep wide random', () async {
      const exponentWidth = 3;
      const mantissaWidth = 3;

      final fp1 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fp2 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      fp1.put(0);
      fp2.put(0);

      for (var expOutWidth = 3; expOutWidth < 5; expOutWidth++) {
        for (var mantOutWidth = 3; mantOutWidth < 16; mantOutWidth += 4) {
          final fpout = FloatingPoint(
              exponentWidth: expOutWidth, mantissaWidth: mantOutWidth);
          // ignore: cascade_invocations
          fpout.put(0);
          final multiplier =
              FloatingPointMultiplierSimple(fp1, fp2, outProduct: fpout);

          final value = Random(51);
          var cnt = 100;
          while (cnt > 0) {
            final fv1 = FloatingPointValue.random(value,
                exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
            final fv2 = FloatingPointValue.random(value,
                exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
            fp1.put(fv1);
            fp2.put(fv2);

            final expected = FloatingPointValue.ofDoubleUnrounded(
                fv1.toDouble() * fv2.toDouble(),
                exponentWidth: fpout.exponent.width,
                mantissaWidth: fpout.mantissa.width);
            final computed = multiplier.product.floatingPointValue;

            expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t*
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
            cnt--;
          }
        }
      }
    });

    test('FP: simple multiplier singleton pipelined', () async {
      final clk = SimpleClockGenerator(10).clk;

      const exponentWidth = 4;
      const mantissaWidth = 4;
      final fp1 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fv1 = FloatingPointValue.ofBinaryStrings('0', '0111', '0000');

      final fp2 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fv2 = FloatingPointValue.ofBinaryStrings('0', '1101', '0101');

      final expected = FloatingPointValue.ofDoubleUnrounded(
          fv1.toDouble() * fv2.toDouble(),
          exponentWidth: exponentWidth,
          mantissaWidth: mantissaWidth);

      fp1.put(fv1.value);
      fp2.put(fv2.value);

      final multiply = FloatingPointMultiplierSimple(fp1, fp2, clk: clk);

      unawaited(Simulator.run());
      await clk.nextNegedge;
      fp1.put(0);
      fp2.put(0);
      final computed = multiply.product.floatingPointValue;

      expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t*
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
      await Simulator.endSimulation();
    });
    test('FP: simple multiplier fp32: random', () {
      final fp1 = FloatingPoint32();
      final fp2 = FloatingPoint32();
      fp1.put(0);
      fp2.put(0);
      final dut = FloatingPointMultiplierSimple(fp1, fp2);
      final value = Random(513);
      for (var i = 0; i < 50; i++) {
        final fv1 = FloatingPoint32Value.random(value);
        final fv2 = FloatingPoint32Value.random(value);
        fp1.put(fv1);
        fp2.put(fv2);
        final computed = dut.product.floatingPointValue;

        final expectedDouble = fp1.floatingPointValue.toDouble() *
            fp2.floatingPointValue.toDouble();
        final expectedNoRound =
            FloatingPoint32Value.ofDoubleUnrounded(expectedDouble);

        // If the error is due to a rounding error, then ignore
        if (!computed.withinRounding(expectedNoRound)) {
          expect(computed, equals(expectedNoRound), reason: '''
      $fv1 (${fv1.toDouble()})\t*
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedNoRound (${expectedNoRound.toDouble()})\texpected
''');
        }
      }
    });
  });
  test('FP: simple multiplier singleton pipelined compression-tree', () async {
    final clk = SimpleClockGenerator(10).clk;

    const exponentWidth = 4;
    const mantissaWidth = 4;
    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fv1 = FloatingPointValue.ofBinaryStrings('0', '0111', '0000');

    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fv2 = FloatingPointValue.ofBinaryStrings('0', '1101', '0101');

    final expected = FloatingPointValue.ofDoubleUnrounded(
        fv1.toDouble() * fv2.toDouble(),
        exponentWidth: exponentWidth,
        mantissaWidth: mantissaWidth);

    fp1.put(fv1.value);
    fp2.put(fv2.value);

    final multiply = FloatingPointMultiplierSimple(fp1, fp2,
        clk: clk,
        multGen: (a, b, {clk, reset, enable, name = 'multiplier'}) =>
            CompressionTreeMultiplier(a, b, 4,
                clk: clk, reset: reset, enable: enable, name: name));

    unawaited(Simulator.run());
    await clk.nextNegedge;
    fp1.put(0);
    fp2.put(0);
    final computed = multiply.product.floatingPointValue;

    expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t+
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
    await Simulator.endSimulation();
  });
}
