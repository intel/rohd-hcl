// Copyright (C) 2025-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_test.dart
// Tests of Floating Point basic types
//
// 2024 April 1
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('floating point swap', () {
    final fp1 = FloatingPoint64();
    final fp2 = FloatingPoint64();

    final val1 = FloatingPoint64Value.populator().ofDouble(1.23);
    final val2 = FloatingPoint64Value.populator().ofDouble(3.45);

    fp1.put(val1);
    fp2.put(val2);

    final swapped = FloatingPointUtilities.sort((fp1, fp2));

    expect(swapped.sorted.$1.floatingPointValue, val2);
    expect(swapped.sorted.$2.floatingPointValue, val1);

    final sorter = FloatingPointSort(fp1, fp2);
    expect(sorter.outA.floatingPointValue, val2);
    expect(sorter.outB.floatingPointValue, val1);
  });

  test('e4m3 isAnInfinity always 0', () {
    expect(FloatingPoint8E4M3().isAnInfinity.value.toBool(), isFalse);
  });

  test('e4m3 classifies only its reserved NaN encoding', () {
    final fp = FloatingPoint8E4M3();
    for (var mantissa = 0; mantissa < 8; mantissa++) {
      final value = FloatingPoint8E4M3Value.populator().ofInts(15, mantissa);
      fp.put(value);
      expect(fp.isNaN.value.toBool(), mantissa == 7,
          reason: 'mantissa=$mantissa');
      expect(fp.isSignalingNaN.value.toBool(), isFalse,
          reason: 'mantissa=$mantissa');
      expect(fp.isAnInfinity.value.toBool(), isFalse,
          reason: 'mantissa=$mantissa');
      if (mantissa == 7) {
        expect(value.toDouble(), isNaN);
      } else {
        expect(value.toDouble(), 256.0 * (1.0 + mantissa / 8.0),
            reason: 'mantissa=$mantissa');
      }
    }
  });

  test('standard formats distinguish signaling and quiet NaNs', () {
    final fp = FloatingPoint(exponentWidth: 5, mantissaWidth: 4);
    fp.put(fp.valuePopulator().ofInts(31, 3, sign: true));
    expect(fp.isSignalingNaN.value.toBool(), isTrue);
    expect(fp.isQuietNaN.value.toBool(), isFalse);

    fp.put(fp.valuePopulator().ofInts(31, 11, sign: true));
    expect(fp.isSignalingNaN.value.toBool(), isFalse);
    expect(fp.isQuietNaN.value.toBool(), isTrue);
  });

  test('explicit J-bit formats classify special values consistently', () {
    final fp =
        FloatingPoint(exponentWidth: 5, mantissaWidth: 5, explicitJBit: true);
    final infinity = fp.valuePopulator().positiveInfinity;
    final nan = fp.valuePopulator().nan;

    expect(infinity.isLegalValue(), isTrue);
    expect(infinity.isAnInfinity, isTrue);
    expect(infinity.isNaN, isFalse);
    fp.put(infinity);
    expect(fp.isAnInfinity.value.toBool(), isTrue);
    expect(fp.isNaN.value.toBool(), isFalse);

    expect(nan.isLegalValue(), isTrue);
    expect(nan.isNaN, isTrue);
    expect(nan.isQuietNaN, isTrue);
    expect(nan.isSignalingNaN, isFalse);
    fp.put(nan);
    expect(fp.isAnInfinity.value.toBool(), isFalse);
    expect(fp.isNaN.value.toBool(), isTrue);
    expect(fp.isQuietNaN.value.toBool(), isTrue);
    expect(fp.isSignalingNaN.value.toBool(), isFalse);
  });

  test('floating point value populators are the correct type', () {
    expect(
        FloatingPoint32()
            .valuePopulator()
            .ofConstant(FloatingPointConstants.one),
        isA<FloatingPoint32Value>());
    expect(
        FloatingPoint64()
            .valuePopulator()
            .ofConstant(FloatingPointConstants.one),
        isA<FloatingPoint64Value>());
    expect(
        FloatingPoint16()
            .valuePopulator()
            .ofConstant(FloatingPointConstants.one),
        isA<FloatingPoint16Value>());
    expect(
        FloatingPointBF16()
            .valuePopulator()
            .ofConstant(FloatingPointConstants.one),
        isA<FloatingPointBF16Value>());
    expect(
        FloatingPoint8E5M2()
            .valuePopulator()
            .ofConstant(FloatingPointConstants.one),
        isA<FloatingPoint8E5M2Value>());
    expect(
        FloatingPoint8E4M3()
            .valuePopulator()
            .ofConstant(FloatingPointConstants.one),
        isA<FloatingPoint8E4M3Value>());
    expect(
        FloatingPointTF32()
            .valuePopulator()
            .ofConstant(FloatingPointConstants.one),
        isA<FloatingPointTF32Value>());
  });

  test('floating point floatingPointValue and previousFloatingPointValue',
      () async {
    final fp = FloatingPoint64();

    expect(fp.floatingPointValue, isA<FloatingPoint64Value>());
    expect(fp.previousFloatingPointValue, isA<FloatingPoint64Value?>());

    final val1 = FloatingPoint64Value.populator().ofDouble(1.23);
    final val2 = FloatingPoint64Value.populator().ofDouble(3.45);

    fp.put(val1);

    expect(fp.floatingPointValue, val1);
    expect(fp.previousFloatingPointValue, isNull);

    var checkRan = false;

    Simulator.registerAction(10, () {
      fp.put(val2);
      expect(fp.floatingPointValue, val2);
      expect(fp.previousFloatingPointValue, val1);
      checkRan = true;
    });

    await Simulator.run();

    expect(checkRan, isTrue);
  });

  test('FP Comparison', () {
    final fp1 = FloatingPoint32();
    final fp2 = FloatingPoint32();

    final val1 = FloatingPoint32Value.populator().ofDouble(1.23);
    final val2 = FloatingPoint32Value.populator().ofDouble(3.45);
    final val3 = FloatingPoint32Value.populator().ofDouble(1.23);

    fp1.put(val1);
    fp2.put(val2);

    expect(fp1.lt(fp2).value.toBool(), isTrue);
    expect(fp1.lte(fp2).value.toBool(), isTrue);
    expect(fp1.gt(fp2).value.toBool(), isFalse);
    expect((fp1 > fp2).value.toBool(), isFalse);
    expect(fp1.gte(fp2).value.toBool(), isFalse);
    expect((fp1 >= fp2).value.toBool(), isFalse);
    expect(fp1.eq(fp2).value.toBool(), isFalse);
    expect(fp1.neq(fp2).value.toBool(), isTrue);

    fp2.put(val3);

    expect(fp1.lt(fp2).value.toBool(), isFalse);
    expect(fp1.lte(fp2).value.toBool(), isTrue);
    expect(fp1.gt(fp2).value.toBool(), isFalse);
    expect((fp1 > fp2).value.toBool(), isFalse);
    expect(fp1.gte(fp2).value.toBool(), isTrue);
    expect((fp1 >= fp2).value.toBool(), isTrue);
    expect(fp1.eq(fp2).value.toBool(), isTrue);
    expect(fp1.neq(fp2).value.toBool(), isFalse);
  });

  test('FP comparisons implement IEEE NaN and signed-zero behavior', () {
    final left = FloatingPoint(exponentWidth: 4, mantissaWidth: 4);
    final right = FloatingPoint(exponentWidth: 4, mantissaWidth: 4);
    FloatingPointValuePopulator populator() => left.valuePopulator();
    final quietNaN = populator().ofInts(15, 8);
    final signalingNaN = populator().ofInts(15, 1, sign: true);
    final finite = populator().one;

    void expectUnordered(
        FloatingPointValue leftValue, FloatingPointValue rightValue,
        {required bool invalid}) {
      left.put(leftValue);
      right.put(rightValue);
      expect(left.eq(right).value.toBool(), isFalse);
      expect(left.neq(right).value.toBool(), isTrue);
      expect(left.lt(right).value.toBool(), isFalse);
      expect(left.lte(right).value.toBool(), isFalse);
      expect(left.gt(right).value.toBool(), isFalse);
      expect(left.gte(right).value.toBool(), isFalse);
      expect(left.comparisonInvalid(right).value.toBool(), invalid);
    }

    expectUnordered(quietNaN, quietNaN, invalid: false);
    expectUnordered(quietNaN, finite, invalid: false);
    expectUnordered(finite, quietNaN, invalid: false);
    expectUnordered(signalingNaN, finite, invalid: true);
    expectUnordered(finite, signalingNaN, invalid: true);

    left.put(populator().positiveZero);
    right.put(populator().negativeZero);
    expect(left.eq(right).value.toBool(), isTrue);
    expect(left.neq(right).value.toBool(), isFalse);
    expect(left.lt(right).value.toBool(), isFalse);
    expect(left.lte(right).value.toBool(), isTrue);
    expect(left.gt(right).value.toBool(), isFalse);
    expect(left.gte(right).value.toBool(), isTrue);
    expect(left.comparisonInvalid(right).value.toBool(), isFalse);
  });

  test('FP Negate', () {
    final fp1 = FloatingPoint32();
    final fp2 = FloatingPoint32();

    final val1 = FloatingPoint32Value.populator().ofDouble(1.23);
    final val2 = FloatingPoint32Value.populator().ofDouble(-1.23);

    fp1.put(val1);
    fp2.put(val2);
    expect(fp1.negate().eq(fp2).value.toBool(), isTrue);
    expect((-fp1).eq(fp2).value.toBool(), isTrue);
    expect(fp1.negate().neq(fp2).value.toBool(), isFalse);
    expect((-fp1).neq(fp2).value.toBool(), isFalse);
    final val3 = val1.negate();
    fp2.put(val3);
    expect(fp1.negate().eq(fp2).value.toBool(), isTrue);
    expect((-fp1).eq(fp2).value.toBool(), isTrue);
    expect(fp1.negate().neq(fp2).value.toBool(), isFalse);
    expect((-fp1).neq(fp2).value.toBool(), isFalse);
  });

  test('FP direct arithmetic operations', () {
    final fp1 = FloatingPoint32()
      ..put(FloatingPoint32Value.populator().ofDouble(1.5));
    final fp2 = FloatingPoint32()
      ..put(FloatingPoint32Value.populator().ofDouble(2.25));

    expect((fp1 + fp2).floatingPointValue.toDouble(), 3.75);
    expect((fp1 - fp2).floatingPointValue.toDouble(), -0.75);
    expect((fp1 * fp2).floatingPointValue.toDouble(), 3.375);
    expect(() => fp1 / fp2, throwsA(isA<UnimplementedError>()));
  });

  test('FloatingPointValue creates a constant FloatingPoint', () {
    final value = FloatingPoint32Value.populator().ofDouble(-2.25);
    final constant = value.toLogic(name: 'constantFloatingPoint');

    expect(constant.name, 'constantFloatingPoint');
    expect(constant.sign, isA<Const>());
    expect(constant.exponent, isA<Const>());
    expect(constant.mantissa, isA<Const>());
    expect(constant.floatingPointValue, value);
  });

  test('FP Comparison Random', () {
    const exponentWidth = 4;
    const mantissaWidth = 3;
    final rv = Random(57);

    for (final explicitJBit in [false, true]) {
      FloatingPoint fpConstructor() => FloatingPoint(
          exponentWidth: exponentWidth,
          mantissaWidth: mantissaWidth,
          explicitJBit: explicitJBit);
      final fp1 = fpConstructor();
      final fp2 = fpConstructor();

      FloatingPointValuePopulator fpvPopulator() => fp1.valuePopulator();
      final compare = fp1.lte(fp2);
      for (var iter = 0; iter < 4000; iter++) {
        for (final doNormal in [false, true]) {
          for (final doSubNormal in [false, true]) {
            if (!doNormal && !doSubNormal) {
              continue;
            }
            final separate = fpvPopulator()
                .random(rv, genNormal: doNormal, genSubNormal: doSubNormal);
            if (!doNormal) {
              if (separate ==
                      (fpvPopulator().ofConstant(
                          FloatingPointConstants.smallestPositiveNormal)) ||
                  (separate ==
                      (fpvPopulator()
                          .ofConstant(
                              FloatingPointConstants.smallestPositiveNormal)
                          .negate()))) {
                continue;
              }
            }
            fp1.put(separate);

            final low = fpvPopulator().random(rv,
                genNormal: doNormal, genSubNormal: doSubNormal, lte: separate);
            final high = fpvPopulator().random(rv,
                genNormal: doNormal, genSubNormal: doSubNormal, gte: separate);
            fp1.put(low);
            fp2.put(high);
            expect(compare.value.toBool(), isTrue);
          }
        }
      }
    }
  });
}
