// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_to_float_test.dart
// Test fixed point to floating point converters.
//
// 2024 October 24
// Author: Soner Yaldiz <soner.yaldiz@intel.com>

import 'dart:io';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() async {
  test('FixedToFloat: simple', () async {
    final fixed = FixedPoint(signed: true, m: 34, n: 33);
    final dut =
        FixedToFloatConverter(fixed, exponentWidth: 4, mantissaWidth: 3);
    await dut.build();
    File('${dut.name}.sv').writeAsStringSync(dut.generateSynth());
    fixed.put(FixedPointValue.ofDouble(1.25, signed: true, m: 34, n: 33));
    expect(dut.float.floatingPointValue.toDouble(), 1.25);
  });
}
