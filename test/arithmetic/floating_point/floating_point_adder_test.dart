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
    final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);

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

    final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);

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

      final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);

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

    final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);

    final fpSuper = adder.sum.floatingPointValue;
    final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
    final valStr = out.toDouble().toStringAsPrecision(7);
    expect(fpStr, valStr);
  });

  test('FP: small numbers adder test', () {
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

    final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);

    final fpSuper = adder.sum.floatingPointValue;
    final fpStr = fpSuper.toDouble().abs().toStringAsPrecision(7);
    final valStr = out.toDouble().toStringAsPrecision(7);
    expect(fpStr, valStr);
  });

  test('FP: carry numbers adder test', () {
    final val = pow(2.5, -12).toDouble();
    final fp1 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(pow(2.5, -12).toDouble()).value);
    final fp2 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(pow(2.5, -12).toDouble()).value);
    final out = FloatingPoint32Value.fromDouble(val + val);

    final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);

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

      final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);

      final fpSuper = adder.sum.floatingPointValue;
      final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
      final valStr = out.toDouble().toStringAsPrecision(7);
      expect(fpStr, valStr);
    }
  });

// if you name two tests the same they get run together
// RippleCarryAdder: cannot access inputs from outside -- super.a issue
  test('FP: basic loop adder test - negative numbers', () {
    final input = [(4.5, 3.75), (9.0, -3.75), (-9.0, 3.9375), (-3.9375, 9.0)];

    for (final pair in input) {
      final fp1 = FloatingPoint32()
        ..put(FloatingPoint32Value.fromDouble(pair.$1).value);
      final fp2 = FloatingPoint32()
        ..put(FloatingPoint32Value.fromDouble(pair.$2).value);
      final out = FloatingPoint32Value.fromDouble(pair.$1 + pair.$2);

      final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);

      final fpSuper = adder.sum.floatingPointValue;
      final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
      final valStr = out.toDouble().toStringAsPrecision(7);
      expect(fpStr, valStr);
    }
  });

  test('FP: basic subnormal test', () {
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
    final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);

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
    final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);

    expect(adder.sum.floatingPointValue.compareTo(out), 0);
  });

  test('FP: negative number requiring a carryOut', () {
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
    final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);

    expect(adder.sum.floatingPointValue.compareTo(out), 0);
  });

  test('FP: subnormal cancellation', () {
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

    final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);
    // TODO(desmonddak):  figure out how to handle -0.0, as this would fail
    expect(adder.sum.floatingPointValue.abs().compareTo(out), 0);
  });

  test('FP: basic loop adder test2', () {
    final input = [(4.5, 3.75), (9.0, -3.75), (-9.0, 3.9375), (-3.9375, 9.0)];

    for (final pair in input) {
      final fp1 = FloatingPoint32()
        ..put(FloatingPoint32Value.fromDouble(pair.$1).value);
      final fp2 = FloatingPoint32()
        ..put(FloatingPoint32Value.fromDouble(pair.$2).value);
      final out = FloatingPoint32Value.fromDouble(pair.$1 + pair.$2);

      final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);

      final fpSuper = adder.sum.floatingPointValue;
      final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
      final valStr = out.toDouble().toStringAsPrecision(7);
      expect(fpStr, valStr);
    }
  });
  test('FP: singleton', () {
    const pair = (9.0, -3.75);
    {
      final fp1 = FloatingPoint32()
        ..put(FloatingPoint32Value.fromDouble(pair.$1).value);
      final fp2 = FloatingPoint32()
        ..put(FloatingPoint32Value.fromDouble(pair.$2).value);
      final out = FloatingPoint32Value.fromDouble(pair.$1 + pair.$2);

      final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);

      final fpSuper = adder.sum.floatingPointValue;
      final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
      final valStr = out.toDouble().toStringAsPrecision(7);
      expect(fpStr, valStr);
    }
  });
}
