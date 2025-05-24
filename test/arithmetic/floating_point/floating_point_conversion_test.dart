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
    final fv1 = FloatingPointValue.ofBinaryStrings('0', '010', '1111');
    final exponentWidth = fv1.exponent.width;
    final mantissaWidth = fv1.mantissa.width;
    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

    const destExponentWidth = 2;
    const destMantissaWidth = 4;

    final fp2 = FloatingPoint(
        exponentWidth: destExponentWidth, mantissaWidth: destMantissaWidth);
    fp1.put(fv1);
    final convert = FloatingPointConverter(fp1, fp2);
    await convert.build();

    final expected = FloatingPointValue.populator(
            exponentWidth: destExponentWidth, mantissaWidth: destMantissaWidth)
        .ofDoubleUnrounded(
      fv1.toDouble(),
    );
    final expectedRound = FloatingPointValue.populator(
            exponentWidth: destExponentWidth, mantissaWidth: destMantissaWidth)
        .ofDouble(fv1.toDouble());

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
    final fv1 = FloatingPointValue.ofBinaryStrings('0', '010', '1111');
    final exponentWidth = fv1.exponent.width;
    final mantissaWidth = fv1.mantissa.width;
    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

    const destExponentWidth = 4;
    const destMantissaWidth = 4;

    fp1.put(fv1);
    final fp2 = FloatingPoint(
        exponentWidth: destExponentWidth, mantissaWidth: destMantissaWidth);
    final convert = FloatingPointConverter(fp1, fp2);

    final expected = FloatingPointValue.populator(
            exponentWidth: destExponentWidth, mantissaWidth: destMantissaWidth)
        .ofDouble(fv1.toDouble());

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
              final fv1 = FloatingPointValue.populator(
                      exponentWidth: exponentWidth,
                      mantissaWidth: mantissaWidth)
                  .ofInts(e1, m1, sign: negate);
              fp1.put(fv1.value);

              final expected = FloatingPointValue.populator(
                      exponentWidth: destExponentWidth,
                      mantissaWidth: destMantissaWidth)
                  .ofDouble(fv1.toDouble());

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
              final fv1 = FloatingPointValue.populator(
                      exponentWidth: exponentWidth,
                      mantissaWidth: mantissaWidth)
                  .ofInts(e1, m1, sign: negate);
              fp1.put(fv1.value);

              final expected = FloatingPointValue.populator(
                      exponentWidth: destExponentWidth,
                      mantissaWidth: destMantissaWidth)
                  .ofDouble(fv1.toDouble());

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
              final fv1 = FloatingPointValue.populator(
                      exponentWidth: sEW, mantissaWidth: sMW)
                  .random(rv);
              fp1.put(fv1.value);

              final expected = FloatingPointValue.populator(
                      exponentWidth: dEW, mantissaWidth: dMW)
                  .ofDouble(fv1.toDouble());

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
                  final fv1 = FloatingPointValue.populator(
                          exponentWidth: sEW, mantissaWidth: sMW)
                      .ofInts(e1, m1, sign: negate);
                  fp1.put(fv1.value);

                  final expected = FloatingPointValue.populator(
                          exponentWidth: dEW, mantissaWidth: dMW)
                      .ofDouble(fv1.toDouble());

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

      FloatingPointExplicitJBitValue ofExplicitString(String s) =>
          FloatingPointExplicitJBitValue.ofSpacedBinaryString(s);

      final fpj = FloatingPointExplicitJBit(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

      final fvj = ofExplicitString('0 1011 0001'); //trueS = 3 ok
      if (fvj.isLegalValue()) {
        final fp = FloatingPoint(
            exponentWidth: exponentWidth + delta, mantissaWidth: mantissaWidth);

        fpj.put(fvj);

        final expected = FloatingPointValue.populator(
                exponentWidth: exponentWidth + delta,
                mantissaWidth: mantissaWidth)
            .ofDouble(fvj.toDouble());

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
      var cnt = 0;

      final fpj = FloatingPointExplicitJBit(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      for (final delta in [-2, 2]) {
        final fp = FloatingPoint(
            exponentWidth: exponentWidth + delta, mantissaWidth: mantissaWidth);
        fpj.put(0);
        final converter = FloatingPointConverter(fpj, fp);

        for (final signVal in [false, true]) {
          for (var e = 0; e < pow(2.0, exponentWidth).toInt(); e++) {
            for (var m = 0; m < pow(2.0, mantissaWidth).toInt(); m++) {
              final fpev = FloatingPointExplicitJBitValue.populator(
                      exponentWidth: exponentWidth,
                      mantissaWidth: mantissaWidth)
                  .ofInts(e, m, sign: signVal);
              if (fpev.isLegalValue()) {
                fpj.put(fpev);
                cnt++;
                final computed = converter.destination.floatingPointValue;
                final dbl = fpev.toDouble();
                final expected = FloatingPointValue.populator(
                        exponentWidth: exponentWidth + delta,
                        mantissaWidth: mantissaWidth)
                    .ofDouble(dbl,
                        roundingMode: delta < 0
                            ? FloatingPointRoundingMode.roundNearestEven
                            : FloatingPointRoundingMode.truncate);
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
      stdout.write('cnt=$cnt');
    });

    test('FP: narrowing conversion implicit to explicit jbit', () {
      const exponentWidth = 4;
      const mantissaWidth = 6;
      const delta = -2;

      FloatingPointValue ofString(String s) =>
          FloatingPointValue.ofSpacedBinaryString(s);

      final fpj = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

      final fvj = ofString('0 0111 111111');
      final fp = FloatingPointExplicitJBit(
          exponentWidth: exponentWidth + delta, mantissaWidth: mantissaWidth);

      fpj.put(fvj);
      final expected = FloatingPointExplicitJBitValue.populator(
              exponentWidth: exponentWidth + delta,
              mantissaWidth: mantissaWidth)
          .ofDouble(fvj.toDouble());

      FloatingPointConverter(fpj, fp);
      final computed = fp.floatingPointExplicitJBitValue;
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
      var cnt = 0;

      final fp = FloatingPoint(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      for (final delta in [-2, 2]) {
        final fpj = FloatingPointExplicitJBit(
            exponentWidth: exponentWidth + delta, mantissaWidth: mantissaWidth);
        fp.put(0);
        final converter = FloatingPointConverter(fp, fpj);

        for (final signVal in [false, true]) {
          for (var e = 0; e < pow(2.0, exponentWidth).toInt(); e++) {
            for (var m = 0; m < pow(2.0, mantissaWidth).toInt(); m++) {
              final fpev = FloatingPointValue.populator(
                      exponentWidth: exponentWidth,
                      mantissaWidth: mantissaWidth)
                  .ofInts(e, m, sign: signVal);
              final nfpev = fpev;
              fp.put(nfpev);
              cnt++;
              final computed =
                  converter.destination.floatingPointExplicitJBitValue;
              final dbl = fpev.toDouble();
              final fpv = FloatingPointExplicitJBitValue.populator(
                      exponentWidth: exponentWidth + delta,
                      mantissaWidth: mantissaWidth)
                  .ofDouble(dbl,
                      roundingMode: delta < 0
                          ? FloatingPointRoundingMode.roundNearestEven
                          : FloatingPointRoundingMode.truncate);
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
      stdout.write('cnt=$cnt');
    });

    test('FP: singleton conversion explicit to explicit jbit', () {
      const exponentWidth = 4;
      const mantissaWidth = 4;
      const delta = -2;

      FloatingPointExplicitJBitValue ofExplicitString(String s) =>
          FloatingPointExplicitJBitValue.ofSpacedBinaryString(s);

      final fpj = FloatingPointExplicitJBit(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

      final fvj = ofExplicitString('0 0000 0001');
      if (fvj.isLegalValue()) {
        final fp = FloatingPointExplicitJBit(
            exponentWidth: exponentWidth + delta, mantissaWidth: mantissaWidth);

        fpj.put(fvj);
        final dbl = fvj.toDouble();
        final expectedPartial = FloatingPointExplicitJBitValue.populator(
            exponentWidth: exponentWidth + delta, mantissaWidth: mantissaWidth);
        final expected = expectedPartial.ofDouble(dbl);

        FloatingPointConverter(fpj, fp);
        final computed = fp.floatingPointExplicitJBitValue;
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
      const mantissaWidth = 4;
      var cnt = 0;

      final fp = FloatingPointExplicitJBit(
          exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
      // ignore: cascade_invocations
      fp.put(0);

      for (final delta in [-2, 2]) {
        final fpj = FloatingPointExplicitJBit(
            exponentWidth: exponentWidth + delta, mantissaWidth: mantissaWidth);
        final converter = FloatingPointConverter(fp, fpj);
        for (final signVal in [false, true]) {
          for (var e = 0; e < pow(2.0, exponentWidth).toInt(); e++) {
            for (var m = 0; m < pow(2.0, mantissaWidth).toInt(); m++) {
              final fpev = FloatingPointExplicitJBitValue.populator(
                      exponentWidth: exponentWidth,
                      mantissaWidth: mantissaWidth)
                  .ofInts(e, m, sign: signVal);
              if (fpev.isLegalValue()) {
                cnt++;
                fp.put(fpev);
                final computed =
                    converter.destination.floatingPointExplicitJBitValue;
                final dbl = fpev.toDouble();
                final fpv = FloatingPointExplicitJBitValue.populator(
                        exponentWidth: exponentWidth + delta,
                        mantissaWidth: mantissaWidth)
                    .ofDouble(dbl,
                        roundingMode: delta < 0
                            ? FloatingPointRoundingMode.roundNearestEven
                            : FloatingPointRoundingMode.truncate);
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
      stdout.write('cnt=$cnt');
    });
  });
}
