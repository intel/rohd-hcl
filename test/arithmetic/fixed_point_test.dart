// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_point_test.dart
// Test of fixed point logic.
//
// 2025 August 22
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

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
    final val3 = FixedPointValue.populator(
            integerWidth: 10, fractionWidth: 10, signed: true)
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
}
