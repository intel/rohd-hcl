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
