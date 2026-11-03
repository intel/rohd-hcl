// Copyright (C) 2024-2026 Intel Corporation
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

class _MixedFormatFixedPointModule extends Module {
  late final FixedPoint sum;
  late final FixedPoint product;

  _MixedFormatFixedPointModule() : super(name: 'mixedFormatFixedPoint') {
    final left = addTypedInput(
      'left',
      FixedPoint(signed: false, integerWidth: 2, fractionWidth: 10),
    );
    final right = addTypedInput(
      'right',
      FixedPoint(integerWidth: 5, fractionWidth: 20),
    );
    final internalSum = left + right;
    final internalProduct = left.multiply(right);
    FixedPoint createSum({String name = ''}) => internalSum.clone(name: name);
    FixedPoint createProduct({String name = ''}) =>
        internalProduct.clone(name: name);
    sum = addTypedOutput('sum', createSum)..gets(internalSum);
    product = addTypedOutput('product', createProduct)..gets(internalProduct);
  }
}

void main() {
  test('FX Comparison', () {
    final fx1 = FixedPoint(integerWidth: 10, fractionWidth: 10);
    final fx2 = FixedPoint(integerWidth: 10, fractionWidth: 10);

    final val1 = fx1.valuePopulator().ofDouble(
          1.23,
        );
    final val2 = fx2.valuePopulator().ofDouble(3.45);
    final val3 = FixedPointValue.populatorWithSignedness(
            integerWidth: 10, fractionWidth: 10)
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
    final product = fx1.multiply(fx2);

    expect(sum.fixedPointValue.toDouble(), 9.75);
    expect(sum.integerWidth, 5);
    expect(difference.fixedPointValue.toDouble(), 5.25);
    expect(difference.integerWidth, 5);
    expect(product.fixedPointValue.toDouble(), 16.875);
  });

  test('FX mixed-format addition aligns fractional bits', () {
    final left = FixedPoint(integerWidth: 2, fractionWidth: 10);
    final right = FixedPoint(integerWidth: 5, fractionWidth: 20);
    left.put(left.valuePopulator().ofDouble(1.5));
    right.put(right.valuePopulator().ofDouble(3.25));

    final sum = left + right;
    expect(sum.signed, isTrue);
    expect(sum.integerWidth, 6);
    expect(sum.fractionWidth, 20);
    expect(sum.fixedPointValue.toDouble(), 4.75);
  });

  test('FX mixed-signed multiplication preserves full precision', () {
    final left = FixedPoint(signed: false, integerWidth: 2, fractionWidth: 10);
    final right = FixedPoint(integerWidth: 5, fractionWidth: 20);
    left.put(left.valuePopulator().ofDouble(1.5));
    right.put(right.valuePopulator().ofDouble(-2.25));

    final product = left.multiply(right);
    expect(product.signed, isTrue);
    expect(product.integerWidth, 8);
    expect(product.fractionWidth, 30);
    expect(product.fixedPointValue.toDouble(), -3.375);
  });

  test('FX promotion emits correctly sized SystemVerilog ports', () async {
    final module = _MixedFormatFixedPointModule();
    await module.build();

    final systemVerilog = module.dumpSystemVerilog();
    expect(systemVerilog, contains('[26:0] sum'));
    expect(systemVerilog, contains('[38:0] product'));
  });

  test('FX cast rounds and handles overflow explicitly', () {
    final positive = FixedPoint(integerWidth: 2, fractionWidth: 3);
    positive.put(positive.valuePopulator().ofDouble(1.375));
    final widened = positive.cast(integerWidth: 4, fractionWidth: 5);
    expect(widened.fixedPointValue.toDouble(), 1.375);
    expect(widened.integerWidth, 4);
    expect(widened.fractionWidth, 5);
    expect(
      positive
          .cast(integerWidth: 2, fractionWidth: 1)
          .fixedPointValue
          .toDouble(),
      1,
    );
    expect(
      positive
          .cast(
            integerWidth: 2,
            fractionWidth: 1,
            roundingMode: FloatingPointRoundingMode.roundNearestTiesAway,
          )
          .fixedPointValue
          .toDouble(),
      1.5,
    );

    final negative = FixedPoint(integerWidth: 3, fractionWidth: 2);
    negative.put(negative.valuePopulator().ofDouble(-1.75));
    expect(
      negative
          .cast(
            integerWidth: 3,
            fractionWidth: 0,
            roundingMode: FloatingPointRoundingMode.roundTowardsZero,
          )
          .fixedPointValue
          .toDouble(),
      -1,
    );

    final wide = FixedPoint(integerWidth: 4, fractionWidth: 0);
    wide.put(wide.valuePopulator().ofDouble(7));
    final saturated = wide.cast(
      integerWidth: 2,
      fractionWidth: 0,
      overflow: FixedPointOverflowMode.saturate,
    );
    expect(saturated.fixedPointValue.toDouble(), 3);
    expect(
      wide.cast(integerWidth: 2, fractionWidth: 0).fixedPointValue.toDouble(),
      -1,
    );

    final negativeOverflow = FixedPoint(integerWidth: 4, fractionWidth: 0);
    negativeOverflow.put(negativeOverflow.valuePopulator().ofDouble(-7));
    expect(
      negativeOverflow
          .cast(
            integerWidth: 2,
            fractionWidth: 0,
            overflow: FixedPointOverflowMode.saturate,
          )
          .fixedPointValue
          .toDouble(),
      -4,
    );
    expect(
      negativeOverflow
          .cast(
            integerWidth: 2,
            fractionWidth: 0,
            signed: false,
            overflow: FixedPointOverflowMode.saturate,
          )
          .fixedPointValue
          .toDouble(),
      0,
    );
  });

  test('FixedPointArray applies scalar promotion elementwise', () {
    final left = FixedPointArray([
      FixedPoint(integerWidth: 2, fractionWidth: 2),
      FixedPoint(integerWidth: 2, fractionWidth: 2),
    ]);
    final right = FixedPointArray([
      FixedPoint(integerWidth: 3, fractionWidth: 4),
      FixedPoint(integerWidth: 3, fractionWidth: 4),
    ]);
    left[0].put(left[0].valuePopulator().ofDouble(1.5));
    left[1].put(left[1].valuePopulator().ofDouble(-1));
    right[0].put(right[0].valuePopulator().ofDouble(2.25));
    right[1].put(right[1].valuePopulator().ofDouble(0.5));

    final sum = left + right;
    final product = left.multiply(right);
    expect(sum.map((value) => value.fixedPointValue.toDouble()),
        orderedEquals([3.75, -0.5]));
    expect(sum.every((value) => value.fractionWidth == 4), isTrue);
    expect(product.map((value) => value.fixedPointValue.toDouble()),
        orderedEquals([3.375, -0.5]));
    expect(product.every((value) => value.fractionWidth == 6), isTrue);
  });

  test('FX promotion supports every signedness combination', () {
    for (final leftSigned in [false, true]) {
      for (final rightSigned in [false, true]) {
        final left = FixedPoint(
          signed: leftSigned,
          integerWidth: 2,
          fractionWidth: 2,
        );
        final right = FixedPoint(
          signed: rightSigned,
          integerWidth: 3,
          fractionWidth: 4,
        );
        left.put(left.valuePopulator().ofDouble(leftSigned ? -1.5 : 1.5));
        right.put(right.valuePopulator().ofDouble(rightSigned ? -2.25 : 2.25));

        final sum = left + right;
        final product = left.multiply(right);
        expect(sum.signed, leftSigned || rightSigned);
        expect(sum.integerWidth, 4);
        expect(sum.fractionWidth, 4);
        expect(product.signed, leftSigned || rightSigned);
        expect(product.integerWidth, 5 + (leftSigned || rightSigned ? 1 : 0));
        expect(product.fractionWidth, 6);
      }
    }
  });

  test('FX unsigned subtraction adds only one sign bit', () {
    final fx1 = FixedPoint(integerWidth: 4, fractionWidth: 4, signed: false);
    final fx2 = FixedPoint(integerWidth: 4, fractionWidth: 4, signed: false);
    final difference = fx1.subtract(fx2);

    expect(difference.signed, isTrue);
    expect(difference.integerWidth, 4);
    expect(difference.fractionWidth, 4);
    expect(difference.width, fx1.width + 1);

    fx1.put(fx1.valuePopulator().ofDouble(0));
    fx2.put(fx2.valuePopulator().ofDouble(15.9375));
    expect(difference.fixedPointValue.toDouble(), -15.9375);
  });

  test('legacy multiply operator retains unsigned result behavior', () {
    final fx1 = FixedPoint(integerWidth: 4, fractionWidth: 4, signed: false);
    final fx2 = FixedPoint(integerWidth: 4, fractionWidth: 4, signed: false);
    fx1.put(fx1.valuePopulator().ofDouble(2));
    fx2.put(fx2.valuePopulator().ofDouble(3));

    // This regression test intentionally exercises the legacy operator.
    // ignore: deprecated_member_use_from_same_package
    final product = fx1 * fx2;

    expect(product.signed, isFalse);
    expect(product.integerWidth, 8);
    expect(product.fractionWidth, 8);
    expect(product.fixedPointValue.toDouble(), 6);
  });

  test('FixedPointValue creates a constant FixedPoint', () {
    final value = FixedPointValue.populatorWithSignedness(
            integerWidth: 4, fractionWidth: 4)
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
        final product = fx1.multiply(fx2);
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
        final product = fx1.multiply(fx2);
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
