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
}
