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
    final fixed = FixedPoint(mWidth: 3, nWidth: 23);
    expect(() => FixedPointSqrt(fixed), throwsException);
  });

  test('Fixed Point: expected correct sqrt', () {
    const mantissaWidth = 23;

    final fixed = FixedPoint(signed: false, mWidth: 3, nWidth: mantissaWidth);

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
        fixed.put(FixedPointValue.populator(
                    mWidth: fixed.mWidth,
                    nWidth: fixed.nWidth,
                    signed: fixed.signed)
                .ofDouble(test)

            // FixedPointValue.ofDouble(test,
            //     signed: fixed.signed, m: fixed.mWidth, n: fixed.nWidth)
            );

        final fpvResult = dut.sqrt.fixedPointValue;

        final fpvExpected = FixedPointValue.populator(
                mWidth: fixed.mWidth,
                nWidth: fixed.nWidth,
                signed: fixed.signed)
            .ofDouble(sqrt(test));

        // FixedPointValue.ofDouble(sqrt(test),
        //     signed: fixed.signed, m: fixed.mWidth, n: fixed.nWidth);
        expect(fpvResult, fpvExpected);
      }
    }
  });
}
