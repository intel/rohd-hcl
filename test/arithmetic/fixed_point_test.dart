// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_point_test.dart
// Test of fixed point logic.
//
// 2025 August 22
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() async {
  test('FX Comparison', () {
    final fx1 = FixedPoint(integerWidth: 10, fractionWidth: 10);
    final fx2 = FixedPoint(integerWidth: 10, fractionWidth: 10);

    final val1 = fx1.valuePopulator().ofDouble(
          1.23,
        );
    final val2 = fx2.valuePopulator().ofDouble(3.45);
    final val3 = FixedPointValue.populator(integerWidth: 10, fractionWidth: 10)
        .ofDouble(1.23);

    fx1.put(val1);
    fx2.put(val2);

    expect(fx1.lt(fx2).value.toBool(), isTrue);
    expect(fx1.lte(fx2).value.toBool(), isTrue);
    expect(fx1.gt(fx2).value.toBool(), isFalse);
    expect((fx1 > fx2).value.toBool(), isFalse);
    expect(fx1.gte(fx2).value.toBool(), isFalse);
    expect((fx1 >= fx2).value.toBool(), isFalse);
    expect(fx1.eq(fx2).value.toBool(), isFalse);
    expect(fx1.neq(fx2).value.toBool(), isTrue);

    fx2.put(val3);

    expect(fx1.lt(fx2).value.toBool(), isFalse);
    expect(fx1.lte(fx2).value.toBool(), isTrue);
    expect(fx1.gt(fx2).value.toBool(), isFalse);
    expect((fx1 > fx2).value.toBool(), isFalse);
    expect(fx1.gte(fx2).value.toBool(), isTrue);
    expect((fx1 >= fx2).value.toBool(), isTrue);
    expect(fx1.eq(fx2).value.toBool(), isTrue);
    expect(fx1.neq(fx2).value.toBool(), isFalse);
  });

  test('FX Negate', () {
    final fx1 = FixedPoint(integerWidth: 10, fractionWidth: 10);
    final fx2 = FixedPoint(integerWidth: 10, fractionWidth: 10);

    final val1 = fx1.valuePopulator().ofDouble(1.23);
    final val2 = fx2.valuePopulator().ofDouble(-1.23);

    fx1.put(val1);
    fx2.put(val2);
    expect(fx1.negate().eq(fx2).value.toBool(), isTrue);
    expect((-fx1).eq(fx2).value.toBool(), isTrue);
    expect(fx1.negate().neq(fx2).value.toBool(), isFalse);
    expect((-fx1).neq(fx2).value.toBool(), isFalse);
    final val3 = val1.negate();
    fx2.put(val3);
    expect(fx1.negate().eq(fx2).value.toBool(), isTrue);
    expect((-fx1).eq(fx2).value.toBool(), isTrue);
    expect(fx1.negate().neq(fx2).value.toBool(), isFalse);
    expect((-fx1).neq(fx2).value.toBool(), isFalse);
  });

  test('FX direct arithmetic operations', () {
    final fx1 = FixedPoint(integerWidth: 4, fractionWidth: 4);
    final fx2 = FixedPoint(integerWidth: 4, fractionWidth: 4);
    fx1.put(fx1.valuePopulator().ofDouble(7.5));
    fx2.put(fx2.valuePopulator().ofDouble(2.25));

    final sum = fx1 + fx2;
    final difference = fx1 - fx2;
    final product = fx1 * fx2;

    expect(sum.fixedPointValue.toDouble(), 9.75);
    expect(sum.integerWidth, 5);
    expect(difference.fixedPointValue.toDouble(), 5.25);
    expect(difference.integerWidth, 5);
    expect(product.fixedPointValue.toDouble(), 16.875);
  });

  test('FixedPointValue creates a constant FixedPoint', () {
    final value = FixedPointValue.populator(integerWidth: 4, fractionWidth: 4)
        .ofDouble(-2.25);
    final constant = value.toLogic(name: 'constantFixedPoint');

    expect(constant.name, 'constantFixedPoint');
    expect(constant.integer, isA<Const>());
    expect(constant.fraction, isA<Const>());
    expect(constant.fixedPointValue, value);
  });

  test('FX Multiply signed', () {
    final fx1 = FixedPoint(integerWidth: 4, fractionWidth: 4);
    final fx2 = FixedPoint(integerWidth: 4, fractionWidth: 4);
    const vals = [
      -8.0,
      -16.0,
      -2.0,
      -1.5,
      -1.0,
      -0.5,
      0.0,
      0.5,
      1.0,
      1.5,
      2.0,
      3.9375,
    ];
    for (final v1 in vals) {
      for (final v2 in vals) {
        fx1.put(fx1.valuePopulator().ofDouble(v1));
        fx2.put(fx2.valuePopulator().ofDouble(v2));
        final product = fx1 * fx2;
        expect(product.fixedPointValue.toDouble(), closeTo(v1 * v2, 1e-6),
            reason: '$v1 * $v2');
        expect(product.integerWidth, 9);
      }
    }
  });

  test('FX Multiply unsigned', () {
    final fx1 = FixedPoint(integerWidth: 4, fractionWidth: 4, signed: false);
    final fx2 = FixedPoint(integerWidth: 4, fractionWidth: 4, signed: false);
    const vals = [0.0, 0.5, 1.0, 1.5, 2.0, 3.9375, 15.9375];
    for (final v1 in vals) {
      for (final v2 in vals) {
        fx1.put(fx1.valuePopulator().ofDouble(v1));
        fx2.put(fx2.valuePopulator().ofDouble(v2));
        final product = fx1 * fx2;
        expect(product.fixedPointValue.toDouble(), closeTo(v1 * v2, 1e-6),
            reason: '$v1 * $v2');
      }
    }
  });

  test('FX unimplemented operators throw', () {
    final fx1 = FixedPoint(integerWidth: 4, fractionWidth: 4);
    final fx2 = FixedPoint(integerWidth: 4, fractionWidth: 4);
    fx1.put(fx1.valuePopulator().ofDouble(1));
    fx2.put(fx2.valuePopulator().ofDouble(2));
    expect(() => fx1 % fx2, throwsA(isA<UnimplementedError>()));
    expect(() => fx1 / fx2, throwsA(isA<UnimplementedError>()));
    expect(() => fx1.pow(fx2), throwsA(isA<UnimplementedError>()));
  });
}
