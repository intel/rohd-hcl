// Copyright (C) 2025 Intel Corporation
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

    // TODO(mkorbel1): re-enable prevVal checks pending https://github.com/intel/rohd/pull/565

    expect(fp.floatingPointValue, val1);
    // expect(fp.previousFloatingPointValue, isNull);

    var checkRan = false;

    Simulator.registerAction(10, () {
      fp.put(val2);
      expect(fp.floatingPointValue, val2);
      // expect(fp.previousFloatingPointValue, val1);
      checkRan = true;
    });

    await Simulator.run();

    expect(checkRan, isTrue);
  });

  test('FloatingPointValue negation', () async {
    const exponentWidth = 4;
    const mantissaWidth = 4;
    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

    final val1 = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofDouble(-1.23);
    fp1.put(val1);
    final val2 = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofDouble(1.23);
    expect((-fp1).floatingPointValue, equals(val2));
  });

  test('FloatingPointValue comparison operators', () async {
    const exponentWidth = 4;
    const mantissaWidth = 4;
    final fp1 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    final fp2 = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

    final val1 = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofDouble(-1.23);
    final val2 = FloatingPointValue.populator(
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        .ofDouble(-3.45);

    fp1.put(val1);
    fp2.put(val2);

    final rv = Random(71);

    for (var iter = 0; iter < 50; iter++) {
      final val1 = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .random(rv);
      final val2 = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .random(rv);
      fp1.put(val1);
      fp2.put(val1);
      expect(fp1.eq(fp2).value.toBool(), isTrue);
      expect(fp1.lte(fp2).value.toBool(), isTrue);
      expect(fp1.gte(fp2).value.toBool(), isTrue);
      expect((fp2 >= fp1).value.toBool(), isTrue);
      expect(fp1.neq(fp2).value.toBool(), isFalse);
      expect(fp1.lt(fp2).value.toBool(), isFalse);
      expect(fp1.gt(fp2).value.toBool(), isFalse);
      expect((fp2 > fp1).value.toBool(), isFalse);

      fp2.put(val2);
      if (val1.toDouble() < val2.toDouble()) {
        expect(fp1.lt(fp2).value.toBool(), isTrue);
        expect(fp1.lte(fp2).value.toBool(), isTrue);
        expect(
            fp1.neq(fp2).value.toBool(), isTrue); // This will use Logic.neq()
        expect(fp1.eq(fp2).value.toBool(), isFalse);
        expect(fp1.gt(fp2).value.toBool(), isFalse);
        expect((fp1 > fp2).value.toBool(), isFalse);
      } else if (val1.toDouble() > val2.toDouble()) {
        expect(fp1.gt(fp2).value.toBool(), isTrue);
        expect((fp1 > fp2).value.toBool(), isTrue);
        expect(fp1.lt(fp2).value.toBool(), isFalse);
        expect(fp1.lte(fp2).value.toBool(), isFalse);
        expect(
            fp1.neq(fp2).value.toBool(), isTrue); // This will use Logic.neq()
      } else {
        // rare that the two numbers would collide but just to be safe
        expect(fp1.eq(fp2).value.toBool(), isTrue);
        expect(fp1.neq(fp2).value.toBool(), isFalse);
      }
    }
  });

  // TODO(desmonddak): convert these tests to methods

  BigInt toBigInt(FloatingPointValue fpv) {
    final mantissa = [
      if (fpv.isNormal()) LogicValue.one else LogicValue.zero,
      fpv.mantissa
    ].swizzle();
    final bigIntRepr = mantissa.toBigInt() << fpv.exponent.toInt();
    return bigIntRepr;
  }

  FloatingPointValue fromBigInt(BigInt bigIntRepr,
      {required int exponentWidth,
      required int mantissaWidth,
      bool sign = false}) {
    final vec = LogicValue.ofBigInt(
        bigIntRepr, max(bigIntRepr.bitLength, mantissaWidth));
    final predExp = vec.width - mantissaWidth - 1;
    final predMantissa = vec >>> predExp;
    final outMantissa = predMantissa.getRange(0, mantissaWidth);
    final intvec = vec >>> predExp;
    final len = intvec.width - mantissaWidth - 1;
    final outExponent = len;

    return FloatingPointValue(
        sign: LogicValue.ofBool(sign),
        exponent: LogicValue.ofInt(outExponent, exponentWidth),
        mantissa: outMantissa);
  }

  test('FloatingPointValue to BigInt', () async {
    const exponentWidth = 8;
    const mantissaWidth = 8;
    for (final flop in [-1.3, 4.5, -6.9e-8, 8.2e5]) {
      final val1 = FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
          .ofDouble(flop);

      final bigInt = toBigInt(val1);

      final fpv = fromBigInt(bigInt,
          sign: val1.sign.toBool(),
          exponentWidth: exponentWidth,
          mantissaWidth: mantissaWidth);

      expect(fpv, equals(val1));
    }
  });
}
