// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_conversion_test.dart
// Tests for floating point conversion (FP to FP)
//
// 2025 January 30
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:io';
import 'dart:math';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  test('FP: singleton conversion wide to narrow exponent', () async {
    const exponentWidth = 3;
    const mantissaWidth = 4;

    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fv1 = fp1.valuePopulator().ofBinaryStrings('0', '010', '1111');

    const destExponentWidth = 2;
    const destMantissaWidth = 4;

    final fp2 = FloatingPoint(
        exponentWidth: destExponentWidth, mantissaWidth: destMantissaWidth);
    fp1.put(fv1);
    final convert = FloatingPointConverter(fp1, fp2);
    await convert.build();

    final expected = fp2.valuePopulator().ofDoubleUnrounded(
          fv1.toDouble(),
        );
    final expectedRound = fp2.valuePopulator().ofDouble(fv1.toDouble());

    final computed = convert.destination.floatingPointValue;
    expect(computed, equals(fp2.floatingPointValue));

    expect(computed, equals(expectedRound), reason: '''
      $fv1 (${fv1.toDouble()})\t=
      $computed (${computed.toDouble()})\tcomputed
      $expectedRound (${expectedRound.toDouble()})\texpected
      $expected (${expected.toDouble()})\texpected unrounded

''');
  });

  test('FP: singleton conversion narrow to wide exponent', () {
    const exponentWidth = 3;
    const mantissaWidth = 4;

    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fv1 = fp1.valuePopulator().ofBinaryStrings('0', '010', '1111');

    const destExponentWidth = 4;
    const destMantissaWidth = 4;

    fp1.put(fv1);
    final fp2 = FloatingPoint(
        exponentWidth: destExponentWidth, mantissaWidth: destMantissaWidth);
    final convert = FloatingPointConverter(fp1, fp2);

    final expected = fp2.valuePopulator().ofDouble(fv1.toDouble());

    final computed = convert.destination.floatingPointValue;
    expect(computed, equals(fp2.floatingPointValue));

    expect(computed, equals(expected), reason: '''
                              $fv1 (${fv1.toDouble()})\t=
                              $computed (${computed.toDouble()})\tcomputed
                              $expected (${expected.toDouble()})\texpected
''');
  });

  test('FP: conversion wide to narrow exponent exhaustive', () {
    const exponentWidth = 4;
    const mantissaWidth = 6;
    const normal = 0; // set to zero for subnormal testing

    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
      ..put(0);
    for (var destExponentWidth = exponentWidth - 1;
        destExponentWidth > 2;
        destExponentWidth--) {
      for (var destMantissaWidth = mantissaWidth + 3;
          destMantissaWidth > 3;
          destMantissaWidth--) {
        final fp2 = FloatingPoint(
            exponentWidth: destExponentWidth, mantissaWidth: destMantissaWidth);
        final convert = FloatingPointConverter(fp1, fp2);
        final expLimit = pow(2, exponentWidth) - 1;
        final mantLimit = pow(2, mantissaWidth);
        for (final negate in [false, true]) {
          for (var e1 = normal; e1 < expLimit; e1++) {
            for (var m1 = 0; m1 < mantLimit; m1++) {
              final fv1 = fp1.valuePopulator().ofInts(e1, m1, sign: negate);
              fp1.put(fv1.value);

              final expected = fp2.valuePopulator().ofDouble(fv1.toDouble());

              final computed = convert.destination.floatingPointValue;
              expect(computed, equals(fp2.floatingPointValue));

              expect(computed, equals(expected), reason: '''
                              $fv1 (${fv1.toDouble()})\t=>
                              $computed (${computed.toDouble()})\tcomputed
                              $expected (${expected.toDouble()})\texpected
                              $destExponentWidth destExponentWidth
                              $destMantissaWidth destMantissaWidth
''');
            }
          }
        }
      }
    }
  });

  test('FP: conversion narrow to wide exhaustive', () {
    const exponentWidth = 4;
    const mantissaWidth = 5;
    const normal = 0; // set to zero for subnormal testing

    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    // ignore: cascade_invocations
    fp1.put(0);
    for (var destExponentWidth = exponentWidth;
        destExponentWidth < exponentWidth + 2;
        destExponentWidth++) {
      for (var destMantissaWidth = mantissaWidth - 2;
          destMantissaWidth < mantissaWidth + 3;
          destMantissaWidth++) {
        final fp2 = FloatingPoint(
            exponentWidth: destExponentWidth, mantissaWidth: destMantissaWidth);
        final convert = FloatingPointConverter(fp1, fp2);
        final expLimit = pow(2, exponentWidth) - 1;
        final mantLimit = pow(2, mantissaWidth);
        for (final negate in [false, true]) {
          for (var e1 = normal; e1 < expLimit; e1++) {
            for (var m1 = 0; m1 < mantLimit; m1++) {
              final fv1 = fp1.valuePopulator().ofInts(e1, m1, sign: negate);
              fp1.put(fv1.value);

              final expected = fp2.valuePopulator().ofDouble(fv1.toDouble());

              final computed = convert.destination.floatingPointValue;
              expect(computed, equals(fp2.floatingPointValue));

              expect(computed, equals(expected), reason: '''
                              $fv1 (${fv1.toDouble()})\t=>
                              $computed (${computed.toDouble()})\tcomputed
                              $expected (${expected.toDouble()})\texpected
''');
            }
          }
        }
      }
    }
  });

  test('FP: conversion random', () {
    for (var sEW = 2; sEW < 5; sEW++) {
      for (var sMW = 2; sMW < 5; sMW++) {
        final rv = Random(13);
        final fp1 = FloatingPoint(exponentWidth: sEW, mantissaWidth: sMW)
          ..put(0);
        for (var dEW = 2; dEW < 6; dEW++) {
          for (var dMW = 2; dMW < 6; dMW++) {
            final fp2 = FloatingPoint(exponentWidth: dEW, mantissaWidth: dMW);
            final convert = FloatingPointConverter(fp1, fp2);
            for (var iter = 0; iter < 20; iter++) {
              final fv1 = fp1.valuePopulator().random(rv);
              fp1.put(fv1.value);

              final expected = fp2.valuePopulator().ofDouble(fv1.toDouble());

              final computed = convert.destination.floatingPointValue;

              expect(computed, equals(fp2.floatingPointValue));

              expect(computed, equals(expected), reason: '''
                              $fv1 (${fv1.toDouble()})\t=>
                              $computed (${computed.toDouble()})\tcomputed
                              $expected (${expected.toDouble()})\texpected
''');
            }
          }
        }
      }
    }
  });

  test('FP: conversion exhaustive', () {
    for (var sEW = 2; sEW < 5; sEW++) {
      for (var sMW = 2; sMW < 5; sMW++) {
        final fp1 = FloatingPoint(exponentWidth: sEW, mantissaWidth: sMW)
          ..put(0);
        for (var dEW = 2; dEW < 6; dEW++) {
          for (var dMW = 2; dMW < 6; dMW++) {
            final fp2 = FloatingPoint(exponentWidth: dEW, mantissaWidth: dMW);
            final convert = FloatingPointConverter(fp1, fp2);
            for (final negate in [false, true]) {
              for (var e1 = 0; e1 < pow(2, sEW) - 1; e1++) {
                for (var m1 = 0; m1 < pow(2, sMW); m1++) {
                  final fv1 = fp1.valuePopulator().ofInts(e1, m1, sign: negate);
                  fp1.put(fv1.value);

                  final expected =
                      fp2.valuePopulator().ofDouble(fv1.toDouble());

                  final computed = convert.destination.floatingPointValue;

                  expect(computed, equals(fp2.floatingPointValue));

                  expect(computed, equals(expected), reason: '''
                              $fv1 (${fv1.toDouble()})\t=>
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
  });

  test('FP: conversion 32-BF16 random', () {
    final rv = Random(13);
    final fp1 = FloatingPoint32()..put(0);
    final fp2 = FloatingPointBF16();
    final convert = FloatingPointConverter(fp1, fp2);

    final maxV = FloatingPointBF16Value.populator()
        .ofConstant(FloatingPointConstants.largestNormal)
        .toDouble();
    final minV = FloatingPoint16Value.populator()
        .ofConstant(FloatingPointConstants.smallestPositiveSubnormal)
        .toDouble();
    var iter = 0;
    while (iter < 20) {
      final fv1 = FloatingPoint32Value.populator().random(rv);
      fp1.put(fv1.value);
      if (fv1.toDouble().abs() > maxV) {
        continue;
      }
      if (fv1.toDouble().abs() < minV) {
        continue;
      }
      iter++;
      final expected =
          FloatingPointBF16Value.populator().ofDouble(fv1.toDouble());

      final computed = convert.destination.floatingPointValue;

      expect(computed, equals(fp2.floatingPointValue));
      expect(computed, equals(expected), reason: '''
                              $fv1 (${fv1.toDouble()})\t=>
                              $computed (${computed.toDouble()})\tcomputed
                              $expected (${expected.toDouble()})\texpected
''');
    }
  });

  test('FP: conversion BF16-32 random', () {
    final rv = Random(13);
    final fp1 = FloatingPointBF16()..put(0);
    final fp2 = FloatingPoint32();
    final convert = FloatingPointConverter(fp1, fp2);

    var iter = 0;
    while (iter < 20) {
      final fv1 = FloatingPointBF16Value.populator().random(rv);
      fp1.put(fv1.value);
      iter++;
      final expected =
          FloatingPoint32Value.populator().ofDouble(fv1.toDouble());

      final computed = convert.destination.floatingPointValue;

      expect(computed, equals(fp2.floatingPointValue));
      expect(computed, equals(expected), reason: '''
                              $fv1 (${fv1.toDouble()})\t=>
                              $computed (${computed.toDouble()})\tcomputed
                              $expected (${expected.toDouble()})\texpected
''');
    }
  });

  // TODO(desmonddak): make this exhaustive
  test('FP: conversion subtypes', () {
    final fp32 = FloatingPoint32();
    final bf16 = FloatingPointBF16();

    final one =
        FloatingPoint32Value.populator().ofConstant(FloatingPointConstants.one);

    fp32.put(one);
    FloatingPointConverter(fp32, bf16);
    expect(bf16.floatingPointValue.toDouble(), equals(1.0));
  });

  group('FP: explicit-jbit conversions', () {
    test('FP: narrowing conversion explicit to implicit jbit', () {
      const exponentWidth = 4;
      const mantissaWidth = 4;
      const delta = -1;

      final fpj = FloatingPoint(
          exponentWidth: exponentWidth,
          mantissaWidth: mantissaWidth,
          explicitJBit: true);
      FloatingPointValue ofExplicitString(String s) =>
          fpj.valuePopulator().ofSpacedBinaryString(s);

      final fvj = ofExplicitString('0 1011 0001'); //trueS = 3 ok
      if (fvj.isLegalValue()) {
        final fp = FloatingPoint(
            exponentWidth: exponentWidth + delta, mantissaWidth: mantissaWidth);

        fpj.put(fvj);

        final expected = fp.valuePopulator().ofDouble(fvj.toDouble());

        FloatingPointConverter(fpj, fp);
        final computed = fp.floatingPointValue;
        expect(computed, equals(expected), reason: '''
input:      $fvj  ${fvj.toDouble()}
normalized: ${fvj.canonicalize()} ${fvj.canonicalize().toDouble()}
computed:   $computed ${computed.toDouble()}
expected:   $expected ${expected.toDouble()}
''');
      } else {
        stdout.write('illegal jbit value');
      }
    });

    test('FP: conversion explicit to implicit j-bit exhaustive round-trip', () {
      const exponentWidth = 6;
      const mantissaWidth = 4;

      final fpj = FloatingPoint(
          exponentWidth: exponentWidth,
          mantissaWidth: mantissaWidth,
          explicitJBit: true);
      for (final expDelta in [-2, 2]) {
        final fp = FloatingPoint(
            exponentWidth: exponentWidth + expDelta,
            mantissaWidth: mantissaWidth);
        fpj.put(0);
        final converter = FloatingPointConverter(fpj, fp);

        for (final signVal in [false, true]) {
          for (var e = 0; e < pow(2.0, exponentWidth).toInt(); e++) {
            for (var m = 0; m < pow(2.0, mantissaWidth).toInt(); m++) {
              final fpev = fpj.valuePopulator().ofInts(e, m, sign: signVal);
              if (fpev.isLegalValue()) {
                fpj.put(fpev);
                final computed = converter.destination.floatingPointValue;
                final dbl = fpev.toDouble();
                final expected = fp.valuePopulator().ofDouble(dbl,
                    roundingMode: expDelta < 0
                        ? FloatingPointRoundingMode.roundNearestEven
                        : FloatingPointRoundingMode.truncate);
                expect(computed.isNaN, equals(expected.isNaN));
                if (!computed.isNaN) {
                  expect(computed, equals(expected), reason: '''
input:      $fpev  ${fpev.toDouble()}
normalized: ${fpev.canonicalize()} ${fpev.canonicalize().toDouble()}
computed:   $computed ${computed.toDouble()}
expected:   $expected ${expected.toDouble()}
''');
                }
              }
            }
          }
        }
      }
    });

    test('FP: narrowing conversion implicit to explicit jbit', () {
      const exponentWidth = 4;
      const mantissaWidth = 6;
      const delta = -2;

      final fpj = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      FloatingPointValue ofString(String s) =>
          fpj.valuePopulator().ofSpacedBinaryString(s);

      final fvj = ofString('0 0111 111111');
      final fp = FloatingPoint(
          exponentWidth: exponentWidth + delta,
          mantissaWidth: mantissaWidth,
          explicitJBit: true);

      fpj.put(fvj);
      final expected = fp.valuePopulator().ofDouble(fvj.toDouble());

      FloatingPointConverter(fpj, fp);
      final computed = fp.floatingPointValue;
      expect(computed.canonicalize(), equals(expected), reason: '''
input:      $fvj
computed:   $computed
normalized: ${computed.canonicalize()}
expected:   $expected
''');
    });

    test('FP: conversion implicit to explicit j-bit exhaustive round-trip', () {
      const exponentWidth = 4;
      const mantissaWidth = 6;

      final fp = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      for (final expDelta in [-2, 2]) {
        final fpj = FloatingPoint(
            exponentWidth: exponentWidth + expDelta,
            mantissaWidth: mantissaWidth,
            explicitJBit: true);
        fp.put(0);
        final converter = FloatingPointConverter(fp, fpj);

        for (final signVal in [false, true]) {
          for (var e = 0; e < pow(2.0, exponentWidth).toInt(); e++) {
            for (var m = 0; m < pow(2.0, mantissaWidth).toInt(); m++) {
              final fpev = fp.valuePopulator().ofInts(e, m, sign: signVal);
              final nfpev = fpev;
              fp.put(nfpev);
              final computed = converter.destination.floatingPointValue;
              final dbl = fpev.toDouble();
              final fpv = fpj.valuePopulator().ofDouble(dbl,
                  roundingMode: expDelta < 0
                      ? FloatingPointRoundingMode.roundNearestEven
                      : FloatingPointRoundingMode.truncate);
              expect(computed.isNaN, equals(fpv.isNaN));
              if (!computed.isNaN) {
                expect(computed.canonicalize(), equals(fpv), reason: '''
input:      $fpev
computed:   $computed
normalized: ${computed.canonicalize()}
expected:   $fpv
''');
              }
            }
          }
        }
      }
    });

    test('FP: singleton conversion explicit to explicit jbit', () {
      const exponentWidth = 4;
      const mantissaWidth = 4;
      const delta = -2;

      final fpj = FloatingPoint(
          exponentWidth: exponentWidth,
          mantissaWidth: mantissaWidth,
          explicitJBit: true);
      FloatingPointValue ofExplicitString(String s) =>
          fpj.valuePopulator().ofSpacedBinaryString(s);

      final fvj = ofExplicitString('0 0000 0001');
      if (fvj.isLegalValue()) {
        final fp = FloatingPoint(
            exponentWidth: exponentWidth + delta,
            mantissaWidth: mantissaWidth,
            explicitJBit: true);

        fpj.put(fvj);
        final dbl = fvj.toDouble();
        final expectedPartial = fp.valuePopulator();
        final expected = expectedPartial.ofDouble(dbl);

        FloatingPointConverter(fpj, fp);
        final computed = fp.floatingPointValue;
        expect(computed.canonicalize(), equals(expected), reason: '''
input:    $fvj
computed: $computed
expected: $expected
''');
      } else {
        stdout.write('illegal jbit value');
      }
    });

    test('FP: conversion explicit to explicit j-bit exhaustive round-trip', () {
      const exponentWidth = 6;
      const mantissaWidth = 6;

      final fp = FloatingPoint(
          exponentWidth: exponentWidth,
          mantissaWidth: mantissaWidth,
          explicitJBit: true);
      // ignore: cascade_invocations
      fp.put(0);

      for (final expDelta in [-2, 2]) {
        // TODO(desmonddak): fix narrowing bug and improve this test
        for (final mantDelta in [0]) {
          final fpj = FloatingPoint(
              exponentWidth: exponentWidth + expDelta,
              mantissaWidth: mantissaWidth + mantDelta,
              explicitJBit: true);
          final converter = FloatingPointConverter(fp, fpj);
          for (final signVal in [false, true]) {
            for (var e = 0; e < pow(2.0, exponentWidth).toInt(); e++) {
              for (var m = 0; m < pow(2.0, mantissaWidth).toInt(); m++) {
                final fpev = fp.valuePopulator().ofInts(e, m, sign: signVal);
                if (fpev.isLegalValue()) {
                  fp.put(fpev);
                  final computed = converter.destination.floatingPointValue;
                  final dbl = fpev.toDouble();
                  final fpv = fpj.valuePopulator().ofDouble(dbl,
                      roundingMode: expDelta < 0
                          ? FloatingPointRoundingMode.roundNearestEven
                          : FloatingPointRoundingMode.truncate);
                  expect(computed.isNaN, equals(fpv.isNaN));
                  if (!computed.isNaN) {
                    expect(computed.canonicalize(), equals(fpv), reason: '''
input:    $fpev
normalized: ${fpev.canonicalize()}
computed: $computed
expected: $fpv
''');
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
