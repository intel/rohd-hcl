// Copyright (C) 2024-2026 Intel Corporation
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

/// Computes the exact truncated product of [fv1] and [fv2] in [fpOut]'s format.
FloatingPointValue _expectedProduct(
        FloatingPoint fpOut, FloatingPointValue fv1, FloatingPointValue fv2) =>
    fpOut
        .valuePopulator()
        .multiply(fv1, fv2, roundingMode: FloatingPointRoundingMode.truncate);

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
          final fv1 = fp1.valuePopulator().ofInts(e1, 0);
          final fv2 = fp2.valuePopulator().ofInts(e2, 0);
          final expected = _expectedProduct(fp1, fv1, fv2);

          fp1.put(fv1.value);
          fp2.put(fv2.value);
          final computed = multiply.product.floatingPointValue;

          expect(computed.isNaN, equals(expected.isNaN));
          if (!computed.isNaN) {
            expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t*
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
          }
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
          fp1.valuePopulator().ofSpacedBinaryString(s);
      final testCases = [
        (ofString('0 0001 0000'), ofString('0 0000 0000')),
        (ofString('0 0111 0010'), ofString('0 1110 1111')),
        (ofString('0 1010 0000'), ofString('0 1011 0100')),
        (
          fv.clonePopulator().positiveInfinity,
          fv.clonePopulator().positiveInfinity
        ),
        (
          fv.clonePopulator().negativeInfinity,
          fv.clonePopulator().negativeInfinity
        ),
        (
          fv.clonePopulator().positiveInfinity,
          fv.clonePopulator().negativeInfinity
        ),
        (
          fv.clonePopulator().positiveInfinity,
          fv.clonePopulator().positiveZero
        ),
        (
          fv.clonePopulator().negativeInfinity,
          fv.clonePopulator().positiveZero
        ),
        (fv.clonePopulator().positiveInfinity, fv.clonePopulator().one),
        (fv.clonePopulator().positiveZero, fv.clonePopulator().one),
        (fv.clonePopulator().negativeInfinity, fv.clonePopulator().one),
      ];

      for (final test in testCases) {
        final fv1 = test.$1;
        final fv2 = test.$2;

        final expected = _expectedProduct(fp1, fv1, fv2);

        fp1.put(fv1.value);
        fp2.put(fv2.value);
        final multiply = FloatingPointMultiplierSimple(fp1, fp2);
        final computed = multiply.product.floatingPointValue;
        expect(computed.isNaN, equals(expected.isNaN));
        if (!computed.isNaN) {
          expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t*
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
        }
      }
    });

    test('FP: simple multiplier supports every rounding mode', () {
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
        final multiplier =
            FloatingPointMultiplierSimple(a, b, roundingMode: mode);

        for (var iteration = 0; iteration < 150; iteration++) {
          final aValue = populator().random(random);
          final bValue = populator().random(random);
          a.put(aValue);
          b.put(bValue);

          final actual = multiplier.product.floatingPointValue;
          final expected =
              populator().multiply(aValue, bValue, roundingMode: mode);
          expect(actual.isNaN, expected.isNaN,
              reason: 'mode=$mode a=$aValue b=$bValue');
          if (!expected.isNaN) {
            expect(actual, expected, reason: 'mode=$mode a=$aValue b=$bValue');
          }
        }
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
            final fv1 = fp1.valuePopulator().ofInts(e1, m1);
            for (var e2 = 0; e2 < expLimit; e2++) {
              for (var m2 = 0; m2 < mantLimit; m2++) {
                final fv2 =
                    fp2.valuePopulator().ofInts(e2, m2, sign: subtract == 1);

                final expected = _expectedProduct(fp1, fv1, fv2);

                fp1.put(fv1.value);
                fp2.put(fv2.value);
                final computed = multiply.product.floatingPointValue;
                expect(computed.isNaN, equals(expected.isNaN));
                if (!computed.isNaN) {
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

      final rand = Random(51);
      var cnt = 1000;
      while (cnt > 0) {
        final fv1 = fp1.valuePopulator().random(rand);
        final fv2 = fp2.valuePopulator().random(rand);
        fp1.put(fv1);
        fp2.put(fv2);

        final expected = _expectedProduct(fp1, fv1, fv2);
        final computed = multiplier.product.floatingPointValue;
        expect(computed.isNaN, equals(expected.isNaN));
        if (!computed.isNaN) {
          expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t*
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
        }
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
              CompressionTreeMultiplier(a, b, name: name));
      final rand = Random(51);

      var cnt = 1000;
      while (cnt > 0) {
        final fv1 = fp1.valuePopulator().random(rand);
        final fv2 = fp2.valuePopulator().random(rand);
        fp1.put(fv1);
        fp2.put(fv2);

        final expected = _expectedProduct(fp1, fv1, fv2);
        final computed = multiplier.product.floatingPointValue;
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

    test('FP: simple multiplier singleton', () async {
      const exponentWidth = 4;
      const mantissaWidth = 4;
      final fp1 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fv1 = fp1.valuePopulator().ofBinaryStrings('1', '1100', '0111');

      final fp2 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fv2 = fp2.valuePopulator().ofBinaryStrings('1', '1100', '0000');

      final expected = _expectedProduct(fp1, fv1, fv2);

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
      final fv1 = fp1.valuePopulator().ofBinaryStrings('1', '1000', '0011');

      final fp2 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fv2 = fp2.valuePopulator().ofBinaryStrings('1', '0001', '0001');

      final fpOut =
          FloatingPoint(exponentWidth: 5, mantissaWidth: mantissaWidth * 5);

      final expected = fpOut
          .valuePopulator()
          .multiply(fv1, fv2, roundingMode: FloatingPointRoundingMode.truncate);

      fp1.put(fv1.value);
      fp2.put(fv2.value);
      fpOut.put(0);

      final multiply =
          FloatingPointMultiplierSimple(fp1, fp2, outProduct: fpOut);
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
          fp1.valuePopulator().ofBinaryStrings('0', '00000110', '1010000');

      final fp2 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fv2 =
          fp2.valuePopulator().ofBinaryStrings('1', '01100010', '1110000');

      final fpOut = FloatingPoint(exponentWidth: 8, mantissaWidth: 14);

      final expected = fpOut
          .valuePopulator()
          .multiply(fv1, fv2, roundingMode: FloatingPointRoundingMode.truncate);

      fp1.put(fv1.value);
      fp2.put(fv2.value);
      fpOut.put(0);

      final multiply =
          FloatingPointMultiplierSimple(fp1, fp2, outProduct: fpOut);
      await multiply.build();
      final computed = multiply.product.floatingPointValue;

      expect(computed, equals(expected), reason: '''
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
      a.put(FloatingPointBF16Value.populator().ofDouble(1.2));
      b.put(FloatingPointBF16Value.populator().ofDouble(2.1));

      final dut = FloatingPointMultiplierSimple(a, b, outProduct: out);

      final result = dut.product;

      expect(
          result.floatingPointValue,
          out.valuePopulator().multiply(
              a.floatingPointValue, b.floatingPointValue,
              roundingMode: FloatingPointRoundingMode.truncate));
    });

    test('FP: simple multiplier wide random', () async {
      const exponentWidth = 5;
      const mantissaWidth = 5;

      final fp1 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fp2 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      fp1.put(0);
      fp2.put(0);

      const expOutWidth = 8;
      const mantOutWidth = 23;
      final fpofpOutt = FloatingPoint(
          exponentWidth: expOutWidth, mantissaWidth: mantOutWidth);
      // ignore: cascade_invocations
      fpofpOutt.put(0);
      final multiplier =
          FloatingPointMultiplierSimple(fp1, fp2, outProduct: fpofpOutt);

      final rand = Random(51);
      var cnt = 100;
      while (cnt > 0) {
        final fv1 = fp1.valuePopulator().random(rand);
        final fv2 = fp2.valuePopulator().random(rand);
        fp1.put(fv1);
        fp2.put(fv2);

        final expected = _expectedProduct(fpofpOutt, fv1, fv2);
        final computed = multiplier.product.floatingPointValue;
        expect(computed.isNaN, equals(expected.isNaN));
        if (!computed.isNaN) {
          expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t*
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
        }
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
          final fpOut = FloatingPoint(
              exponentWidth: expOutWidth, mantissaWidth: mantOutWidth);
          // ignore: cascade_invocations
          fpOut.put(0);
          final multiplier =
              FloatingPointMultiplierSimple(fp1, fp2, outProduct: fpOut);

          final rand = Random(51);
          var cnt = 100;
          while (cnt > 0) {
            final fv1 = fp1.valuePopulator().random(rand);
            final fv2 = fp2.valuePopulator().random(rand);
            fp1.put(fv1);
            fp2.put(fv2);

            final expected = _expectedProduct(fpOut, fv1, fv2);
            final computed = multiplier.product.floatingPointValue;
            expect(computed.isNaN, equals(expected.isNaN));
            if (!computed.isNaN) {
              expect(computed, equals(expected), reason: '''
      $fv1 (${fv1.toDouble()})\t*
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
            }
            cnt--;
          }
        }
      }
    });

    test('FP: simple multiplier narrows to smaller exponent and mantissa', () {
      // Regression test for issue #194: the product format may be narrower
      // than the inputs in both exponent and mantissa width.
      const exponentWidth = 5;
      const mantissaWidth = 6;

      final fp1 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fp2 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      fp1.put(0);
      fp2.put(0);

      for (final outSpec in [(3, 2), (3, 4), (4, 3)]) {
        for (final mode in FloatingPointRoundingMode.values) {
          final fpOut = FloatingPoint(
              exponentWidth: outSpec.$1, mantissaWidth: outSpec.$2);
          // ignore: cascade_invocations
          fpOut.put(0);
          final multiplier = FloatingPointMultiplierSimple(fp1, fp2,
              outProduct: fpOut, roundingMode: mode);

          final rand = Random(2024);
          for (var iteration = 0; iteration < 100; iteration++) {
            final fv1 = fp1.valuePopulator().random(rand);
            final fv2 = fp2.valuePopulator().random(rand);
            fp1.put(fv1);
            fp2.put(fv2);

            final expected =
                fpOut.valuePopulator().multiply(fv1, fv2, roundingMode: mode);
            final computed = multiplier.product.floatingPointValue;
            expect(computed.isNaN, equals(expected.isNaN),
                reason: 'outSpec=$outSpec mode=$mode fv1=$fv1 fv2=$fv2');
            if (!computed.isNaN) {
              expect(computed, equals(expected), reason: '''
outSpec=$outSpec mode=$mode
      $fv1 (${fv1.toDouble()})\t*
      $fv2 (${fv2.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expected (${expected.toDouble()})\texpected
''');
            }
          }
        }
      }
    });

    test(
        'FP: simple multiplier by exact zero produces exact zero '
        'with wider output exponent', () {
      // Regression test: multiplying by an exact zero operand must produce
      // an exact-zero result (mantissa and exponent both zero) even when
      // the product's exponent field is wider than the inputs'.
      const exponentWidth = 5;
      const mantissaWidth = 6;

      final fp1 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fp2 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fv1 = fp1.valuePopulator().ofBinaryStrings('1', '00000', '000000');
      final fv2 = fp2.valuePopulator().ofBinaryStrings('0', '01110', '110001');
      fp1.put(0);
      fp2.put(0);

      for (final outExpWidth in [3, 4, 5, 6, 7, 8]) {
        final fpOut =
            FloatingPoint(exponentWidth: outExpWidth, mantissaWidth: 6);
        // ignore: cascade_invocations
        fpOut.put(0);
        final multiplier =
            FloatingPointMultiplierSimple(fp1, fp2, outProduct: fpOut);
        fp1.put(fv1);
        fp2.put(fv2);

        final computed = multiplier.product.floatingPointValue;
        expect(computed.isAZero, isTrue,
            reason: 'outExpWidth=$outExpWidth computed=$computed');
        expect(computed.sign.toBool(), isTrue,
            reason: 'outExpWidth=$outExpWidth computed=$computed');
      }
    });

    test(
        'FP: simple multiplier subnormal rounding tracks all shifted-out '
        'sticky bits', () {
      const exponentWidth = 5;
      const mantissaWidth = 6;

      final fp1 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fp2 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final multiplier = FloatingPointMultiplierSimple(fp1, fp2,
          roundingMode: FloatingPointRoundingMode.roundNearestEven);
      final fv1 = fp1.valuePopulator().ofBinaryStrings('0', '00100', '100001');
      final fv2 = fp2.valuePopulator().ofBinaryStrings('0', '00100', '010101');
      fp1.put(fv1);
      fp2.put(fv2);

      final expected = fp1.valuePopulator().multiply(fv1, fv2,
          roundingMode: FloatingPointRoundingMode.roundNearestEven);
      expect(multiplier.product.floatingPointValue, equals(expected));
    });

    test('FP: simple multiplier singleton pipelined', () async {
      final clk = SimpleClockGenerator(10).clk;

      const exponentWidth = 4;
      const mantissaWidth = 4;
      final fp1 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fv1 = fp1.valuePopulator().ofBinaryStrings('0', '0111', '0000');

      final fp2 = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      final fv2 = fp2.valuePopulator().ofBinaryStrings('0', '1101', '0101');

      final expected = fp1
          .valuePopulator()
          .multiply(fv1, fv2, roundingMode: FloatingPointRoundingMode.truncate);

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
      final rand = Random(513);
      for (var i = 0; i < 50; i++) {
        final fv1 = FloatingPoint32Value.populator().random(rand);
        final fv2 = FloatingPoint32Value.populator().random(rand);
        fp1.put(fv1);
        fp2.put(fv2);
        final computed = dut.product.floatingPointValue;

        final expectedNoRound = _expectedProduct(fp1, fv1, fv2);
        expect(computed.isNaN, equals(expectedNoRound.isNaN));

        if (!computed.isNaN) {
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
    final fv1 = fp1.valuePopulator().ofBinaryStrings('0', '0111', '0000');

    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fv2 = fp2.valuePopulator().ofBinaryStrings('0', '1101', '0101');

    final expected = fp1
        .valuePopulator()
        .multiply(fv1, fv2, roundingMode: FloatingPointRoundingMode.truncate);

    fp1.put(fv1.value);
    fp2.put(fv2.value);

    final multiply = FloatingPointMultiplierSimple(fp1, fp2,
        clk: clk,
        multGen: (a, b, {clk, reset, enable, name = 'multiplier'}) =>
            CompressionTreeMultiplier(a, b,
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
