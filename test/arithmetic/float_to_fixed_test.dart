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
    for (var val = 0; val < pow(2, 6); val++) {
      final floatValue = FloatingPointValue.ofLogicValue(
          5, 2, LogicValue.ofInt(val, float.width));
      float.put(floatValue);
      final fxp = dut.fixed;
      final fxpExp = FixedPointValue.ofDouble(floatValue.toDouble(),
          signed: true, m: dut.m, n: dut.n);
      expect(fxp.value.bitString, fxpExp.value.bitString);
    }
  });
}
