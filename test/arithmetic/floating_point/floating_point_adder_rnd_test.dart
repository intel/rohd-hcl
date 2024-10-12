// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_rnd_test.dart
// Tests of Floating Point Addition with rounding
//
// 2024 August 30
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:math';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  test('FP: singleton N path', () {
    const eWidth = 4;
    const mWidth = 5;
    final fa = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    final fb = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);

    final fva = FloatingPointValue.ofInts(14, 31,
        exponentWidth: eWidth, mantissaWidth: mWidth);
    final fvb = FloatingPointValue.ofInts(13, 7,
        exponentWidth: eWidth, mantissaWidth: mWidth, sign: true);
    fa.put(fva);
    fb.put(fvb);

    final expectedNoRound = FloatingPointValue.fromDoubleIter(
        fva.toDouble() + fvb.toDouble(),
        exponentWidth: eWidth,
        mantissaWidth: mWidth);
    final expected = expectedNoRound;

    final adder = FloatingPointAdder(fa, fb);
    final computed = adder.sum.floatingPointValue;
    expect(computed.isNaN(), equals(expected.isNaN()));
    expect(computed, equals(expected));
  });

  test('FP: N path, subtraction, delta < 2', () {
    const eWidth = 4;
    const mWidth = 5;

    final one = FloatingPointValue.getFloatingPointConstant(
        FloatingPointConstants.one, eWidth, mWidth);
    final fa = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    final fb = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    fa.put(one);
    fb.put(one);
    final adder = FloatingPointAdder(fa, fb);

    final largestExponent = FloatingPointValue.computeBias(eWidth) +
        FloatingPointValue.computeMaxExponent(eWidth);
    final largestMantissa = pow(2, mWidth).toInt() - 1;
    for (var i = 0; i <= largestExponent; i++) {
      for (var j = 0; j <= largestExponent; j++) {
        if ((i - j).abs() < 2) {
          for (var ii = 0; ii <= largestMantissa; ii++) {
            for (var jj = 0; jj <= largestMantissa; jj++) {
              final fva = FloatingPointValue.ofInts(i, ii,
                  exponentWidth: eWidth, mantissaWidth: mWidth);
              final fvb = FloatingPointValue.ofInts(j, jj,
                  exponentWidth: eWidth, mantissaWidth: mWidth, sign: true);

              fa.put(fva);
              fb.put(fvb);
              // No rounding
              final expected = FloatingPointValue.fromDoubleIter(
                  fva.toDouble() + fvb.toDouble(),
                  exponentWidth: eWidth,
                  mantissaWidth: mWidth);

              final computed = adder.sum.floatingPointValue;
              expect(computed.isNaN(), equals(expected.isNaN()));
              expect(computed, equals(expected));
            }
          }
        }
      }
    }
  });

  test('FP: singleton R path', () {
    const eWidth = 4;
    const mWidth = 5;
    final fa = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    final fb = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    fa.put(0);
    fb.put(0);

    final fva = FloatingPointValue.ofInts(3, 11,
        exponentWidth: eWidth, mantissaWidth: mWidth);
    final fvb = FloatingPointValue.ofInts(11, 25,
        exponentWidth: eWidth, mantissaWidth: mWidth, sign: true);

    fa.put(fva);
    fb.put(fvb);

    final expected = fva + fvb;
    final adder = FloatingPointAdder(fa, fb);

    final computed = adder.sum.floatingPointValue;
    expect(computed.isNaN(), equals(expected.isNaN()));
    expect(computed, equals(expected));
  });

  test('FP: R path, strict subnormal', () {
    const eWidth = 4;
    const mWidth = 6;

    final fa = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    final fb = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    fa.put(0);
    fb.put(0);
    final adder = FloatingPointAdder(fa, fb);

    final largestMantissa = pow(2, mWidth).toInt() - 1;
    for (final sign in [false]) {
      for (var i = 0; i <= 1; i++) {
        for (var j = 0; j <= 1; j++) {
          if (!sign || (i - j).abs() >= 2) {
            for (var ii = 0; ii <= largestMantissa; ii++) {
              for (var jj = 0; jj <= largestMantissa; jj++) {
                final fva = FloatingPointValue.ofInts(i, ii,
                    exponentWidth: eWidth, mantissaWidth: mWidth);
                final fvb = FloatingPointValue.ofInts(j, jj,
                    exponentWidth: eWidth, mantissaWidth: mWidth, sign: sign);

                fa.put(fva);
                fb.put(fvb);
                final expected = fva + fvb;

                final computed = adder.sum.floatingPointValue;
                expect(computed.isNaN(), equals(expected.isNaN()));
                expect(computed, equals(expected));
              }
            }
          }
        }
      }
    }
  });

  test('FP: R path, full normal', () {
    const eWidth = 3;
    const mWidth = 5;

    final fa = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    final fb = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    fa.put(0);
    fb.put(0);
    final adder = FloatingPointAdder(fa, fb);

    final largestExponent = FloatingPointValue.computeBias(eWidth) +
        FloatingPointValue.computeMaxExponent(eWidth);
    final largestMantissa = pow(2, mWidth).toInt() - 1;
    for (final sign in [false, true]) {
      for (var i = 1; i <= largestExponent; i++) {
        for (var j = 1; j <= largestExponent; j++) {
          if ((i - j).abs() >= 2) {
            for (var ii = 0; ii <= largestMantissa; ii++) {
              for (var jj = 0; jj <= largestMantissa; jj++) {
                final fva = FloatingPointValue.ofInts(i, ii,
                    exponentWidth: eWidth, mantissaWidth: mWidth);
                final fvb = FloatingPointValue.ofInts(j, jj,
                    exponentWidth: eWidth, mantissaWidth: mWidth, sign: sign);

                fa.put(fva);
                fb.put(fvb);
                final expected = fva + fvb;
                final computed = adder.sum.floatingPointValue;
                expect(computed.isNaN(), equals(expected.isNaN()));
                expect(computed, equals(expected));
              }
            }
          }
        }
      }
    }
  });

  test('FP: R path, full all', () {
    const eWidth = 3;
    const mWidth = 5;

    final fa = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    final fb = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    fa.put(0);
    fb.put(0);
    final adder = FloatingPointAdder(fa, fb);

    final largestExponent = FloatingPointValue.computeBias(eWidth) +
        FloatingPointValue.computeMaxExponent(eWidth);
    final largestMantissa = pow(2, mWidth).toInt() - 1;
    for (final sign in [false, true]) {
      for (var i = 0; i <= largestExponent; i++) {
        for (var j = 0; j <= largestExponent; j++) {
          if (!sign || (i - j).abs() >= 2) {
            for (var ii = 0; ii <= largestMantissa; ii++) {
              for (var jj = 0; jj <= largestMantissa; jj++) {
                final fva = FloatingPointValue.ofInts(i, ii,
                    exponentWidth: eWidth, mantissaWidth: mWidth);
                final fvb = FloatingPointValue.ofInts(j, jj,
                    exponentWidth: eWidth, mantissaWidth: mWidth, sign: sign);
                fa.put(fva);
                fb.put(fvb);
                final expected = fva + fvb;
                final computed = adder.sum.floatingPointValue;
                expect(computed.isNaN(), equals(expected.isNaN()));
                expect(computed, equals(expected));
              }
            }
          }
        }
      }
    }
  });

  test('FP: R path, full random', () {
    const eWidth = 3;
    const mWidth = 5;

    final fa = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    final fb = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    fa.put(0);
    fb.put(0);
    final adder = FloatingPointAdder(fa, fb);
    final value = Random(47);

    var cnt = 200;
    while (cnt > 0) {
      final fva = FloatingPointValue.random(value,
          exponentWidth: eWidth, mantissaWidth: mWidth);
      final fvb = FloatingPointValue.random(value,
          exponentWidth: eWidth, mantissaWidth: mWidth);
      fa.put(fva);
      fb.put(fvb);
      if ((fva.exponent.toInt() - fvb.exponent.toInt()).abs() >= 2) {
        cnt--;
        final expected = fva + fvb;
        final computed = adder.sum.floatingPointValue;
        expect(computed.isNaN(), equals(expected.isNaN()));
        expect(computed, equals(expected));
      }
    }
  });

  test('FP: singleton merged path', () {
    const eWidth = 3;
    const mWidth = 5;
    final fa = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    final fb = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    fa.put(0);
    fb.put(0);
    final fva = FloatingPointValue.ofInts(14, 31,
        exponentWidth: eWidth, mantissaWidth: mWidth);
    final fvb = FloatingPointValue.ofInts(13, 7,
        exponentWidth: eWidth, mantissaWidth: mWidth, sign: true);
    fa.put(fva);
    fb.put(fvb);

    final expectedNoRound = FloatingPointValue.fromDoubleIter(
        fva.toDouble() + fvb.toDouble(),
        exponentWidth: eWidth,
        mantissaWidth: mWidth);

    final FloatingPointValue expected;
    final expectedRound = fva + fvb;
    if (((fva.exponent.toInt() - fvb.exponent.toInt()).abs() < 2) &
        (fva.sign.toInt() != fvb.sign.toInt())) {
      expected = expectedNoRound;
    } else {
      expected = expectedRound;
    }
    final adder = FloatingPointAdder(fa, fb);

    final computed = adder.sum.floatingPointValue;
    expect(computed.isNaN(), equals(expected.isNaN()));
    expect(computed, equals(expected));
  });

  test('FP: exhaustive', () {
    const eWidth = 3;
    const mWidth = 5;

    final fa = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    final fb = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    fa.put(0);
    fb.put(0);
    final adder = FloatingPointAdder(fa, fb);

    final largestExponent = FloatingPointValue.computeBias(eWidth) +
        FloatingPointValue.computeMaxExponent(eWidth);
    final largestMantissa = pow(2, mWidth).toInt() - 1;
    for (final sign in [false, true]) {
      for (var i = 0; i <= largestExponent; i++) {
        for (var j = 0; j <= largestExponent; j++) {
          for (var ii = 0; ii <= largestMantissa; ii++) {
            for (var jj = 0; jj <= largestMantissa; jj++) {
              final fva = FloatingPointValue.ofInts(i, ii,
                  exponentWidth: eWidth, mantissaWidth: mWidth);
              final fvb = FloatingPointValue.ofInts(j, jj,
                  exponentWidth: eWidth, mantissaWidth: mWidth, sign: sign);

              fa.put(fva);
              fb.put(fvb);
              final expectedNoRound = FloatingPointValue.fromDoubleIter(
                  fva.toDouble() + fvb.toDouble(),
                  exponentWidth: eWidth,
                  mantissaWidth: mWidth);

              final FloatingPointValue expected;
              final expectedRound = fva + fvb;
              if (((fva.exponent.toInt() - fvb.exponent.toInt()).abs() < 2) &
                  (fva.sign.toInt() != fvb.sign.toInt())) {
                expected = expectedNoRound;
              } else {
                expected = expectedRound;
              }
              final computed = adder.sum.floatingPointValue;
              expect(computed.isNaN(), equals(expected.isNaN()));
              expect(computed, equals(expected));
            }
          }
        }
      }
    }
  });
  test('FP: full random', () {
    const eWidth = 3;
    const mWidth = 5;

    final fa = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    final fb = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    fa.put(0);
    fb.put(0);
    final adder = FloatingPointAdder(fa, fb);
    final value = Random(47);

    var cnt = 500;
    while (cnt > 0) {
      final fva = FloatingPointValue.random(value,
          exponentWidth: eWidth, mantissaWidth: mWidth);
      final fvb = FloatingPointValue.random(value,
          exponentWidth: eWidth, mantissaWidth: mWidth);
      fa.put(fva);
      fb.put(fvb);
      final expectedNoRound = FloatingPointValue.fromDoubleIter(
          fva.toDouble() + fvb.toDouble(),
          exponentWidth: eWidth,
          mantissaWidth: mWidth);

      final FloatingPointValue expected;
      final expectedRound = fva + fvb;
      if (((fva.exponent.toInt() - fvb.exponent.toInt()).abs() < 2) &
          (fva.sign.toInt() != fvb.sign.toInt())) {
        expected = expectedNoRound;
      } else {
        expected = expectedRound;
      }
      cnt--;
      final computed = adder.sum.floatingPointValue;
      expect(computed.isNaN(), equals(expected.isNaN()));
      expect(computed, equals(expected));
    }
  });
  test('FP: full random wide', () {
    const eWidth = 11;
    const mWidth = 52;

    final fa = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    final fb = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    fa.put(0);
    fb.put(0);
    final adder = FloatingPointAdder(fa, fb);
    final value = Random(51);

    var cnt = 100;
    while (cnt > 0) {
      final fva = FloatingPointValue.random(value,
          exponentWidth: eWidth, mantissaWidth: mWidth);
      final fvb = FloatingPointValue.random(value,
          exponentWidth: eWidth, mantissaWidth: mWidth);
      fa.put(fva);
      fb.put(fvb);
      final expected = fva + fvb;
      final computed = adder.sum.floatingPointValue;
      expect(computed.isNaN(), equals(expected.isNaN()));
      expect(computed, equals(expected));
      cnt--;
    }
  });
}
