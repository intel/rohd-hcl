// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_to_float_test.dart
// Test fixed point to floating point converters.
//
// 2024 October 24
// Author: Soner Yaldiz <soner.yaldiz@intel.com>

import 'dart:io';
import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() async {
  test('Smoke', () async {
    final fixed = FixedPoint(signed: true, m: 34, n: 33);
    final dut =
        FixedToFloatConverter(fixed, exponentWidth: 4, mantissaWidth: 3);
    await dut.build();
    File('${dut.name}.sv').writeAsStringSync(dut.generateSynth());
    fixed.put(FixedPointValue.ofDouble(1.25, signed: true, m: 34, n: 33));
    expect(dut.float.floatingPointValue.toDouble(), 1.25);
  });

  test('Q16.16 to E5M2', () async {
    final fixed = FixedPoint(signed: true, m: 16, n: 16);
    final dut =
        FixedToFloatConverter(fixed, exponentWidth: 5, mantissaWidth: 2);
    await dut.build();
    for (var val = 0; val < pow(2, 14); val++) {
      final fixedValue = FixedPointValue(
          value: LogicValue.ofInt(val, fixed.width),
          signed: true,
          m: fixed.m,
          n: fixed.n);
      fixed.put(fixedValue);
      final fpv = dut.float.floatingPointValue;
      final fpvExpected = FloatingPointValue.ofDouble(fixedValue.toDouble(),
          exponentWidth: dut.exponentWidth, mantissaWidth: dut.mantissaWidth);
      expect(fpv.sign, fpvExpected.sign);
      expect(fpv.exponent.bitString, fpvExpected.exponent.bitString,
          reason: 'exponent');
      expect(fpv.mantissa.bitString, fpvExpected.mantissa.bitString,
          reason: 'mantissa');
    }
  });
}
