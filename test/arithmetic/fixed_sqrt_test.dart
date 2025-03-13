// Copyright (C) 2025 Intel Corporation
// SPDX-License-Indentifier: BSD-3-Clause
//
// fixed_sqrt_test.dart
// Tests for fixed-point square root.
//
// 2025 March 5
// Authors: James Farwell <james.c.farwell@intel.com>,
//          Stephen Weeks <stephen.weeks@intel.com>,
//          Curtis Anderson <curtis.anders@intel.com>

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/arithmetic.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });
  test('sqrt(negative number)', () async {
    final fixed = FixedPoint(signed: true, m: 3, n: 23);
    expect(() => FixedPointSqrt(fixed), throwsException);
  });

  test('Fixed Point: expected correct sqrt', () {
    const mantissaWidth = 23;

    final fixed = FixedPoint(signed: false, m: 3, n: mantissaWidth);

    for (final dut in [
      FixedPointSqrt(fixed),
    ]) {
      final testCases = [
        1.0,
        1.5,
        1.7,
        1.125,
        2.25,
        3.999,
        3.9999998,
      ];

      for (final test in testCases) {
        fixed.put(FixedPointValue.ofDouble(test,
            signed: fixed.signed, m: fixed.m, n: fixed.n));

        final fpvResult = dut.sqrt.fixedPointValue;

        final fpvExpected = FixedPointValue.ofDouble(sqrt(test),
            signed: fixed.signed, m: fixed.m, n: fixed.n);
        expect(fpvResult, fpvExpected);
      }
    }
  });
}
