// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// float_to_fixed_test.dart
// Test floating point to fixed point conversion.
//
// 2024 November 1
// Author: Soner Yaldiz <soner.yaldiz@intel.com>

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() async {
  test('E5M2 to Q16.16 exhaustive', () async {
    final float = FloatingPoint(exponentWidth: 5, mantissaWidth: 2);
    final dut = FloatToFixed(float);
    await dut.build();
    for (var val = 0; val < pow(2, 8); val++) {
      final fpv = FloatingPointValue.ofLogicValue(
          5, 2, LogicValue.ofInt(val, float.width));
      if (!fpv.isAnInfinity() & !fpv.isNaN()) {
        float.put(fpv);
        final fxp = dut.fixed;
        final fxpExp = FixedPointValue.ofDouble(fpv.toDouble(),
            signed: true, m: dut.m, n: dut.n);
        expect(fxp.value.bitString, fxpExp.value.bitString);
      }
    }
  });

  test('FP8toINT: exhaustive', () async {
    final float = Logic(width: 8);
    final mode = Logic();
    final dut = Float8ToFixed(float, mode);
    await dut.build();

    // E4M3
    mode.put(1);
    for (var val = 0; val < pow(2, 8); val++) {
      final fp8 = FloatingPointValue.ofLogicValue(
          4, 3, LogicValue.ofInt(val, float.width));
      if (!fp8.isNaN() & !fp8.isAnInfinity()) {
        float.put(fp8.value);
        final fx8 =
            FixedPointValue.ofDouble(fp8.toDouble(), signed: true, m: 23, n: 9);
        expect(dut.fixed.value.bitString, fx8.value.bitString);
        expect(dut.q23p9.value, fx8.value);
      }
    }

    // E5M2
    mode.put(0);
    for (var val = 0; val < pow(2, 8); val++) {
      final fp8 = FloatingPointValue.ofLogicValue(
          5, 2, LogicValue.ofInt(val, float.width));
      if (!fp8.isNaN() & !fp8.isAnInfinity()) {
        float.put(fp8.value);
        final fx8 = FixedPointValue.ofDouble(fp8.toDouble(),
            signed: true, m: 16, n: 16);
        expect(dut.fixed.value.bitString, fx8.value.bitString);
        expect(dut.q16p16.value, fx8.value);
      }
    }
  });
}
