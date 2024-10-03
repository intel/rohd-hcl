// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_test.dart
// Tests of Floating Point stuff
//
// 2024 April 1
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com
//

import 'dart:math';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  test('FP: basic adder test', () {
    final fp1 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(3.25).value);
    final fp2 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(1.5).value);
    final out = FloatingPoint32Value.fromDouble(3.25 + 1.5);
    final adder = FloatingPointAdder(fp1, fp2);

    final fpSuper = adder.sum.floatingPointValue;
    final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
    final valStr = out.toDouble().toStringAsPrecision(7);
    expect(fpStr, valStr);
  });

  test('FP: small numbers adder test', () {
    final val = pow(2.0, -23).toDouble();
    final fp1 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(pow(2.0, -23).toDouble()).value);
    final fp2 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(pow(2.0, -23).toDouble()).value);
    final out = FloatingPoint32Value.fromDouble(val + val);

    final adder = FloatingPointAdder(fp1, fp2);

    final fpSuper = adder.sum.floatingPointValue;
    final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
    final valStr = out.toDouble().toStringAsPrecision(7);
    expect(fpStr, valStr);
  });

  test('FP: basic loop adder test', () {
    final input = [(3.25, 1.5), (4.5, 3.75)];

    for (final pair in input) {
      final fp1 = FloatingPoint32()
        ..put(FloatingPoint32Value.fromDouble(pair.$1).value);
      final fp2 = FloatingPoint32()
        ..put(FloatingPoint32Value.fromDouble(pair.$2).value);
      final out = FloatingPoint32Value.fromDouble(pair.$1 + pair.$2);

      final adder = FloatingPointAdder(fp1, fp2);

      final fpSuper = adder.sum.floatingPointValue;
      final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
      final valStr = out.toDouble().toStringAsPrecision(7);
      expect(fpStr, valStr);
    }
  });

  test('FP: basic adder test', () {
    final fp1 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(3.25).value);
    final fp2 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(1.5).value);
    final out = FloatingPoint32Value.fromDouble(3.25 + 1.5);

    final adder = FloatingPointAdder(fp1, fp2);

    final fpSuper = adder.sum.floatingPointValue;
    final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
    final valStr = out.toDouble().toStringAsPrecision(7);
    expect(fpStr, valStr);
  });

  test('FP: addersmall numbers test', () {
    final val = FloatingPoint32Value.getFloatingPointConstant(
            FloatingPointConstants.smallestPositiveSubnormal)
        .toDouble();
    final fp1 = FloatingPoint32()
      ..put(FloatingPoint32Value.getFloatingPointConstant(
              FloatingPointConstants.smallestPositiveSubnormal)
          .value);
    final fp2 = FloatingPoint32()
      ..put(FloatingPoint32Value.getFloatingPointConstant(
              FloatingPointConstants.smallestPositiveSubnormal)
          .negate()
          .value);
    final out = FloatingPoint32Value.fromDouble(val - val);

    final adder = FloatingPointAdder(fp1, fp2);

    final fpSuper = adder.sum.floatingPointValue;
    final fpStr = fpSuper.toDouble().abs().toStringAsPrecision(7);
    final valStr = out.toDouble().toStringAsPrecision(7);
    expect(fpStr, valStr);
  });

  test('FP: adder carry numbers test', () {
    final val = pow(2.5, -12).toDouble();
    final fp1 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(pow(2.5, -12).toDouble()).value);
    final fp2 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(pow(2.5, -12).toDouble()).value);
    final out = FloatingPoint32Value.fromDouble(val + val);

    final adder = FloatingPointAdder(fp1, fp2);

    final fpSuper = adder.sum.floatingPointValue;
    final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
    final valStr = out.toDouble().toStringAsPrecision(7);
    expect(fpStr, valStr);
  });

  test('FP: adder basic loop test', () {
    final input = [(3.25, 1.5), (4.5, 3.75)];

    for (final pair in input) {
      final fp1 = FloatingPoint32()
        ..put(FloatingPoint32Value.fromDouble(pair.$1).value);
      final fp2 = FloatingPoint32()
        ..put(FloatingPoint32Value.fromDouble(pair.$2).value);
      final out = FloatingPoint32Value.fromDouble(pair.$1 + pair.$2);

      final adder = FloatingPointAdder(fp1, fp2);

      final fpSuper = adder.sum.floatingPointValue;
      final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
      final valStr = out.toDouble().toStringAsPrecision(7);
      expect(fpStr, valStr);
    }
  });

// if you name two tests the same they get run together
// RippleCarryAdder: cannot access inputs from outside -- super.a issue
  test('FP: adder basic loop test - negative numbers', () {
    final input = [(4.5, 3.75), (9.0, -3.75), (-9.0, 3.9375), (-3.9375, 9.0)];

    for (final pair in input) {
      final fp1 = FloatingPoint32()
        ..put(FloatingPoint32Value.fromDouble(pair.$1).value);
      final fp2 = FloatingPoint32()
        ..put(FloatingPoint32Value.fromDouble(pair.$2).value);
      final out = FloatingPoint32Value.fromDouble(pair.$1 + pair.$2);

      final adder = FloatingPointAdder(fp1, fp2);

      final fpSuper = adder.sum.floatingPointValue;
      final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
      final valStr = out.toDouble().toStringAsPrecision(7);
      expect(fpStr, valStr);
    }
  });

  test('FP: adder basic subnormal test', () {
    final fp1 = FloatingPoint32()
      ..put(FloatingPoint32Value.getFloatingPointConstant(
              FloatingPointConstants.smallestPositiveNormal)
          .value);
    final fp2 = FloatingPoint32()
      ..put(FloatingPoint32Value.getFloatingPointConstant(
              FloatingPointConstants.smallestPositiveSubnormal)
          .negate()
          .value);

    final out = FloatingPoint32Value.fromDouble(
        fp1.floatingPointValue.toDouble() + fp2.floatingPointValue.toDouble());
    final adder = FloatingPointAdder(fp1, fp2);

    final fpSuper = adder.sum.floatingPointValue;
    final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
    final valStr = out.toDouble().toStringAsPrecision(7);
    expect(fpStr, valStr);
  });

  test('FP: tiny subnormal test', () {
    const ew = 4;
    const mw = 4;
    final fp1 = FloatingPoint(exponentWidth: ew, mantissaWidth: mw)
      ..put(FloatingPointValue.getFloatingPointConstant(
              FloatingPointConstants.smallestPositiveNormal, ew, mw)
          .value);
    final fp2 = FloatingPoint(exponentWidth: ew, mantissaWidth: mw)
      ..put(FloatingPointValue.getFloatingPointConstant(
              FloatingPointConstants.smallestPositiveSubnormal, ew, mw)
          .negate()
          .value);

    final outDouble =
        fp1.floatingPointValue.toDouble() + fp2.floatingPointValue.toDouble();
    final out = FloatingPointValue.fromDoubleIter(outDouble,
        exponentWidth: ew, mantissaWidth: mw);
    final adder = FloatingPointAdder(fp1, fp2);

    expect(adder.sum.floatingPointValue.compareTo(out), 0);
  });

  test('FP: addernegative number requiring a carryOut', () {
    const pair = (9.0, -3.75);
    const ew = 3;
    const mw = 5;

    final fp1 = FloatingPoint(exponentWidth: ew, mantissaWidth: mw)
      ..put(FloatingPointValue.fromDouble(pair.$1,
              exponentWidth: ew, mantissaWidth: mw)
          .value);
    final fp2 = FloatingPoint(exponentWidth: ew, mantissaWidth: mw)
      ..put(FloatingPointValue.fromDouble(pair.$2,
              exponentWidth: ew, mantissaWidth: mw)
          .value);

    final out = FloatingPointValue.fromDouble(pair.$1 + pair.$2,
        exponentWidth: ew, mantissaWidth: mw);
    final adder = FloatingPointAdder(fp1, fp2);

    expect(adder.sum.floatingPointValue.compareTo(out), 0);
  });

  test('FP: adder subnormal cancellation', () {
    const ew = 4;
    const mw = 4;
    final fp1 = FloatingPoint(exponentWidth: ew, mantissaWidth: mw)
      ..put(FloatingPointValue.getFloatingPointConstant(
              FloatingPointConstants.smallestPositiveSubnormal, ew, mw)
          .negate()
          .value);
    final fp2 = FloatingPoint(exponentWidth: ew, mantissaWidth: mw)
      ..put(FloatingPointValue.getFloatingPointConstant(
              FloatingPointConstants.smallestPositiveSubnormal, ew, mw)
          .value);

    final out = fp2.floatingPointValue + fp1.floatingPointValue;

    final adder = FloatingPointAdder(fp1, fp2);
    // TODO(desmonddak):  figure out how to handle -0.0, as this would fail
    expect(adder.sum.floatingPointValue.abs().compareTo(out), 0);
  });

  test('FP: adder adder basic loop adder test2', () {
    final input = [(4.5, 3.75), (9.0, -3.75), (-9.0, 3.9375), (-3.9375, 9.0)];

    for (final pair in input) {
      final fp1 = FloatingPoint32()
        ..put(FloatingPoint32Value.fromDouble(pair.$1).value);
      final fp2 = FloatingPoint32()
        ..put(FloatingPoint32Value.fromDouble(pair.$2).value);
      final out = FloatingPoint32Value.fromDouble(pair.$1 + pair.$2);

      final adder = FloatingPointAdder(fp1, fp2);

      final fpSuper = adder.sum.floatingPointValue;
      final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
      final valStr = out.toDouble().toStringAsPrecision(7);
      expect(fpStr, valStr);
    }
  });
  test('FP: adder singleton', () {
    const pair = (9.0, -3.75);
    {
      final fp1 = FloatingPoint32()
        ..put(FloatingPoint32Value.fromDouble(pair.$1).value);
      final fp2 = FloatingPoint32()
        ..put(FloatingPoint32Value.fromDouble(pair.$2).value);
      final out = FloatingPoint32Value.fromDouble(pair.$1 + pair.$2);

      final adder = FloatingPointAdder(fp1, fp2);

      final fpSuper = adder.sum.floatingPointValue;
      final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
      final valStr = out.toDouble().toStringAsPrecision(7);
      expect(fpStr, valStr);
    }
  });
  test('FP: adder random', () {
    const eWidth = 5;
    const mWidth = 20;

    final fa = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    final fb = FloatingPoint(exponentWidth: eWidth, mantissaWidth: mWidth);
    final fpv = FloatingPointValue.ofInts(0, 0,
        exponentWidth: eWidth, mantissaWidth: mWidth);
    final smallest = FloatingPointValue.getFloatingPointConstant(
        FloatingPointConstants.smallestPositiveNormal, eWidth, mWidth);
    fa.put(0);
    fb.put(0);
    final adder = FloatingPointAdder(fa, fb);
    final value = Random(513);
    for (var i = 0; i < 50; i++) {
      final fva = FloatingPointValue.random(value,
          exponentWidth: eWidth, mantissaWidth: mWidth, normal: true);
      final fvb = FloatingPointValue.random(value,
          exponentWidth: eWidth, mantissaWidth: mWidth, normal: true);
      fa.put(fva);
      fb.put(fvb);
      // fromDoubleIter does not round like '+' would
      final expected = FloatingPointValue.fromDoubleIter(
          fva.toDouble() + fvb.toDouble(),
          exponentWidth: fpv.exponent.width,
          mantissaWidth: fpv.mantissa.width);
      final computed = adder.sum.floatingPointValue;
      final ulp = FloatingPointValue.ofInts(
          max(expected.exponent.toInt(), 1), 1,
          exponentWidth: eWidth, mantissaWidth: mWidth);
      final diff = (expected.toDouble() - computed.toDouble()).abs();
      if (expected.isNormal()) {
        expect(expected.isNaN(), equals(computed.isNaN()));
        if (!expected.isNaN()) {
          expect(diff, lessThan(ulp.toDouble() * smallest.toDouble()));
        }
      }
    }
  });
}
