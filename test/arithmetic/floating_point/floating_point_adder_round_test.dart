// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_rnd_test.dart
// Tests of FloatingPointAdderRnd -- a rounding FP Adder.
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
  test('FP: singleton N path', () async {
    final clk = SimpleClockGenerator(10).clk;

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

    final expectedNoRound = FloatingPointValue.ofDoubleUnrounded(
        fva.toDouble() + fvb.toDouble(),
        exponentWidth: eWidth,
        mantissaWidth: mWidth);
    final expected = expectedNoRound;

    final adder = FloatingPointAdderRound(fa, fb, clk: clk);
    await adder.build();
    unawaited(Simulator.run());
    await clk.nextNegedge;
    fa.put(0);
    fb.put(0);

    final computed = adder.sum.floatingPointValue;
    expect(computed.isNaN(), equals(expected.isNaN()));
    expect(computed, equals(expected));
    await Simulator.endSimulation();
  });

  test('FP: N path, subtraction, delta < 2', () async {
    final clk = SimpleClockGenerator(10).clk;

    const eWidth = 4;
    const mWidth = 5;

    final one = FloatingPointValue.getFloatingPointConstant(
        FloatingPointConstants.one, eWidth, mWidth);
    final fa = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    final fb = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    fa.put(one);
    fb.put(one);
    final adder = FloatingPointAdderRound(clk: clk, fa, fb);
    await adder.build();
    unawaited(Simulator.run());

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
              final expected = FloatingPointValue.ofDoubleUnrounded(
                  fva.toDouble() + fvb.toDouble(),
                  exponentWidth: eWidth,
                  mantissaWidth: mWidth);
              await clk.nextNegedge;
              fa.put(0);
              fb.put(0);

              final computed = adder.sum.floatingPointValue;
              expect(computed.isNaN(), equals(expected.isNaN()));
              expect(computed, equals(expected));
            }
          }
        }
      }
    }
    await Simulator.endSimulation();
  });

  test('FP: singleton R path', () async {
    final clk = SimpleClockGenerator(10).clk;

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
    final adder = FloatingPointAdderRound(clk: clk, fa, fb);
    await adder.build();
    unawaited(Simulator.run());
    await clk.nextNegedge;
    fa.put(0);
    fb.put(0);

    final computed = adder.sum.floatingPointValue;
    expect(computed.isNaN(), equals(expected.isNaN()));
    expect(computed, equals(expected));
    await Simulator.endSimulation();
  });

  test('FP: R path, strict subnormal', () async {
    final clk = SimpleClockGenerator(10).clk;

    const eWidth = 4;
    const mWidth = 5;

    final fa = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    final fb = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    fa.put(0);
    fb.put(0);
    final adder = FloatingPointAdderRound(clk: clk, fa, fb);
    await adder.build();
    unawaited(Simulator.run());

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
                await clk.nextNegedge;
                fa.put(0);
                fb.put(0);

                final computed = adder.sum.floatingPointValue;
                expect(computed.isNaN(), equals(expected.isNaN()));
                expect(computed, equals(expected));
              }
            }
          }
        }
      }
    }
    await Simulator.endSimulation();
  });

  test('FP: R path, full random', () async {
    final clk = SimpleClockGenerator(10).clk;

    const eWidth = 3;
    const mWidth = 5;

    final fa = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    final fb = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    fa.put(0);
    fb.put(0);
    final adder = FloatingPointAdderRound(clk: clk, fa, fb);
    await adder.build();
    unawaited(Simulator.run());
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
        await clk.nextNegedge;
        fa.put(0);
        fb.put(0);
        final computed = adder.sum.floatingPointValue;
        expect(computed.isNaN(), equals(expected.isNaN()));
        expect(computed, equals(expected));
      }
    }
    await Simulator.endSimulation();
  });

  test('FP: singleton merged path', () async {
    final clk = SimpleClockGenerator(10).clk;

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

    final expectedNoRound = FloatingPointValue.ofDoubleUnrounded(
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
    final adder = FloatingPointAdderRound(clk: clk, fa, fb);
    await adder.build();
    unawaited(Simulator.run());
    await clk.nextNegedge;
    fa.put(0);
    fb.put(0);

    final computed = adder.sum.floatingPointValue;
    expect(computed.isNaN(), equals(expected.isNaN()));
    expect(computed, equals(expected));
    await Simulator.endSimulation();
  });

  test('FP: full random wide', () async {
    final clk = SimpleClockGenerator(10).clk;

    const eWidth = 11;
    const mWidth = 52;

    final fa = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    final fb = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    fa.put(0);
    fb.put(0);
    final adder = FloatingPointAdderRound(clk: clk, fa, fb);
    await adder.build();
    unawaited(Simulator.run());
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
      await clk.nextNegedge;
      fa.put(0);
      fb.put(0);
      final computed = adder.sum.floatingPointValue;
      expect(computed.isNaN(), equals(expected.isNaN()));
      expect(computed, equals(expected));
      cnt--;
    }
    await Simulator.endSimulation();
  });
}
